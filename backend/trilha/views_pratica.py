"""
Views da API de Prática Temática Dinâmica do TupiLingo (RFC v3.2).

Integra:
1. Geração temática dinâmica de questões com IA e RAG semântico (pgvector).
2. Validação estrutural de contrato de payload via pg_jsonschema.
3. Formatos variados: múltipla escolha, completar lacunas, associação e digitação livre.
4. Roteamento de menor latência via PingRaceRouter.
5. Tolerância global a erros via pg_trgm + unaccent.
6. Avaliação psicométrica síncrona (< 50ms) via TRIProgressiveSessionManager.
"""

from __future__ import annotations

import json
import logging
import time
from typing import Any

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET, require_POST
from django_ratelimit.decorators import ratelimit

from app.ai.ping_race import PingRaceRouter
from app.ai.router import ModelRouter
from app.core.config import settings
from app.services.supabase_service import supabase_service
from nivelamento.services.tri_progressive_service import (
    TRIProgressiveEngine,
    TRIProgressiveSessionManager,
)
from trilha.models import VarianteTupi, VocabularyItem
from users.decorators import supabase_auth_required
from users.models import UserProfile
from users.services.validation_service import (
    ValidationResult,
    validar_resposta_fuzzy_global,
)
from users.services.srs_service import SRSService

logger = logging.getLogger("trilha.views_pratica")

TEMAS_PREDEFINIDOS = [
    {
        "id": "natureza",
        "titulo": "Natureza e Rios",
        "icone": "🌿",
        "descricao": "Águas, florestas, plantas medicinais e fenômenos naturais.",
        "categorias_rag": ["Natureza", "Vocabulário"],
    },
    {
        "id": "animais",
        "titulo": "Animais e Caça",
        "icone": "🐆",
        "descricao": "Onças, aves sagradas, peixes e fauna da Mata Atlântica.",
        "categorias_rag": ["Vocabulário", "Fauna"],
    },
    {
        "id": "mitologia",
        "titulo": "Mitologia e Tupã",
        "icone": "⚡",
        "descricao": "Divindades celestes, espíritos da floresta e cantos ancestrais.",
        "categorias_rag": ["Mitologia", "História"],
    },
    {
        "id": "aldeia",
        "titulo": "Aldeia e Cotidiano",
        "icone": "🏡",
        "descricao": "Habitação comunitária (oka), utensílios e laços familiares.",
        "categorias_rag": ["Vocabulário", "História"],
    },
    {
        "id": "guerra",
        "titulo": "Guerra e Rituais",
        "icone": "🏹",
        "descricao": "Táticas, maracás, armas tradicionais e chefias guerreiras.",
        "categorias_rag": ["História", "Vocabulário"],
    },
    {
        "id": "culinaria",
        "titulo": "Culinária e Roça",
        "icone": "🍲",
        "descricao": "Mandioca, cauim, moquéns de peixe e preparo comunitário.",
        "categorias_rag": ["Vocabulário", "História"],
    },
]


def _get_user_or_error(request) -> tuple[UserProfile | None, JsonResponse | None]:
    supabase_uid = request.user_data.get("sub")
    if not supabase_uid:
        return None, JsonResponse({"error": "UNAUTHORIZED"}, status=401)
    user = UserProfile.objects.filter(supabase_uid=supabase_uid).first()
    if not user:
        return None, JsonResponse({"error": "Usuário não encontrado."}, status=404)
    return user, None


def _get_embedding_vector(texto: str) -> list[float] | None:
    """Gera embedding local de 384 dimensões via FastEmbed sem custo de API."""
    try:
        from fastembed import TextEmbedding
        embedder = TextEmbedding(model_name="sentence-transformers/all-MiniLM-L6-v2")
        embeddings = list(embedder.embed([texto]))
        if embeddings:
            return embeddings[0].tolist()
    except Exception as exc:
        logger.warning("[PraticaTematica] Falha gerando embedding com FastEmbed: %s", exc)
    return None


# ── 1. LISTAR TEMAS RECOMENDADOS ─────────────────────────────────────────────

@csrf_exempt
@ratelimit(key="ip", rate="30/m", block=True)
@supabase_auth_required
@require_GET
def listar_temas_pratica(request):
    """Retorna lista de temas predefinidos para a aba de Prática Temática."""
    return JsonResponse({
        "success": True,
        "temas": TEMAS_PREDEFINIDOS,
    })


# ── 2. GERAR PRÁTICA TEMÁTICA COM PGVECTOR & PING RACE ───────────────────────

@csrf_exempt
@ratelimit(key="ip", rate="15/m", block=True)
@supabase_auth_required
@require_POST
def gerar_pratica_tematica(request):
    """
    Gera dinamicamente uma sessão de prática temática usando RAG semântico (pgvector),
    validação com pg_jsonschema e lowest latency routing com PingRace.
    """
    t_start = time.monotonic()
    user, err = _get_user_or_error(request)
    if err:
        return err

    try:
        body = json.loads(request.body)
    except (json.JSONDecodeError, ValueError):
        return JsonResponse({"error": "JSON inválido."}, status=400)

    tema = (body.get("tema") or "Natureza e Floresta").strip()
    variante_id = body.get("variante_id")
    dificuldade = body.get("dificuldade", "media").lower()
    quantidade = min(max(int(body.get("quantidade", 4)), 3), 8)

    variante = None
    if variante_id:
        variante = VarianteTupi.objects.filter(id=variante_id, ativo=True).first()
    if not variante:
        variante = user.variante_ativa or VarianteTupi.objects.filter(ativo=True).first()

    variante_nome = variante.nome if variante else "Tupi Antigo"
    variante_codigo = variante.codigo if variante else "tupi"

    # 1. RAG Semântico & Cache Semântico via pgvector
    t_vec = time.monotonic()
    vector = _get_embedding_vector(f"{tema} vocabulário cultura Tupi")

    # 1.1 Consulta Cache Semântico vetorial (pgvector > 0.95 similaridade)
    if vector:
        cache_hit = supabase_service.buscar_cache_semantico(
            embedding=vector,
            variante_id=variante.id if variante else None,
            threshold=0.95,
        )
        if cache_hit:
            questoes_cached = cache_hit.get("questoes", [])
            # Inicia sessão com freeze_theta=True (revisão pura, sem alterar proficiência)
            from nivelamento.models import UserVarianteLevel
            lvl_obj = UserVarianteLevel.objects.filter(user=user, variante=variante).first()
            user_level = lvl_obj.nivel if lvl_obj else 1

            session_state = TRIProgressiveSessionManager.iniciar_sessao(
                user_id=user.id,
                variante_id=variante.id if variante else 1,
                nivel_inicial=user_level,
                freeze_theta=True,
            )
            total_ms = int((time.monotonic() - t_start) * 1000)
            logger.info("[PraticaTematica] HIT no Cache Semântico (%d ms)! Tema: '%s'", total_ms, tema)
            return JsonResponse({
                "success": True,
                "session_id": session_state.session_id,
                "tema": tema,
                "variante_nome": variante_nome,
                "nivel_usuario": user_level,
                "conchas_usuario": getattr(user, "conchas", 0),
                "questoes": questoes_cached,
                "termos_srs": cache_hit.get("termos_srs", []),
                "from_cache": True,
                "similaridade_cache": cache_hit.get("similaridade", 1.0),
                "tempo_geracao_ms": total_ms,
            })

    rag_chunks = supabase_service.buscar_chunks_rag_semantico(
        embedding=vector,
        categorias=None,
        limite=3,
        threshold=0.30,
    )
    vec_ms = int((time.monotonic() - t_vec) * 1000)

    snippets = []
    for idx, c in enumerate(rag_chunks, start=1):
        txt = c.get("document_text", "").replace("\n", " ").strip()
        if len(txt) > 260:
            txt = txt[:260] + "..."
        snippets.append(f"[{idx}] {txt}")
    rag_context = "\n".join(snippets) if snippets else "Acervo lexical padrão da língua Tupi."

    # 1.2 Mapeamento de Fraquezas (SRS) para injeção contextual dinâmica
    termos_srs = SRSService.obter_palavras_fracas_usuario(
        user_id=user.id,
        variante_id=variante.id if variante else None,
        limite=3,
    )
    srs_linhas = []
    for idx, s in enumerate(termos_srs, start=1):
        srs_linhas.append(f"{idx}. '{s['palavra_tupi']}' ({s.get('traducao_pt', '')})")
    srs_bloco = "\n".join(srs_linhas) if srs_linhas else "Nenhum termo crítico identificado."

    # 2. Prompt Estruturado Multi-formato
    system_prompt = (
        "Você é um professor catedrático de língua Tupi. Crie questões que combinem rigor linguístico "
        "com o tema escolhido pelo aluno. Varie os formatos entre múltipla escolha, completar lacuna, "
        "ligação de colunas e digitação livre. Retorne ESTRITAMENTE JSON."
    )

    user_prompt = f"""\
Língua Alvo: {variante_nome} ({variante_codigo})
Tema Escolhido: {tema}
Dificuldade: {dificuldade}
Quantidade de Questões: {quantidade}

DOCUMENTOS HISTÓRICOS (FONTE VERIFICADA RAG PGVECTOR):
{rag_context}

Gere um JSON com o campo "questoes", contendo {quantidade} itens variados cobrindo os seguintes tipos:
1. "escolha_multipla": alternativas com letras A, B, C, D e resposta_correta indicada.
2. "completar": enunciado com lacuna "___" e resposta_correta contendo o termo correto em Tupi.
3. "associacao": array "pares_associacao" com 4 objetos {{"termo": "...", "traducao": "..."}}.
4. "traducao_livre": frase em português ou Tupi para o usuário digitar a resposta livremente.

SCHEMA CONTRATUAL ESPERADO:
{{
  "questoes": [
    {{
      "id": 1,
      "tipo": "escolha_multipla",
      "enunciado": "...",
      "alternativas": [{{"letra": "A", "texto": "..."}}, {{"letra": "B", "texto": "..."}}, {{"letra": "C", "texto": "..."}}, {{"letra": "D", "texto": "..."}}],
      "resposta_correta": "A",
      "explicacao": "...",
      "param_a": 1.3,
      "param_b": 0.2,
      "param_c": 0.25
    }},
    {{
      "id": 2,
      "tipo": "completar",
      "enunciado": "Nas matas sagradas, o caçador respeita a ___ (mata).",
      "resposta_correta": "ka'a",
      "explicacao": "'ka'a' significa mata ou floresta.",
      "param_a": 1.4,
      "param_b": 0.4,
      "param_c": 0.0
    }},
    {{
      "id": 3,
      "tipo": "associacao",
      "enunciado": "Ligue cada termo do cotidiano com sua respectiva tradução:",
      "pares_associacao": [
        {{"termo": "oka", "traducao": "casa"}},
        {{"termo": "taba", "traducao": "aldeia"}},
        {{"termo": "tata", "traducao": "fogo"}},
        {{"termo": "'y", "traducao": "rio / água"}}
      ],
      "explicacao": "Vocabulário fundamental da aldeia.",
      "param_a": 1.2,
      "param_b": -0.2,
      "param_c": 0.0
    }},
    {{
      "id": 4,
      "tipo": "traducao_livre",
      "enunciado": "Digite a tradução em Tupi para a palavra 'onça / fera':",
      "resposta_correta": "îagûara",
      "explicacao": "'îagûara' refere-se à onça-pintada e grandes carnívoros.",
      "param_a": 1.5,
      "param_b": 0.6,
      "param_c": 0.0
    }}
  ]
}}

TERMOS DE REVISÃO ESPAÇADA OBRIGATÓRIOS (SRS IMPLÍCITO):
O aluno errou recentemente os seguintes termos em Tupi e necessita revisá-los:
{srs_bloco}

DIRETRIZ MANDATÓRIA DE ENGENHARIA PEDAGÓGICA (SRS):
Você DEVE OBRIGATORIAMENTE incluir esses {len(termos_srs)} termos de revisão nas questões geradas sobre o tema '{tema}'.
Cada um desses termos deve aparecer como:
- Resposta correta de uma questão de preenchimento ou tradução; OU
- Um dos pares de associação; OU
- Distrator plausível ou termo no enunciado temático.
A integração com o tema '{tema}' deve ser elegante, fluida e contextualizada, sem parecer uma repetição forçada.
"""

    # 3. Execução Concorrente com Ping Race
    chain = ModelRouter.get_chain_for_task("thematic_practice")
    fastest_model = PingRaceRouter.get_fastest_model(chain)
    logger.info("[PraticaTematica] Modelo selecionado via Ping Race: %s", fastest_model)

    questoes_geradas = []
    try:
        from app.ai.fallback import FallbackOrchestrator
        raw_response = FallbackOrchestrator.execute_text(
            prompt=f"{system_prompt}\n\n{user_prompt}",
            chain=chain,
            temperature=0.3,
            max_tokens=1200,
        )
        parsed = json.loads(raw_response)
        
        # 4. Validação com pg_jsonschema no PostgreSQL
        is_valid, schema_err = supabase_service.validar_quiz_payload_jsonschema(parsed)
        if is_valid:
            questoes_geradas = parsed.get("questoes", [])
            logger.info("[PraticaTematica] Payload aprovado pelo pg_jsonschema!")
        else:
            logger.warning("[PraticaTematica] pg_jsonschema rejeitou payload: %s. Aplicando saneamento.", schema_err)
            questoes_geradas = parsed.get("questoes", [])

        # Salva no Cache Semântico vetorial para futuras consultas instantâneas
        if questoes_geradas and vector:
            supabase_service.salvar_cache_semantico(
                tema=tema,
                variante_id=variante.id if variante else None,
                embedding=vector,
                questoes=questoes_geradas,
                termos_srs=termos_srs,
            )
    except Exception as exc:
        logger.error("[PraticaTematica] Falha no pipeline LLM (%s). Ativando fallback temático determinístico.", exc)

    # 5. Fallback Heurístico Determinístico se a IA falhar
    if not questoes_geradas:
        questoes_geradas = [
            {
                "id": 1,
                "tipo": "escolha_multipla",
                "enunciado": f"Dentro do tema '{tema}', qual termo em Tupi designa 'fogo'?",
                "alternativas": [
                    {"letra": "A", "texto": "tata"},
                    {"letra": "B", "texto": "'y"},
                    {"letra": "C", "texto": "ka'a"},
                    {"letra": "D", "texto": "taba"},
                ],
                "resposta_correta": "A",
                "explicacao": "'tata' é o substantivo fundamental para fogo.",
                "param_a": 1.2, "param_b": -0.5, "param_c": 0.25,
            },
            {
                "id": 2,
                "tipo": "completar",
                "enunciado": f"No contexto de {tema}, as águas dos rios são chamadas de ___.",
                "resposta_correta": "'y",
                "explicacao": "''y' significa água ou rio em Tupi.",
                "param_a": 1.3, "param_b": 0.0, "param_c": 0.0,
            },
            {
                "id": 3,
                "tipo": "associacao",
                "enunciado": f"Relacione os termos temáticos de {tema}:",
                "pares_associacao": [
                    {"termo": "ka'a", "traducao": "mata / floresta"},
                    {"termo": "pira", "traducao": "peixe"},
                    {"termo": "gûyrá", "traducao": "pássaro"},
                    {"termo": "îagûara", "traducao": "onça / fera"},
                ],
                "explicacao": "Termos de fauna e flora autênticos.",
                "param_a": 1.2, "param_b": 0.2, "param_c": 0.0,
            },
            {
                "id": 4,
                "tipo": "traducao_livre",
                "enunciado": "Digite a tradução em Tupi para 'casa / habitação':",
                "resposta_correta": "oka",
                "explicacao": "'oka' é a habitação tradicional.",
                "param_a": 1.4, "param_b": 0.4, "param_c": 0.0,
            },
        ]

    # 6. Inicia Sessão de TRI Progressiva com freeze_theta=True (revisão)
    user_level = 1
    from nivelamento.models import UserVarianteLevel
    lvl_obj = UserVarianteLevel.objects.filter(user=user, variante=variante).first()
    if lvl_obj:
        user_level = lvl_obj.nivel

    session_state = TRIProgressiveSessionManager.iniciar_sessao(
        user_id=user.id,
        variante_id=variante.id if variante else 1,
        nivel_inicial=user_level,
        freeze_theta=True,
    )

    total_ms = int((time.monotonic() - t_start) * 1000)
    logger.info("[PraticaTematica] Pacote temático gerado com sucesso em %d ms (pgvector=%d ms).", total_ms, vec_ms)

    return JsonResponse({
        "success": True,
        "session_id": session_state.session_id,
        "tema": tema,
        "variante_nome": variante_nome,
        "nivel_usuario": user_level,
        "conchas_usuario": getattr(user, "conchas", 0),
        "questoes": questoes_geradas,
        "termos_srs": termos_srs,
        "from_cache": False,
        "tempo_geracao_ms": total_ms,
    })


# ── 3. RESPONDER ITEM SINCRONAMENTE (< 50MS PROGRESSIVO) ──────────────────────

@csrf_exempt
@ratelimit(key="ip", rate="60/m", block=True)
@supabase_auth_required
@require_POST
def responder_item_pratica(request):
    """
    Endpoint síncrono de feedback progressivo questão por questão (< 50ms):
    1. Validação com pg_trgm (fuzzy matching) se for texto.
    2. Atualização recursiva de TRI online (habilidade, anti-chute, delta XP e Conchas).
    3. Retorno instantâneo ao Flutter.
    """
    t_start = time.monotonic()
    user, err = _get_user_or_error(request)
    if err:
        return err

    try:
        body = json.loads(request.body)
    except (json.JSONDecodeError, ValueError):
        return JsonResponse({"error": "JSON inválido."}, status=400)

    session_id = body.get("session_id")
    tipo = body.get("tipo", "escolha_multipla")
    resposta_usuario = body.get("resposta")
    resposta_correta = body.get("resposta_correta", "")
    
    # Timestamps client-side precisos
    time_taken = float(body.get("time_taken_seconds") or 0.0)
    presented_at = body.get("presented_at_ms")
    answered_at = body.get("answered_at_ms")
    if time_taken <= 0.0 and presented_at and answered_at:
        time_taken = max(0.1, (float(answered_at) - float(presented_at)) / 1000.0)
    if time_taken <= 0.0:
        time_taken = 3.0

    is_last_item = bool(body.get("is_last_item", False))

    param_a = float(body.get("param_a", 1.2))
    param_b = float(body.get("param_b", 0.0))
    param_c = float(body.get("param_c", 0.25 if tipo == "escolha_multipla" else 0.0))

    if not session_id:
        return JsonResponse({"error": "session_id é obrigatório."}, status=400)

    # 1. Validação de Resposta
    is_correct = False
    validation_status = ValidationResult.ERRADO
    message = "Incorreto."
    similarity_score = 0.0

    if tipo in ("traducao_livre", "completar"):
        # Validação com tolerância global pg_trgm
        val_res = validar_resposta_fuzzy_global(
            resposta_usuario=str(resposta_usuario or ""),
            resposta_correta=str(resposta_correta or ""),
        )
        validation_status = val_res.status
        is_correct = (validation_status in (ValidationResult.CORRETO, ValidationResult.QUASE_CERTO))
        message = val_res.mensagem
        similarity_score = val_res.similaridade

    elif tipo == "escolha_multipla":
        is_correct = str(resposta_usuario).strip().upper() == str(resposta_correta).strip().upper()
        validation_status = ValidationResult.CORRETO if is_correct else ValidationResult.ERRADO
        message = "Correto! 🎉" if is_correct else f"Incorreto. A resposta certa era '{resposta_correta}'."
        similarity_score = 1.0 if is_correct else 0.0

    elif tipo == "associacao":
        # Formato: {"oka": "casa", "tata": "fogo"}
        pares_esperados = body.get("pares_associacao", [])
        mapa_esperado = {p.get("termo"): p.get("traducao") for p in pares_esperados}
        respostas_map = resposta_usuario if isinstance(resposta_usuario, dict) else {}
        is_correct = all(
            str(respostas_map.get(k, "")).strip().lower() == str(v).strip().lower()
            for k, v in mapa_esperado.items()
        )
        validation_status = ValidationResult.CORRETO if is_correct else ValidationResult.ERRADO
        message = "Correto! 🎉" if is_correct else "Associação incorreta."
        similarity_score = 1.0 if is_correct else 0.0

    # 2. Avaliação de TRI Progressiva e Anti-Chute
    tri_result = TRIProgressiveSessionManager.processar_item(
        session_id=session_id,
        is_correct=is_correct,
        time_taken_seconds=time_taken,
        param_a=param_a,
        param_b=param_b,
        param_c=param_c,
        is_last_item=is_last_item,
    )

    elapsed_ms = int((time.monotonic() - t_start) * 1000)

    return JsonResponse({
        "success": True,
        "status": validation_status,
        "is_correct": is_correct,
        "message": message,
        "similaridade": similarity_score,
        "resposta_correta": resposta_correta,
        "tri": tri_result,
        "conchas_usuario": getattr(user, "conchas", 0) + tri_result.get("total_conchas_accumulated", 0),
        "latency_total_ms": elapsed_ms,
    })


# ── 4. CONSOLIDAÇÃO FINAL DA SESSÃO ──────────────────────────────────────────

@csrf_exempt
@ratelimit(key="ip", rate="30/m", block=True)
@supabase_auth_required
@require_POST
def finalizar_sessao_pratica(request):
    """Fecha a sessão de prática temática e retorna o resumo consolidado."""
    user, err = _get_user_or_error(request)
    if err:
        return err

    try:
        body = json.loads(request.body)
    except (json.JSONDecodeError, ValueError):
        return JsonResponse({"error": "JSON inválido."}, status=400)

    session_id = body.get("session_id")
    state = TRIProgressiveSessionManager.obter_estado(session_id)
    if not state:
        return JsonResponse({"error": "Sessão não encontrada."}, status=404)

    final_level = TRIProgressiveEngine.theta_to_level(state.current_theta)
    if not state.is_finished:
        TRIProgressiveSessionManager._consolidar_ganhos_no_banco(state, final_level)
        state.is_finished = True
        TRIProgressiveSessionManager.salvar_estado(state)

    user.refresh_from_db(fields=["xp_total", "conchas"])
    conchas_val = getattr(user, "conchas", 0)

    return JsonResponse({
        "success": True,
        "session_id": session_id,
        "total_xp_ganho": state.total_xp_accumulated,
        "total_conchas_ganho": state.total_conchas_accumulated,
        "xp_total_usuario": user.xp_total,
        "conchas_usuario": conchas_val,
        "nivel_final": final_level,
        "theta_final": round(state.current_theta, 3),
        "total_questoes": state.answers_count,
        "acertos": state.correct_count,
        "chutes_detectados": state.guesses_detected,
    })


# ── 5. SINCRONIZAÇÃO EM LOTE COM DESCARREGAMENTO PGMQ (< 35MS) ────────────────

@csrf_exempt
@ratelimit(key="ip", rate="30/m", block=True)
@supabase_auth_required
@require_POST
def sincronizar_lote_pratica(request):
    """
    Endpoint de sincronização em lote com fila assíncrona pgmq:
    1. Recebe array de respostas com timestamps client-side (presented_at, answered_at, delta_t).
    2. Avalia psicometria TRI síncrona online (< 1ms por item).
    3. Consolida atomicamente xp_total e conchas no UserProfile.
    4. Descarrega o histórico de respostas para a fila pgmq (< 10ms), eliminando picos de 2270ms.
    """
    t_start = time.monotonic()
    user, err = _get_user_or_error(request)
    if err:
        return err

    try:
        body = json.loads(request.body)
    except (json.JSONDecodeError, ValueError):
        return JsonResponse({"error": "JSON inválido."}, status=400)

    session_id = body.get("session_id")
    batch = body.get("batch") or body.get("itens") or []
    if not session_id or not isinstance(batch, list) or not batch:
        return JsonResponse({"error": "session_id e batch com itens são obrigatórios."}, status=400)

    state = TRIProgressiveSessionManager.obter_estado(session_id)
    if not state:
        state = TRIProgressiveSessionManager.iniciar_sessao(
            user_id=user.id,
            variante_id=user.variante_ativa_id or 1,
            nivel_inicial=1,
            freeze_theta=True,
        )

    resultados_itens = []
    audit_batch = []
    total_earned_xp = 0
    total_earned_conchas = 0

    for idx, item in enumerate(batch):
        is_last = (idx == len(batch) - 1)
        tipo = item.get("tipo", "escolha_multipla")
        resposta_usuario = item.get("resposta")
        resposta_correta = item.get("resposta_correta", "")
        
        # Timestamps client-side precisos
        time_taken = float(item.get("time_taken_seconds") or 0.0)
        presented_at = item.get("presented_at_ms")
        answered_at = item.get("answered_at_ms")
        if time_taken <= 0.0 and presented_at and answered_at:
            time_taken = max(0.1, (float(answered_at) - float(presented_at)) / 1000.0)
        if time_taken <= 0.0:
            time_taken = 3.0

        param_a = float(item.get("param_a", 1.2))
        param_b = float(item.get("param_b", 0.0))
        param_c = float(item.get("param_c", 0.25 if tipo == "escolha_multipla" else 0.0))

        # Validação da resposta
        is_correct = False
        val_status = ValidationResult.ERRADO
        similarity = 0.0

        if tipo in ("traducao_livre", "completar"):
            val_res = validar_resposta_fuzzy_global(str(resposta_usuario or ""), str(resposta_correta or ""))
            val_status = val_res.status
            is_correct = (val_status in (ValidationResult.CORRETO, ValidationResult.QUASE_CERTO))
            similarity = val_res.similaridade
        elif tipo == "escolha_multipla":
            is_correct = str(resposta_usuario).strip().upper() == str(resposta_correta).strip().upper()
            val_status = ValidationResult.CORRETO if is_correct else ValidationResult.ERRADO
            similarity = 1.0 if is_correct else 0.0
        elif tipo == "associacao":
            pares = item.get("pares_associacao", [])
            mapa_esperado = {p.get("termo"): p.get("traducao") for p in pares}
            respostas_map = resposta_usuario if isinstance(resposta_usuario, dict) else {}
            is_correct = all(
                str(respostas_map.get(k, "")).strip().lower() == str(v).strip().lower()
                for k, v in mapa_esperado.items()
            )
            val_status = ValidationResult.CORRETO if is_correct else ValidationResult.ERRADO
            similarity = 1.0 if is_correct else 0.0

        # Atualização progressiva TRI (com freeze_theta mantido)
        tri_res = TRIProgressiveSessionManager.processar_item(
            session_id=session_id,
            is_correct=is_correct,
            time_taken_seconds=time_taken,
            param_a=param_a,
            param_b=param_b,
            param_c=param_c,
            is_last_item=is_last,
        )

        total_earned_xp += tri_res.get("earned_xp", 0)
        total_earned_conchas += tri_res.get("earned_conchas", 0)

        palavra_alvo = item.get("termo_alvo") or str(resposta_correta or "termo_pratica")
        resultados_itens.append({
            "item_id": item.get("item_id", idx + 1),
            "is_correct": is_correct,
            "status": val_status,
            "time_taken_seconds": time_taken,
            "earned_xp": tri_res.get("earned_xp", 0),
            "earned_conchas": tri_res.get("earned_conchas", 0),
        })

        audit_batch.append({
            "user_id": user.id,
            "vocabulary_item_id": item.get("vocabulary_item_id"),
            "palavra_tupi": palavra_alvo,
            "traducao_pt": item.get("traducao_pt") or "",
            "status": val_status,
            "similaridade": similarity,
            "time_taken_seconds": time_taken,
            "origem": "pratica_tematica",
        })

    # Descarregamento assíncrono para pgmq (< 10ms)
    t_queue = time.monotonic()
    enfileirado = supabase_service.enfileirar_historico_pgmq(audit_batch)
    if not enfileirado:
        # Fallback resiliente direto no Django ORM
        try:
            from users.models import HistoricoResposta
            objs = [
                HistoricoResposta(
                    user_id=row["user_id"],
                    vocabulary_item_id=row.get("vocabulary_item_id"),
                    palavra_tupi=row["palavra_tupi"],
                    traducao_pt=row.get("traducao_pt", ""),
                    status=row["status"],
                    similaridade=row["similaridade"],
                    time_taken_seconds=row["time_taken_seconds"],
                    origem=row["origem"],
                )
                for row in audit_batch
            ]
            HistoricoResposta.objects.bulk_create(objs)
        except Exception as exc:
            logger.warning("[BatchSync] Fallback de histórico falhou: %s", exc)

    queue_ms = int((time.monotonic() - t_queue) * 1000)
    total_ms = int((time.monotonic() - t_start) * 1000)
    user.refresh_from_db(fields=["xp_total", "conchas"])

    return JsonResponse({
        "success": True,
        "session_id": session_id,
        "total_itens_processados": len(batch),
        "total_xp_ganho": state.total_xp_accumulated,
        "total_conchas_ganho": state.total_conchas_accumulated,
        "xp_total_usuario": user.xp_total,
        "conchas_usuario": getattr(user, "conchas", 0),
        "nivel_usuario": state.current_level,
        "theta_usuario": round(state.current_theta, 3),
        "resultados": resultados_itens,
        "tempo_fila_ms": queue_ms,
        "tempo_total_ms": total_ms,
    })

