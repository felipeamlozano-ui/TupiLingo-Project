"""
Serviço de geração de questões de nivelamento com engine híbrida.
Suporta novo fluxo via Supabase RPC e fluxo legado (GraphRAG) via feature flag.
"""

from __future__ import annotations

import copy
import hashlib
import json
import logging
import os
import random
import time
from typing import Any

from pydantic import BaseModel, Field, ValidationError

from app.ai.cache import prompt_cache
from app.ai.fallback import FallbackOrchestrator
from app.ai.router import ModelRouter
from app.ai.ping_race import PingRaceRouter
from app.core.config import settings
from app.schemas.quiz import (
    Alternative,
    EsqueletoItem,
    LLMQuizItem,
    LLMQuizResponse,
    QuizItem,
    QuizResponse,
)
from app.services.supabase_service import (
    SupabaseRPCError,
    SupabaseRPCTimeoutError,
    SupabaseServiceError,
    supabase_service,
)

logger = logging.getLogger(__name__)

# Feature Flag

_USE_SUPABASE_ENGINE: bool = (
    os.environ.get("USE_SUPABASE_QUIZ_ENGINE", "true").lower() == "true"
)

# Shims de Compatibilidade Backward (pipeline legado)
# Estas funções existiam no rag_service.py original e ainda são importadas
# por nivelamento/apps.py e app/ai/knowledge_graph.py.
# São mantidas aqui para não quebrar a inicialização do servidor.

_db_instance = None
_embedder_instance = None


def get_db():
    """
    Compat shim: retorna a instância singleton do SQLiteVectorDB.
    Usado pelo pipeline legado (knowledge_graph.py) e pelo AppConfig.
    """
    global _db_instance
    if _db_instance is None:
        from nivelamento.services.vector_db import SQLiteVectorDB  # noqa: PLC0415
        _db_instance = SQLiteVectorDB("vector_store.db")
    return _db_instance


def get_embedder():
    """
    Compat shim: retorna o embedder para o pipeline legado.
    No novo pipeline (USE_SUPABASE_QUIZ_ENGINE=true), embeddings não são usados
    no caminho crítico.
    """
    global _embedder_instance
    if _embedder_instance is None:
        try:
            from fastembed import TextEmbedding  # noqa: PLC0415
            _embedder_instance = TextEmbedding(model_name="BAAI/bge-small-en-v1.5")
        except Exception as exc:  # noqa: BLE001
            logger.warning("[rag_service] get_embedder() falhou: %s. Retornando None.", exc)
            return None
    return _embedder_instance

# Constantes

# Mapa dos códigos reais do banco (VarianteTupi.codigo) → nome legível para o prompt LLM
_VARIANTE_NOME_MAP: dict[str, str] = {
    "tupi":                "Tupi Antigo (língua dos Tupinambás, séc. XVI)",
    "tupi_contemporaneo":  "Tupi Contemporâneo",
    "tupinamba":           "Tupinambá",
}

_NIVEL_TEMAS: dict[int, tuple[str, str]] = {
    1:  ("palavras básicas, animais comuns", "facil"),
    2:  ("verbos básicos, ações cotidianas", "facil"),
    3:  ("natureza, geografia básica", "facil"),
    4:  ("mitologia, Tupã e entidades", "media"),
    5:  ("história do Brasil pré-colonial", "media"),
    6:  ("nomes de lugares (toponímia)", "media"),
    7:  ("gramática intermediária", "dificil"),
    8:  ("estrutura de frases complexas", "dificil"),
    9:  ("poesia e cânticos rituais", "dificil"),
    10: ("textos históricos fluentes", "dificil"),
}

_NIVEL_CATEGORIA_MAP: dict[int, str] = {
    1: "fauna",
    2: "geral",
    3: "natureza",
    4: "mitologia",
    5: "historia",
    6: "geral",
    7: "gramatica",
    8: "gramatica",
    9: "geral",
    10: "geral",
}

_LETRAS: tuple[str, ...] = ("A", "B", "C", "D")


# Sistema de Prompt Builder Escalonado por Nível

def _get_system_prompt(tier: str) -> str:
    """Retorna o prompt de sistema especializado para o nível de proficiência."""
    if tier == "iniciante":
        return """\
Você é um professor de língua indígena focado no vocabulário inicial.
Sua função é criar enunciados de tradução simples e diretos para cada termo Tupi fornecido.

DIRETRIZES DO NÍVEL INICIANTE:
1. NÃO altere termos em Tupi, traduções ou distratores.
2. Crie enunciados diretos de tradução (ex: "Qual a tradução correta da palavra '...'?", "O que significa '...' em português?").
3. A explicação deve ser sucinta e indicar a tradução direta (ex: "'...' significa '...' na língua Tupi.").
4. A curiosidade pode ser deixada vazia ("") ou conter um fato simples.
5. Retorne ESTRITAMENTE o JSON no formato solicitado, sem markdown ou texto extra."""

    elif tier == "intermediario":
        return """\
Você é um educador e linguista especialista na cultura e na língua Tupi.
Sua função é criar questões que unam vocabulário com contextualização cultural e gramatical.

DIRETRIZES DO NÍVEL INTERMEDIÁRIO:
1. NÃO altere termos em Tupi, traduções ou distratores.
2. Crie enunciados contextualizados culturalmente e gramaticalmente (ex: explore o uso do termo no cotidiano da aldeia, relações com a natureza ou estruturas sintáticas).
3. A explicação deve ter 1 a 2 frases contextualizando culturalmente a resposta correta.
4. Adicione uma curiosidade cultural relevante sobre o termo ou seu papel no mundo indígena.
5. Retorne ESTRITAMENTE o JSON no formato solicitado, sem markdown ou texto extra."""

    else:  # avancado
        return """\
Você é um historiador, etnolinguista e paleógrafo especialista em Tupi Antigo e documentos coloniais do Brasil quinhentista e seiscentista.
Sua função é formular questões de alta densidade histórica, documental e morfológica.

DIRETRIZES DO NÍVEL AVANÇADO:
1. NÃO altere termos em Tupi, traduções ou distratores.
2. Crie enunciados com contextualização histórica profunda e documental (mencione fontes como as Cartas dos Índios Camarões de 1645, crônicas de viajantes coloniais como Hans Staden, Jean de Léry, Thevet, guerras coloniais, alianças ou análise morfológica).
3. A explicação deve aprofundar o significado histórico e a etimologia/morfologia da palavra naquele contexto de época.
4. Inclua curiosidades etnográficas ou históricas marcantes (personagens históricos como Pedro Poti, Camarão, rituais e costumes).
5. Retorne ESTRITAMENTE o JSON no formato solicitado, sem markdown ou texto extra."""


def _build_prompt(
    esqueleto: list[EsqueletoItem],
    variante_nome: str,
    tema: str,
    tier: str = "iniciante",
) -> str:
    """
    Constrói o prompt do usuário injetando o esqueleto lexical determinístico
    e orientações específicas para o nível de proficiência.
    """
    itens_json = json.dumps(
        [
            {
                "item_id":          item.item_id,
                "termo_tupi":       item.termo_tupi,
                "traducao_correta": item.traducao_correta,
                "distratores":      item.distratores,
                "regra_contexto":   item.regra_contexto,
            }
            for item in esqueleto
        ],
        ensure_ascii=False,
    )

    if tier == "iniciante":
        instrucao = (
            "Para cada item abaixo, crie um enunciado direto de tradução simples e uma explicação sucinta.\n"
        )
    elif tier == "intermediario":
        instrucao = (
            "Para cada item abaixo, crie um enunciado com contextualização cultural e gramatical da língua Tupi, "
            "uma explicação contextualizada de 1-2 frases e uma curiosidade cultural.\n"
        )
    else:  # avancado
        instrucao = (
            "Para cada item abaixo, crie um enunciado com contextualização histórica ou documental "
            "(citando cartas de 1645, crônicas coloniais, guerras ou análise morfológica profunda), "
            "uma explicação histórica rica e uma curiosidade etnográfica.\n"
        )

    return (
        f"Língua: {variante_nome}\n"
        f"Nível: {tier.upper()} | Tema: {tema}\n\n"
        f"{instrucao}\n"
        f"Itens Lexicais:\n{itens_json}\n\n"
        f"Responda APENAS com JSON no formato:\n"
        f'{{\"questoes\":[{{\"item_id\":1,\"enunciado\":\"...\",\"explicacao\":\"...\",\"curiosidade\":\"\"}},...]}}'
    )


# Montagem do QuizResponse final

def _montar_quiz_response(
    esqueleto: list[EsqueletoItem],
    llm_items: list[LLMQuizItem],
    variante_codigo: str,
    dificuldade: str,
    provider: str,
    modelo: str,
    tempo_total_ms: int,
    cache_hit: bool,
) -> QuizResponse:
    """
    Combina o esqueleto lexical (fonte da verdade) com a redação da LLM
    para montar o ``QuizResponse`` final.

    A lógica de posicionamento da resposta correta e dos distratores
    é determinística aqui — a LLM não interfere nessa decisão.
    """
    llm_map: dict[int, LLMQuizItem] = {item.item_id: item for item in llm_items}

    quiz_items: list[QuizItem] = []
    for idx, esq in enumerate(esqueleto, start=1):
        llm = llm_map.get(esq.item_id) or llm_map.get(idx)
        enunciado = (
            llm.enunciado
            if llm and llm.enunciado
            else f"O que significa '{esq.termo_tupi}' em {variante_codigo.replace('_', ' ').title()}?"
        )
        explicacao = (
            llm.explicacao
            if llm and llm.explicacao
            else f"'{esq.termo_tupi}' significa '{esq.traducao_correta}'."
        )
        curiosidade = llm.curiosidade if llm else ""

        # Posição aleatória para a resposta correta (A/B/C/D)
        posicao_correta = random.randint(0, 3)

        # Distratores disponíveis (máximo 3, pode ser menos)
        distratores = list(esq.distratores)[:3]
        # Preenche com fallback se necessário
        while len(distratores) < 3:
            distratores.append(f"[opção {len(distratores) + 1}]")

        alternativas: list[Alternative] = []
        distr_idx = 0
        for pos, letra in enumerate(_LETRAS):
            if pos == posicao_correta:
                texto = esq.traducao_correta
            else:
                texto = distratores[distr_idx] if distr_idx < len(distratores) else "—"
                distr_idx += 1
            alternativas.append(Alternative(letra=letra, texto=texto))

        quiz_items.append(
            QuizItem(
                item_id=idx,
                enunciado=enunciado,
                alternativas=alternativas,
                resposta_correta=_LETRAS[posicao_correta],
                explicacao=explicacao,
                categoria=esq.categoria,
                variante=variante_codigo,
                dificuldade=dificuldade,  # type: ignore[arg-type]
                curiosidade=curiosidade,
                regra_contexto=esq.regra_contexto,
            )
        )

    return QuizResponse(
        questoes=quiz_items,
        provider=provider,
        modelo=modelo,
        tempo_total_ms=tempo_total_ms,
        cache_hit=cache_hit,
    )


# Cache helpers

def _cache_key(variante_codigo: str, categoria: str, nivel: int) -> str:
    raw = f"quiz:v1:{variante_codigo}:{categoria}:{nivel}"
    return "quiz_cache:" + hashlib.sha256(raw.encode()).hexdigest()


def _shuffle_quiz_response(response: QuizResponse) -> QuizResponse:
    """
    Embaralha as alternativas de cada questão e atualiza resposta_correta.
    Retorna uma cópia profunda para não modificar o objeto em cache.
    """
    shuffled = copy.deepcopy(response)
    letras = list(_LETRAS)
    for item in shuffled.questoes:
        # Identifica o texto correto antes do embaralhamento
        texto_correto = next(
            a.texto for a in item.alternativas if a.letra == item.resposta_correta
        )
        random.shuffle(item.alternativas)
        # Re-atribui as letras A/B/C/D e atualiza a resposta correta
        for i, alt in enumerate(item.alternativas):
            alt.letra = letras[i]
        item.resposta_correta = next(  # type: ignore[assignment]
            letras[i]
            for i, alt in enumerate(item.alternativas)
            if alt.texto == texto_correto
        )
    return shuffled


# RAGService — ponto de entrada mantido compatível com views.py

class RAGService:
    """Gera questões de nivelamento para a interface pública do Flutter."""

    def generate(
        self,
        nivel_atual: int,
        variante_codigo: str = "tupi",
    ) -> dict[str, Any]:
        """
        Gera 10 questões de múltipla escolha para o nível e variante especificados.

        Returns:
            Dicionário compatível com o contrato Flutter:
            ``{"questoes": [...]}``

        Raises:
            ValueError: Payload inválido.
            RuntimeError: Falha irrecuperável na geração.
        """
        if _USE_SUPABASE_ENGINE:
            return self._generate_hybrid(nivel_atual, variante_codigo)
        else:
            return self._generate_legacy(nivel_atual, variante_codigo)

    # Novo fluxo: Engine Heurística (USE_SUPABASE_QUIZ_ENGINE=true)

    def _generate_hybrid(
        self,
        nivel_atual: int,
        variante_codigo: str,
    ) -> dict[str, Any]:
        """Gera questões usando a base lexical do Supabase e formatação LLM."""
        t_total = time.monotonic()

        tema, dificuldade = _NIVEL_TEMAS.get(nivel_atual, ("vocabulário geral", "facil"))
        categoria = _NIVEL_CATEGORIA_MAP.get(nivel_atual, "geral")
        variante_nome = _VARIANTE_NOME_MAP.get(
            variante_codigo,
            variante_codigo.replace("_", " ").title(),
        )

        # ── Escalonamento de Proficiência e Orçamento de Tokens ──────────────
        if nivel_atual <= 3:
            tier = "iniciante"
            max_tokens = 800
        elif nivel_atual <= 7:
            tier = "intermediario"
            max_tokens = 1500
        else:
            tier = "avancado"
            max_tokens = 2000

        system_prompt = _get_system_prompt(tier)

        # ── Etapa 1: RPC Supabase (Consulta Léxica com ORDER BY RANDOM()) ─────
        t_rpc = time.monotonic()
        try:
            esqueleto = supabase_service.obter_esqueleto_quiz(
                variante_codigo=variante_codigo,
                categoria=categoria,
                quantidade=10,
            )
        except (SupabaseRPCTimeoutError, SupabaseRPCError, SupabaseServiceError) as exc:
            logger.error("[RAGService] RPC Supabase falhou: %s. Usando fallback legado.", exc)
            return self._generate_legacy(nivel_atual, variante_codigo)

        rpc_ms = int((time.monotonic() - t_rpc) * 1000)
        logger.info(
            "[RAGService] RPC concluída em %d ms. Itens retornados: %d.",
            rpc_ms, len(esqueleto),
        )

        # Se o banco não tiver dados ainda, usa legado como fallback
        if not esqueleto:
            logger.warning(
                "[RAGService] RPC retornou lista vazia para variante=%s. "
                "Usando pipeline legado.",
                variante_codigo,
            )
            return self._generate_legacy(nivel_atual, variante_codigo)

        # ── Etapa 2: Prompt Builder Escalonado ────────────────────────────────
        t_prompt = time.monotonic()
        prompt_usuario = _build_prompt(esqueleto, variante_nome, tema, tier=tier)
        prompt_ms = int((time.monotonic() - t_prompt) * 1000)
        logger.info(
            "[RAGService] Prompt construído em %d ms | tier=%s | ~%d chars.",
            prompt_ms, tier, len(prompt_usuario),
        )

        # ── Etapa 3: LLM via Ping Race Concorrente ────────────────────────────
        t_llm = time.monotonic()
        model_chain = ModelRouter.get_chain_for_task(
            task_type="fast",
            context_length=len(prompt_usuario) // 4,
        )

        provider_usado = ""
        modelo_usado = ""

        try:
            # PING RACE: Dispara um micro-ping em paralelo para os modelos candidatos.
            # O primeiro a responder com HTTP 200 é eleito o vencedor e posicionado
            # no topo da cadeia para gerar a questão imediatamente.
            try:
                winner = PingRaceRouter.get_fastest_model(model_chain)
                logger.info("[RAGService] 🏁 Ping Race elegeu o modelo vencedor: %s", winner)
                provider_usado, modelo_usado = winner.split("/", 1) if "/" in winner else ("LLM", winner)
                # Reordena a cadeia colocando o vencedor em 1º lugar
                model_chain = [winner] + [m for m in model_chain if m != winner]
            except Exception as ping_exc:
                logger.warning("[RAGService] Ping Race encontrou erro (%s). Prosseguindo com fallback padrão.", ping_exc)

            llm_response: LLMQuizResponse = FallbackOrchestrator.execute_with_fallback(
                prompt=f"{system_prompt}\n\n{prompt_usuario}",
                schema=LLMQuizResponse,
                chain=model_chain,
                temperature=0.2,
                max_tokens=max_tokens,
            )
            if not provider_usado and model_chain:
                first = model_chain[0]
                provider_usado, modelo_usado = first.split("/", 1) if "/" in first else ("LLM", first)
        except Exception as exc:
            logger.error(
                "[RAGService] LLM falhou completamente: %s. "
                "Gerando questões heurísticas puras.",
                exc,
            )

            # Fallback heurístico puro — sem LLM, monta questões do esqueleto direto
            llm_response = LLMQuizResponse(
                questoes=[
                    LLMQuizItem(
                        item_id=item.item_id,
                        enunciado=(
                            f"O que significa '{item.termo_tupi}' em {variante_nome}?"
                        ),
                        explicacao=(
                            f"'{item.termo_tupi}' significa '{item.traducao_correta}'."
                            f" {item.regra_contexto}".strip()
                        ),
                        curiosidade="",
                    )
                    for item in esqueleto
                ]
            )

        llm_ms = int((time.monotonic() - t_llm) * 1000)
        logger.info("[RAGService] LLM concluída em %d ms (tier=%s, max_tokens=%d).", llm_ms, tier, max_tokens)

        # ── Etapa 4: Montar QuizResponse final ────────────────────────────────
        tempo_total_ms = int((time.monotonic() - t_total) * 1000)
        quiz_response = _montar_quiz_response(
            esqueleto=esqueleto,
            llm_items=llm_response.questoes,
            variante_codigo=variante_codigo,
            dificuldade=dificuldade,
            provider=provider_usado,
            modelo=modelo_usado,
            tempo_total_ms=tempo_total_ms,
            cache_hit=False,
        )

        # ── Etapa 5: Embaralha e retorna (Geração 100% dinâmica) ──────────────
        shuffled = _shuffle_quiz_response(quiz_response)

        logger.info(
            "[RAGService] Quiz gerado com sucesso em tempo real. Total: %d ms "
            "(rpc=%d ms, llm=%d ms).",
            tempo_total_ms, rpc_ms, llm_ms,
        )

        return shuffled.model_dump()

    # Legado: GraphRAG (USE_SUPABASE_QUIZ_ENGINE=false)

    def _generate_legacy(
        self,
        nivel_atual: int,
        variante_codigo: str = "tupi",
    ) -> dict[str, Any]:
        """Pipeline legado baseado no GraphRAG (usado como fallback de segurança)."""
        from pydantic import BaseModel as _BaseModel, Field as _Field
        from typing import List as _List

        class QuestaoSchema(_BaseModel):
            enunciado: str
            alternativas: _List[dict]
            resposta_correta: str
            explicacao: str
            categoria: str = "geral"

        class _ExameSchema(_BaseModel):
            questoes: _List[QuestaoSchema] = _Field(default_factory=list)

        temas = {
            1: "palavras basicas do dia a dia, animais comuns",
            2: "verbos basicos, acoes",
            3: "natureza, geografia basica",
            4: "mitologia, Tupa",
            5: "historia do Brasil pre-colonial",
            6: "nomes de lugares (toponimia)",
            7: "gramatica intermediaria",
            8: "estrutura de frases complexas",
            9: "poesia e canticos",
            10: "textos historicos fluentes",
        }
        tema = temas.get(nivel_atual, "vocabulario geral")
        variante_nome = _VARIANTE_NOME_MAP.get(
            variante_codigo,
            variante_codigo.replace("_", " ").title(),
        )

        # Contexto RAG mínimo (truncado a 2000 chars para evitar 413)
        try:
            db = SQLiteVectorDB("vector_store.db")
            graph = get_graph()
            contexto = graph.search_subgraph(
                [0.0] * 384, top_k=3, neighbors=0
            )[:2000]
        except Exception:
            contexto = "Contexto indisponível."

        prompt = (
            f"Você é professor de {variante_nome}.\n"
            f"Crie exatamente 10 questões de múltipla escolha. Nível {nivel_atual}/10. "
            f"Tema: {tema}.\n"
            f"Contexto (máx 2000 chars):\n{contexto}\n\n"
            f"Retorne APENAS JSON com chave 'questoes'."
        )

        chain = ModelRouter.get_chain_for_task(task_type="fast")
        try:
            resultado: _ExameSchema = FallbackOrchestrator.execute_with_fallback(
                prompt=prompt,
                schema=_ExameSchema,
                chain=chain,
                temperature=0.6,
            )
            result_dict = resultado.model_dump()
            return self._shuffle_legacy(result_dict)
        except Exception as exc:
            logger.error("[RAGService][Legacy] Falha completa: %s", exc)
            raise RuntimeError(f"Falha ao gerar questões (legado): {exc}") from exc

    def _shuffle_legacy(self, result_dict: dict[str, Any]) -> dict[str, Any]:
        """Embaralha as alternativas no formato do pipeline legado."""
        shuffled = copy.deepcopy(result_dict)
        for q in shuffled.get("questoes", []):
            alternativas = q.get("alternativas", [])
            correct_letter = q.get("resposta_correta")
            correct_text = next(
                (a.get("texto") for a in alternativas if a.get("letra") == correct_letter),
                "",
            )
            random.shuffle(alternativas)
            letras = ["A", "B", "C", "D", "E"]
            for idx, alt in enumerate(alternativas):
                new_letter = letras[idx] if idx < len(letras) else str(idx)
                alt["letra"] = new_letter
                if alt.get("texto") == correct_text:
                    q["resposta_correta"] = new_letter
        return shuffled
