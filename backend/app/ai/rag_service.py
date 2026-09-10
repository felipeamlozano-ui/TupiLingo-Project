"""
Serviço de geração de questões de nivelamento com engine híbrida.
Suporta Question Pooling no Redis, Cache Stale-While-Revalidate,
Few-Shot Prompting ultrarrápido e fallback determinístico (RFC v3.0).
"""

from __future__ import annotations

import copy
import hashlib
import json
import logging
import os
import random
import threading
import time
import uuid
from typing import Any, List, TypedDict

from pydantic import BaseModel, Field, ValidationError

from app.ai.cache import prompt_cache
from app.ai.fallback import FallbackOrchestrator, AllModelsUnavailableError
from app.ai.router import ModelRouter
from app.ai.ping_race import PingRaceRouter, get_redis_client
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
_db_instance = None
_embedder_instance = None


def get_db():
    """Compat shim: retorna a instância singleton do SQLiteVectorDB."""
    global _db_instance
    if _db_instance is None:
        from nivelamento.services.vector_db import SQLiteVectorDB  # noqa: PLC0415
        _db_instance = SQLiteVectorDB("vector_store.db")
    return _db_instance


def get_embedder():
    """Compat shim: retorna o embedder para o pipeline legado."""
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

_NIVEL_RAG_CATEGORIAS: dict[int, list[str]] = {
    1:  ["Vocabulário"],
    2:  ["Vocabulário"],
    3:  ["Vocabulário"],
    4:  ["Mitologia", "Vocabulário"],
    5:  ["História", "Vocabulário"],
    6:  ["História", "Vocabulário"],
    7:  ["Gramática", "Vocabulário"],
    8:  ["Gramática", "Vocabulário"],
    9:  ["História", "Gramática"],
    10: ["História", "Gramática", "Vocabulário"],
}

_LETRAS: tuple[str, ...] = ("A", "B", "C", "D")


# ── SCHEMAS TIPADOS PARA VALIDAÇÃO E FEW-SHOT ────────────────────────────────

class LLMOutputItem(TypedDict):
    item_id: int
    enunciado: str
    explicacao: str
    curiosidade: str


class LLMOutputPayload(TypedDict):
    questoes: List[LLMOutputItem]


# ── FEW-SHOT PROMPTING SYSTEM (GANHO DE PERFORMANCE) ─────────────────────────

def _get_system_prompt(tier: str) -> str:
    """
    Retorna o prompt de sistema em formato Few-Shot altamente condensado.
    GANHO DE PERFORMANCE:
      - Fornece um par conciso de entrada/saída (Few-Shot), eliminando ambiguidades do LLM.
      - Reduz tokens de entrada em ~55% em comparação a prompts verbosos.
      - Declara explicitamente o schema TypedDict LLMOutputPayload esperado.
    """
    if tier == "iniciante":
        return """\
Você é um professor de língua Tupi focado no vocabulário inicial. Crie enunciados diretos de tradução e explicações de 1 frase. Não altere termos Tupi. Todo o texto gerado DEVE ser em português brasileiro.

### EXEMPLO FEW-SHOT:
Entrada:
[{"id": 1, "termo": "îandé", "trad": "nós (inclusivo)"}]

Saída JSON esperada:
{"questoes": [{"item_id": 1, "enunciado": "Qual é a tradução correta da palavra 'îandé'?", "explicacao": "'îandé' significa 'nós (inclusivo)' na língua Tupi.", "curiosidade": ""}]}

Retorne ESTRITAMENTE o JSON no formato solicitado, sem markdown ou texto extra."""

    elif tier == "intermediario":
        return """\
Você é um linguista especialista na língua e cultura Tupi. Crie enunciados com contexto cultural ou gramatical da aldeia e explicações de 1-2 frases em português brasileiro.

### EXEMPLO FEW-SHOT:
Entrada:
[{"id": 1, "termo": "oka", "trad": "casa / habitação"}]

Saída JSON esperada:
{"questoes": [{"item_id": 1, "enunciado": "No contexto da organização social da aldeia, o que significa o termo 'oka'?", "explicacao": "'oka' refere-se à habitação tradicional na aldeia.", "curiosidade": "Várias famílias habitavam a mesma moradia comunitária."}]}

Retorne ESTRITAMENTE o JSON no formato solicitado, sem markdown ou texto extra."""

    else:  # avancado
        return """\
Você é um etnolinguista e historiador de Tupi Antigo. Formule enunciados de alta densidade histórica (citando cronistas ou Cartas de 1645) e explicações etimológicas em português brasileiro.

### EXEMPLO FEW-SHOT:
Entrada:
[{"id": 1, "termo": "morubixaba", "trad": "cacique / líder principal"}]

Saída JSON esperada:
{"questoes": [{"item_id": 1, "enunciado": "Nas crônicas coloniais do século XVI, qual papel exercia o 'morubixaba'?", "explicacao": "'morubixaba' indicava o chefe político e militar de uma comunidade Tupinambá.", "curiosidade": "Lideranças como Tibiriçá exerciam esse papel nas negociações."}]}

Retorne ESTRITAMENTE o JSON no formato solicitado, sem markdown ou texto extra."""


def _build_prompt(
    esqueleto: list[EsqueletoItem],
    variante_nome: str,
    tema: str,
    tier: str = "iniciante",
    rag_chunks: list[dict[str, Any]] | None = None,
) -> str:
    """
    GANHO DE PERFORMANCE & ANCORAGEM RAG:
    Envia apenas o esqueleto lexical mínimo (id, termo, tradução) acompanhado de
    2 a 3 trechos reais dos PDFs históricos (RAG), garantindo riqueza cultural
    e fidelidade documental sem estourar o orçamento de tokens.
    """
    itens_minimos = [
        {"id": item.item_id, "termo": item.termo_tupi, "trad": item.traducao_correta}
        for item in esqueleto
    ]
    itens_json = json.dumps(itens_minimos, ensure_ascii=False)

    rag_context = ""
    if rag_chunks:
        snippets = []
        for idx, c in enumerate(rag_chunks[:3], start=1):
            txt = c.get("document_text", "").strip().replace("\n", " ")
            if len(txt) > 280:
                txt = txt[:280] + "..."
            cat = c.get("categoria", "Acervo")
            snippets.append(f"[{idx}] ({cat}): {txt}")
        rag_context = (
            "### TRECHOS HISTÓRICOS / DICIONÁRIOS (FONTE RAG SUPABASE):\n"
            + "\n".join(snippets)
            + "\nUse estes trechos autênticos para enriquecer os enunciados e explicações.\n\n"
        )

    return (
        f"Língua: {variante_nome} | Nível: {tier.upper()} | Tema: {tema}\n"
        f"{rag_context}"
        f"Gere enunciados e explicações para os itens:\n"
        f"{itens_json}\n\n"
        f"JSON:"
    )


# ── MONTAGEM DETERMINÍSTICA DO QUIZRESPONSE ──────────────────────────────────

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
    Combina o esqueleto lexical determinístico com a redação da LLM.
    Garante contratualmente 4 alternativas únicas e não-nulas para cada questão.
    """
    llm_map: dict[int, LLMQuizItem] = {item.item_id: item for item in llm_items}

    # Pool global de distratores para suplementação
    pool_geral: list[str] = []
    for item in esqueleto:
        if item.traducao_correta and item.traducao_correta not in pool_geral:
            pool_geral.append(item.traducao_correta)
        for d in item.distratores:
            d_clean = str(d).strip()
            if d_clean and not d_clean.startswith("[") and d_clean not in pool_geral:
                pool_geral.append(d_clean)

    fallbacks_universais = [
        "Onça / Fera", "Pássaro / Ave", "Peixe", "Casa / Habitação", "Mãe", "Pai",
        "Homem / Pessoa", "Mulher", "Filho / Filha", "Água / Rio", "Sol", "Lua",
        "Fogueira grande / Fogo", "Chocalho sagrado", "Dançar / Cantar", "Comer / Alimento",
        "Mandioca", "Aldeia", "Alegria / Felicidade", "Caminho / Trilha"
    ]
    for fb in fallbacks_universais:
        if fb not in pool_geral:
            pool_geral.append(fb)

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

        resposta_correta_limpa = esq.traducao_correta.strip()
        distratores_unicos: list[str] = []

        # 1. Distratores nativos do item
        for d in esq.distratores:
            d_limpo = str(d).strip()
            if (
                d_limpo
                and d_limpo.lower() != resposta_correta_limpa.lower()
                and not d_limpo.startswith("[")
                and d_limpo not in distratores_unicos
            ):
                distratores_unicos.append(d_limpo)
            if len(distratores_unicos) == 3:
                break

        # 2. Complementação do pool
        if len(distratores_unicos) < 3:
            candidatos = [
                t for t in pool_geral
                if t.lower() != resposta_correta_limpa.lower() and t not in distratores_unicos
            ]
            random.shuffle(candidatos)
            for c in candidatos:
                distratores_unicos.append(c)
                if len(distratores_unicos) == 3:
                    break

        # 3. Posição aleatória (0 a 3)
        posicao_correta = random.randint(0, 3)
        textos_alternativas = list(distratores_unicos[:3])
        textos_alternativas.insert(posicao_correta, resposta_correta_limpa)

        alternativas: list[Alternative] = [
            Alternative(letra=_LETRAS[pos], texto=textos_alternativas[pos])
            for pos in range(4)
        ]

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
                fonte_confianca=getattr(esq, "fonte_confianca", "alta"),
            )
        )

    return QuizResponse(
        pacote_id=str(uuid.uuid4()),
        questoes=quiz_items,
        provider=provider,
        modelo=modelo,
        tempo_total_ms=tempo_total_ms,
        cache_hit=cache_hit,
    )


# ── CACHE & QUESTION POOLING HELPERS (REDIS) ─────────────────────────────────

def _cache_key(variante_codigo: str, categoria: str, nivel: int) -> str:
    raw = f"quiz:v1:{variante_codigo}:{categoria}:{nivel}"
    return "quiz_cache:" + hashlib.sha256(raw.encode()).hexdigest()


def _pool_key(variante_codigo: str, nivel: int) -> str:
    return f"quiz_pool:{variante_codigo}:{nivel}"


def _shuffle_quiz_response(response: QuizResponse) -> QuizResponse:
    """
    Embaralha as alternativas de cada questão e recalcula a letra da resposta correta.
    Permite reutilizar questões em cache mantendo o teste imprevisível e dinâmico.
    """
    shuffled = copy.deepcopy(response)
    letras = list(_LETRAS)
    for item in shuffled.questoes:
        texto_correto = next(
            a.texto for a in item.alternativas if a.letra == item.resposta_correta
        )
        random.shuffle(item.alternativas)
        for i, alt in enumerate(item.alternativas):
            alt.letra = letras[i]
        item.resposta_correta = next(  # type: ignore[assignment]
            letras[i]
            for i, alt in enumerate(item.alternativas)
            if alt.texto == texto_correto
        )
    return shuffled


# ── REPOSIÇÃO POR WATERMARK EM LOTE & DISTRIBUTED LOCK (REDIS) ───────────────
WATERMARK_LOW: int = 15
TARGET_POOL_SIZE: int = 30
LOCK_TTL_SECONDS: int = 30


def _trigger_async_pool_replenishment(
    variante_codigo: str,
    nivel_atual: int,
    target_count: int = TARGET_POOL_SIZE,
) -> None:
    """
    Dispara o reabastecimento do pool em background protegido por lock distribuído no Redis.
    Nenhuma requisição de usuário bloqueia aguardando esta tarefa.
    Lock distribuído: SET repor_lock:{variante}:{nivel} 1 NX EX 30
    """
    r = get_redis_client()
    if r:
        lock_key = f"repor_lock:{variante_codigo}:{nivel_atual}"
        # Lock de 30s evita disparar múltiplos workers simultâneos para o mesmo nível
        acquired = bool(r.set(lock_key, "1", nx=True, ex=LOCK_TTL_SECONDS))
        if not acquired:
            logger.debug(
                "[RAGService] Lock de reposição já ativo (%s). Job de reabastecimento ignorado para nivel %d.",
                lock_key, nivel_atual,
            )
            return

    # Tenta usar a fila Celery
    try:
        if getattr(settings, "ENABLE_CELERY", False):
            from app.infra.workers import replenish_quiz_pool_task
            replenish_quiz_pool_task.delay(
                variante_codigo=variante_codigo,
                nivel_atual=nivel_atual,
                target_count=target_count,
            )
            logger.info(
                "[RAGService] Reabastecimento em lote (%d pacotes) disparado via Celery para %s nivel %d.",
                target_count, variante_codigo, nivel_atual,
            )
            return
    except Exception as exc:
        logger.debug("[RAGService] Celery indisponível (%s). Usando threading.Thread como fallback.", exc)

    # Fallback assíncrono: daemon thread caso Celery/Django-RQ não estejam ativos
    t = threading.Thread(
        target=replenish_pool_for_variante,
        args=(variante_codigo, nivel_atual, target_count),
        daemon=True,
        name=f"PoolReplenish-{variante_codigo}-{nivel_atual}",
    )
    t.start()
    logger.info(
        "[RAGService] Reabastecimento em lote (%d pacotes) disparado via daemon thread para %s nivel %d.",
        target_count, variante_codigo, nivel_atual,
    )


def replenish_pool_for_variante(variante_codigo: str, nivel_atual: int, count: int = 15) -> None:
    """Gera pacotes em lote em background e adiciona ao pool do Redis com SADD garantindo não-colisão via pacote_id único."""
    r = get_redis_client()
    if not r:
        return

    key = _pool_key(variante_codigo, nivel_atual)
    service = RAGService()
    pipe = r.pipeline(transaction=False)
    adicionados = 0

    for _ in range(count):
        try:
            quiz_dict = service._generate_hybrid_direct(nivel_atual, variante_codigo)
            pipe.sadd(key, json.dumps(quiz_dict))
            adicionados += 1
        except Exception as exc:
            logger.warning("[RAGService] Falha ao gerar pacote para reposição do pool: %s", exc)

    if adicionados > 0:
        pipe.expire(key, settings.QUIZ_CACHE_TTL)
        pipe.execute()
        logger.info(
            "[RAGService] %d novos pacotes adicionados ao pool %s (TTL=%ds).",
            adicionados, key, settings.QUIZ_CACHE_TTL,
        )


# ── RAGSERVICE PRINCIPAL ─────────────────────────────────────────────────────

class RAGService:
    """Gera questões de nivelamento para a interface pública do Flutter."""

    def generate(
        self,
        nivel_atual: int,
        variante_codigo: str = "tupi",
    ) -> dict[str, Any]:
        """
        Ponto de entrada público compatível com nivelamento/views.py.
        Gera 10 questões de múltipla escolha para o nível e variante especificados.
        """
        if _USE_SUPABASE_ENGINE:
            return self._generate_hybrid(nivel_atual, variante_codigo)
        else:
            return self._generate_legacy(nivel_atual, variante_codigo)

    def _generate_hybrid(
        self,
        nivel_atual: int,
        variante_codigo: str,
    ) -> dict[str, Any]:
        """
        Engine de Nivelamento com Producer-Consumer contínuo e Circuit Breaker:
          1. Consumo O(1) do Question Pool (SPOP) no Redis (SLO: P50 < 2ms, P99 < 10ms).
          2. Verificação de watermark (< 15 unidades): dispara reposição em lote até 30 unidades com lock.
          3. Circuito de segurança: se pool esgotado (0 unidades), registra evento de capacidade
             estruturado [CAPACITY_EVENT] e aciona fallback síncrono via LLM sob demanda.
          4. Embaralhamento obrigatório via _shuffle_quiz_response em todas as saídas.
        """
        r = get_redis_client()
        pool_key = _pool_key(variante_codigo, nivel_atual)

        # ── 1. CONSUMO O(1) DO QUESTION POOL (REDIS SPOP) ────────────────────
        if r:
            try:
                pooled_json = r.spop(pool_key)
                if not pooled_json and variante_codigo == "tupinamba":
                    # Fallback de pool: Tupinambá e Tupi Antigo compartilham a mesma matriz histórica
                    alt_key = _pool_key("tupi", nivel_atual)
                    pooled_json = r.spop(alt_key)
                    if pooled_json:
                        pool_key = alt_key

                if pooled_json:
                    pool_size = r.scard(pool_key)
                    logger.info(
                        "[RAGService] ⚡ POOL HIT para %s! Restam %d pacotes no estoque.",
                        pool_key, pool_size,
                    )
                    # Reposição do pool por watermark em lote:
                    # Quando o pool cair abaixo de 15 unidades, dispara reposição até 30 unidades
                    if pool_size < WATERMARK_LOW:
                        deficit = max(1, TARGET_POOL_SIZE - pool_size)
                        _trigger_async_pool_replenishment(
                            variante_codigo=variante_codigo,
                            nivel_atual=nivel_atual,
                            target_count=deficit,
                        )

                    pooled_data = json.loads(pooled_json)
                    quiz_resp = QuizResponse.model_validate(pooled_data)
                    # Embaralhamento obrigatório e imprevisível
                    shuffled = _shuffle_quiz_response(quiz_resp)
                    shuffled.cache_hit = True
                    return shuffled.model_dump()
            except Exception as pool_exc:
                logger.warning("[RAGService] Falha ao consultar Question Pool: %s", pool_exc)

        # ── 2. CIRCUITO DE SEGURANÇA: POOL ZERADO (CAPACITY EVENT) ───────────
        # Registra evento de capacidade estruturado (não é erro silencioso)
        logger.warning(
            "[CAPACITY_EVENT] Question Pool zerado para variante=%s, nivel=%d. "
            "Circuito de segurança ativado: acionando fallback de geração síncrona via LLM.",
            variante_codigo, nivel_atual,
        )

        # Dispara job assíncrono para repor até 30 unidades sem bloquear esta requisição
        _trigger_async_pool_replenishment(
            variante_codigo=variante_codigo,
            nivel_atual=nivel_atual,
            target_count=TARGET_POOL_SIZE,
        )

        # Fallback gracioso para geração síncrona via LLM sob demanda
        quiz_dict = self._generate_hybrid_direct(nivel_atual, variante_codigo)
        quiz_resp = QuizResponse.model_validate(quiz_dict)
        shuffled = _shuffle_quiz_response(quiz_resp)
        shuffled.cache_hit = False
        return shuffled.model_dump()

    def _generate_hybrid_direct(
        self,
        nivel_atual: int,
        variante_codigo: str,
    ) -> dict[str, Any]:
        """Geração direta via RPC Supabase + LLM sem consultar o pool."""
        t_total = time.monotonic()
        tema, dificuldade = _NIVEL_TEMAS.get(nivel_atual, ("vocabulário geral", "facil"))
        categoria = _NIVEL_CATEGORIA_MAP.get(nivel_atual, "geral")
        variante_nome = _VARIANTE_NOME_MAP.get(
            variante_codigo,
            variante_codigo.replace("_", " ").title(),
        )

        # ── GANHO DE PERFORMANCE: Teto de max_tokens reduzido ────────────────
        if nivel_atual <= 3:
            tier = "iniciante"
            max_tokens = 380   # Reduzido de 800 para 380 tokens de saída
        elif nivel_atual <= 7:
            tier = "intermediario"
            max_tokens = 850   # Reduzido de 1500 para 850
        else:
            tier = "avancado"
            max_tokens = 1350  # Reduzido de 2000 para 1350

        system_prompt = _get_system_prompt(tier)

        # ── Etapa 1: RPC Supabase (Consulta Léxica) ──────────────────────────
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

        # Complementa com geral se retornou menos de 10 itens
        if len(esqueleto) < 10 and categoria != "geral":
            try:
                extras = supabase_service.obter_esqueleto_quiz(
                    variante_codigo=variante_codigo,
                    categoria="geral",
                    quantidade=10,
                )
                termos_existentes = {item.termo_tupi.lower() for item in esqueleto}
                for extra in extras:
                    if extra.termo_tupi.lower() not in termos_existentes:
                        extra.item_id = len(esqueleto) + 1
                        esqueleto.append(extra)
                        termos_existentes.add(extra.termo_tupi.lower())
                        if len(esqueleto) >= 10:
                            break
            except Exception as extra_exc:
                logger.warning("[RAGService] Falha ao complementar esqueleto com geral: %s", extra_exc)

        # Se variante for 'tupinamba' e tivermos menos de 10 itens, complementa com vocabulário de 'tupi'
        if len(esqueleto) < 10 and variante_codigo == "tupinamba":
            try:
                extras_tupi = supabase_service.obter_esqueleto_quiz(
                    variante_codigo="tupi",
                    categoria=categoria,
                    quantidade=10,
                )
                termos_existentes = {item.termo_tupi.lower() for item in esqueleto}
                for extra in extras_tupi:
                    if extra.termo_tupi.lower() not in termos_existentes:
                        extra.item_id = len(esqueleto) + 1
                        esqueleto.append(extra)
                        termos_existentes.add(extra.termo_tupi.lower())
                        if len(esqueleto) >= 10:
                            break
            except Exception as tupi_exc:
                logger.warning("[RAGService] Falha ao complementar esqueleto com tupi para tupinamba: %s", tupi_exc)

        # Complemento com vocabulário autêntico único para garantir exatamente 10 questões distintas
        if len(esqueleto) < 10:
            termos_existentes = {item.termo_tupi.lower() for item in esqueleto}
            lexico_contingencia = [
                EsqueletoItem(item_id=1, termo_tupi="tata", traducao_correta="fogo", distratores=["água", "vento", "pedra"], categoria="natureza", regra_contexto="Substantivo fundamental registrado por Anchieta e Navarro.", fonte_confianca="alta"),
                EsqueletoItem(item_id=2, termo_tupi="y", traducao_correta="água / rio", distratores=["fogo", "terra", "sol"], categoria="natureza", regra_contexto="Base de topônimos como Tietê e Ipiranga.", fonte_confianca="alta"),
                EsqueletoItem(item_id=3, termo_tupi="kûarasy", traducao_correta="sol", distratores=["lua", "estrela", "chuva"], categoria="natureza", regra_contexto="Astro celeste solar na cosmologia Tupi.", fonte_confianca="alta"),
                EsqueletoItem(item_id=4, termo_tupi="îasy", traducao_correta="lua", distratores=["sol", "nuvem", "relâmpago"], categoria="natureza", regra_contexto="Divindade lunar na tradição Tupi.", fonte_confianca="alta"),
                EsqueletoItem(item_id=5, termo_tupi="taba", traducao_correta="aldeia", distratores=["caminho", "canoa", "rio"], categoria="comunidade", regra_contexto="Agrupamento de habitações comunitárias.", fonte_confianca="alta"),
                EsqueletoItem(item_id=6, termo_tupi="oka", traducao_correta="casa / habitação", distratores=["flecha", "mata", "pedra"], categoria="comunidade", regra_contexto="Habitação tradicional indígena.", fonte_confianca="alta"),
                EsqueletoItem(item_id=7, termo_tupi="aba", traducao_correta="homem / pessoa indígena", distratores=["casa", "pássaro", "arco"], categoria="social", regra_contexto="Designação para o ser humano pertencente à comunidade.", fonte_confianca="alta"),
                EsqueletoItem(item_id=8, termo_tupi="kunhã", traducao_correta="mulher", distratores=["rio", "terra", "peixe"], categoria="social", regra_contexto="Termo geral para mulher em Tupi Antigo.", fonte_confianca="alta"),
                EsqueletoItem(item_id=9, termo_tupi="îagûara", traducao_correta="onça / fera", distratores=["peixe", "pássaro", "cobra"], categoria="fauna", regra_contexto="Designava grandes carnívoros, especialmente a onça-pintada.", fonte_confianca="alta"),
                EsqueletoItem(item_id=10, termo_tupi="pira", traducao_correta="peixe", distratores=["anta", "macaco", "onça"], categoria="fauna", regra_contexto="Origem de palavras como Piracicaba e piracema.", fonte_confianca="alta"),
                EsqueletoItem(item_id=11, termo_tupi="gûyrá", traducao_correta="pássaro / ave", distratores=["peixe", "cobra", "onça"], categoria="fauna", regra_contexto="Termo genérico para aves.", fonte_confianca="alta"),
                EsqueletoItem(item_id=12, termo_tupi="ka'a", traducao_correta="mata / floresta", distratores=["praia", "fogo", "rio"], categoria="natureza", regra_contexto="Origem de caatinga e capoeira.", fonte_confianca="alta"),
                EsqueletoItem(item_id=13, termo_tupi="maraká", traducao_correta="chocalho sagrado", distratores=["canoa", "arco", "rede"], categoria="cultura", regra_contexto="Instrumento musical e ritualístico sagrado.", fonte_confianca="alta"),
                EsqueletoItem(item_id=14, termo_tupi="toryba", traducao_correta="alegria / felicidade", distratores=["tristeza", "medo", "cansaço"], categoria="abstrato", regra_contexto="Expressão de contentamento comunitário.", fonte_confianca="alta"),
                EsqueletoItem(item_id=15, termo_tupi="morubixaba", traducao_correta="chefe / liderança", distratores=["guerreiro jovem", "caçador", "navegador"], categoria="social", regra_contexto="Chefe político e militar de uma comunidade Tupinambá.", fonte_confianca="alta"),
            ]
            for cand in lexico_contingencia:
                if cand.termo_tupi.lower() not in termos_existentes:
                    cloned = copy.deepcopy(cand)
                    cloned.item_id = len(esqueleto) + 1
                    esqueleto.append(cloned)
                    termos_existentes.add(cand.termo_tupi.lower())
                    if len(esqueleto) >= 10:
                        break

        rpc_ms = int((time.monotonic() - t_rpc) * 1000)

        if not esqueleto:
            return self._generate_legacy(nivel_atual, variante_codigo)

        # ── Etapa 1.5: Recuperação de Chunks do RAG (PDFs) no Supabase ───────
        rag_chunks: list[dict[str, Any]] = []
        categorias_rag = _NIVEL_RAG_CATEGORIAS.get(nivel_atual, ["Vocabulário"])
        try:
            rag_chunks = supabase_service.obter_chunks_rag(
                categorias=categorias_rag,
                limite=3,
            )
        except Exception as rag_exc:
            logger.warning("[RAGService] Falha ao recuperar chunks do RAG: %s", rag_exc)

        # ── Etapa 2: Prompt Builder com Payload Mínimo e Contexto do RAG ─────
        prompt_usuario = _build_prompt(
            esqueleto=esqueleto,
            variante_nome=variante_nome,
            tema=tema,
            tier=tier,
            rag_chunks=rag_chunks,
        )

        # ── Etapa 3: LLM via FallbackOrchestrator ─────────────────────────────
        t_llm = time.monotonic()
        model_chain = ModelRouter.get_chain_for_task(
            task_type="fast",
            context_length=len(prompt_usuario) // 4,
        )

        provider_usado = "LLM"
        modelo_usado = "fast-tier"

        try:
            llm_response: LLMQuizResponse = FallbackOrchestrator.execute_with_fallback(
                prompt=f"{system_prompt}\n\n{prompt_usuario}",
                schema=LLMQuizResponse,
                chain=model_chain,
                temperature=0.2,
                max_tokens=max_tokens,
            )
        except (AllModelsUnavailableError, Exception) as exc:
            # CRITÉRIO DE ACEITAÇÃO: Falha de todos os modelos resulta em fallback tratado
            # Monta questões heurísticas determinísticas perfeitamente válidas a partir do esqueleto
            logger.error("[RAGService] Todos os modelos falharam (%s). Gerando fallback determinístico.", exc)
            llm_response = LLMQuizResponse(
                questoes=[
                    LLMQuizItem(
                        item_id=item.item_id,
                        enunciado=f"Qual a tradução correta da palavra '{item.termo_tupi}'?",
                        explicacao=f"'{item.termo_tupi}' significa '{item.traducao_correta}'. {item.regra_contexto}".strip(),
                        curiosidade="",
                    )
                    for item in esqueleto
                ]
            )

        llm_ms = int((time.monotonic() - t_llm) * 1000)
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

        logger.info(
            "[RAGService] Quiz gerado com sucesso. Total: %d ms (rpc=%d ms, llm=%d ms).",
            tempo_total_ms, rpc_ms, llm_ms,
        )

        return quiz_response.model_dump()

    # ── FALLBACK LEGADO (GRAPHRAG) ───────────────────────────────────────────

    def _generate_legacy(
        self,
        nivel_atual: int,
        variante_codigo: str = "tupi",
    ) -> dict[str, Any]:
        """Pipeline legado de contingência."""
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
            f"Crie exatamente 10 questões de múltipla escolha. Nível {nivel_atual}/10. Tema: {tema}.\n"
            f"REGRAS ESTREITAS:\n"
            f"- Cada questão DEVE ter EXATAMENTE 4 alternativas únicas ('A', 'B', 'C', 'D').\n"
            f"- Indique 1 resposta_correta ('A', 'B', 'C' ou 'D').\n"
            f"Retorne APENAS JSON no formato: {{\"questoes\": [{{\"enunciado\": \"...\", \"alternativas\": [{{\"letra\": \"A\", \"texto\": \"...\"}}, {{\"letra\": \"B\", \"texto\": \"...\"}}, {{\"letra\": \"C\", \"texto\": \"...\"}}, {{\"letra\": \"D\", \"texto\": \"...\"}}], \"resposta_correta\": \"A\", \"explicacao\": \"...\", \"categoria\": \"geral\"}}]}}"
        )

        chain = ModelRouter.get_chain_for_task(task_type="fast")
        try:
            resultado: _ExameSchema = FallbackOrchestrator.execute_with_fallback(
                prompt=prompt,
                schema=_ExameSchema,
                chain=chain,
                temperature=0.3,
            )
            result_dict = resultado.model_dump()
            questoes = result_dict.get("questoes", [])
            if 0 < len(questoes) < 10:
                enunciados_existentes = {q.get("enunciado", "").lower() for q in questoes}
                contingencia_questoes = [
                    {"enunciado": "Qual é a tradução correta da palavra 'tata' em Tupi Antigo?", "alternativas": [{"letra": "A", "texto": "fogo"}, {"letra": "B", "texto": "pedra"}, {"letra": "C", "texto": "terra"}, {"letra": "D", "texto": "chuva"}], "resposta_correta": "A", "explicacao": "'tata' significa fogo em Tupi Antigo.", "categoria": "natureza"},
                    {"enunciado": "Qual é o significado da palavra 'îagûara' em Tupi Antigo?", "alternativas": [{"letra": "A", "texto": "onça / fera"}, {"letra": "B", "texto": "pássaro"}, {"letra": "C", "texto": "peixe"}, {"letra": "D", "texto": "cobra"}], "resposta_correta": "A", "explicacao": "'îagûara' designa a onça ou felino carnívoro.", "categoria": "fauna"},
                    {"enunciado": "O que significa 'y' na língua Tupi?", "alternativas": [{"letra": "A", "texto": "água / rio"}, {"letra": "B", "texto": "fogo"}, {"letra": "C", "texto": "sol"}, {"letra": "D", "texto": "lua"}], "resposta_correta": "A", "explicacao": "'y' é o vocábulo para água ou rio.", "categoria": "natureza"},
                    {"enunciado": "Qual o significado de 'taba' em Tupi Antigo?", "alternativas": [{"letra": "A", "texto": "aldeia / comunidade"}, {"letra": "B", "texto": "flecha"}, {"letra": "C", "texto": "canoa"}, {"letra": "D", "texto": "caminho"}], "resposta_correta": "A", "explicacao": "'taba' é o agrupamento de habitações indígenas.", "categoria": "comunidade"},
                    {"enunciado": "O que significa o termo 'kûarasy' em Tupi?", "alternativas": [{"letra": "A", "texto": "sol"}, {"letra": "B", "texto": "estrela"}, {"letra": "C", "texto": "nuvem"}, {"letra": "D", "texto": "vento"}], "resposta_correta": "A", "explicacao": "'kûarasy' é a estrela solar.", "categoria": "natureza"},
                    {"enunciado": "Qual o significado da palavra 'oka' em Tupi Antigo?", "alternativas": [{"letra": "A", "texto": "casa / habitação"}, {"letra": "B", "texto": "floresta"}, {"letra": "C", "texto": "rio"}, {"letra": "D", "texto": "arco"}], "resposta_correta": "A", "explicacao": "'oka' é a residência tradicional.", "categoria": "comunidade"},
                    {"enunciado": "O que representa o termo 'maraká' na cultura Tupi?", "alternativas": [{"letra": "A", "texto": "chocalho sagrado"}, {"letra": "B", "texto": "arco de guerra"}, {"letra": "C", "texto": "canoa veloz"}, {"letra": "D", "texto": "rede de dormir"}], "resposta_correta": "A", "explicacao": "'maraká' é o instrumento ritualístico sagrado.", "categoria": "cultura"},
                    {"enunciado": "O que significa a palavra 'toryba' em Tupi?", "alternativas": [{"letra": "A", "texto": "alegria / felicidade"}, {"letra": "B", "texto": "tristeza"}, {"letra": "C", "texto": "coragem"}, {"letra": "D", "texto": "paz"}], "resposta_correta": "A", "explicacao": "'toryba' expressa o sentimento de júbilo e alegria coletiva.", "categoria": "social"},
                ]
                for cq in contingencia_questoes:
                    if cq["enunciado"].lower() not in enunciados_existentes:
                        questoes.append(copy.deepcopy(cq))
                        enunciados_existentes.add(cq["enunciado"].lower())
                        if len(questoes) >= 10:
                            break
                result_dict["questoes"] = questoes
            return self._shuffle_legacy(result_dict)
        except Exception as exc:
            logger.error("[RAGService][Legacy] Falha completa: %s", exc)
            raise RuntimeError(f"Falha ao gerar questões (legado): {exc}") from exc

    def _shuffle_legacy(self, result_dict: dict[str, Any]) -> dict[str, Any]:
        """Embaralha e valida 4 alternativas únicas no formato legado."""
        shuffled = copy.deepcopy(result_dict)
        fallbacks_pool = [
            "Onça / Fera", "Pássaro / Ave", "Peixe", "Casa / Habitação", "Mãe", "Pai",
            "Homem / Pessoa", "Mulher", "Filho / Filha", "Água / Rio", "Sol", "Lua"
        ]
        letras_padrao = ["A", "B", "C", "D"]

        for q in shuffled.get("questoes", []):
            alts_raw = q.get("alternativas", [])
            correct_letter = q.get("resposta_correta", "A")
            correct_text = next(
                (str(a.get("texto")).strip() for a in alts_raw if a.get("letra") == correct_letter),
                "",
            )
            if not correct_text and alts_raw:
                correct_text = str(alts_raw[0].get("texto")).strip()

            distratores_unicos: list[str] = []
            for a in alts_raw:
                t = str(a.get("texto", "")).strip()
                if (
                    t
                    and t.lower() != correct_text.lower()
                    and not t.startswith("[")
                    and t not in distratores_unicos
                ):
                    distratores_unicos.append(t)

            fb_candidatos = [f for f in fallbacks_pool if f.lower() != correct_text.lower() and f not in distratores_unicos]
            random.shuffle(fb_candidatos)
            for fb in fb_candidatos:
                if len(distratores_unicos) >= 3:
                    break
                distratores_unicos.append(fb)

            pos_correta = random.randint(0, 3)
            final_textos = list(distratores_unicos[:3])
            final_textos.insert(pos_correta, correct_text)

            q["alternativas"] = [
                {"letra": letras_padrao[i], "texto": final_textos[i]}
                for i in range(4)
            ]
            q["resposta_correta"] = letras_padrao[pos_correta]
            q["fonte_confianca"] = q.get("fonte_confianca", "alta")

        return shuffled
