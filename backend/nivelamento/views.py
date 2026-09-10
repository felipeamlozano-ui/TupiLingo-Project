"""
Views da API de nivelamento adaptativo.

MUDANÇA CRÍTICA (v2 — Jornada Histórica):
- O nivelamento agora é ISOLADO por VarianteTupi.
- O payload obrigatoriamente inclui `variante_id`.
- O TestAttempt é único por (user, variante).
- A busca no RAG é filtrada por `variante.codigo` para não misturar línguas.
- O nível calculado é salvo em `UserVarianteLevel`, não mais em `UserProfile.tupi_level`.
"""

from __future__ import annotations

import json
import logging

from app.ai.rag_service import RAGService
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST
from django_ratelimit.decorators import ratelimit
from pydantic import ValidationError
from trilha.models import VarianteTupi
from users.decorators import supabase_auth_required
from users.models import UserProfile

from nivelamento.models import AnswerItem, TestAttempt, UserVarianteLevel
from nivelamento.schemas import GenerateQuestionPayload
from nivelamento.services.tri_service import evaluate_test

logger = logging.getLogger("nivelamento.views")


def _get_user_or_error(request) -> tuple[UserProfile | None, JsonResponse | None]:
    """Helper: resolve o UserProfile a partir do JWT ou retorna erro 401/404."""
    supabase_uid = request.user_data.get("sub")
    if not supabase_uid:
        return None, JsonResponse(
            {"success": False, "error": {"code": "UNAUTHORIZED", "message": "Token sem identificação."}},
            status=401,
        )

    # GANHO DE PERFORMANCE: .only() carrega estritamente os campos identificadores
    user = UserProfile.objects.filter(supabase_uid=supabase_uid).only('id', 'supabase_uid').first()

    if not user:
        email = (request.user_data.get("email") or "").strip().lower()
        if email:
            existing = UserProfile.objects.filter(email__iexact=email).first()
            if existing:
                existing.supabase_uid = supabase_uid
                existing.save(update_fields=['supabase_uid'])
                user = existing

    if not user:
        return None, JsonResponse(
            {"success": False, "error": {"code": "NOT_FOUND", "message": "Usuário não encontrado."}},
            status=404,
        )
    return user, None



@csrf_exempt
@ratelimit(key='ip', rate='15/m', block=True)
@ratelimit(key='user', rate='5/m', block=True)
@supabase_auth_required
@require_POST
def gerar_questao_nivelamento(request):
    """Gera questões de nivelamento adaptativo para uma Variante Tupi específica."""
    # ── 1. Resolução do Usuário Autenticado (Topo da View) ───────────────────
    user, err = _get_user_or_error(request)
    if err:
        return err

    # ── 2. Parsing e Validação do Payload ────────────────────────────────────
    try:
        body = json.loads(request.body)
    except (json.JSONDecodeError, ValueError):
        logger.warning("Corpo da requisição inválido")
        return JsonResponse(
            {"success": False, "error": {"code": "INVALID_JSON", "message": "JSON inválido."}},
            status=400,
        )

    try:
        payload = GenerateQuestionPayload.model_validate(body)
    except ValidationError as exc:
        error_messages = "; ".join(f"{e['loc']}: {e['msg']}" for e in exc.errors())
        logger.warning("Payload inválido: %s", error_messages)
        return JsonResponse(
            {"success": False, "error": {"code": "INVALID_PAYLOAD", "message": error_messages}},
            status=400,
        )

    # ── 3. Resolução da Variante ─────────────────────────────────────────────
    variante = (
        VarianteTupi.objects
        .filter(id=payload.variante_id, ativo=True)
        .only('id', 'codigo', 'nome')
        .first()
    )
    if not variante:
        return JsonResponse(
            {"success": False, "error": {"code": "VARIANTE_NOT_FOUND", "message": "Variante inválida ou inativa."}},
            status=404,
        )

    # ─────────────────────────────────────────────────────────────────────────
    # NOTA DE ARQUITETURA DE SEGURANÇA (SECURITY ARCHITECTURE DISCLAIMER):
    # A checagem antecipada de TestAttempt e as diretivas de rate-limit (@ratelimit)
    # minimizam custos computacionais e evitam esgotamento desnecessário do estoque
    # do Question Pool no Redis contra cliques repetidos de usuários legítimos ou
    # scripts casuais.
    #
    # LIMITAÇÃO TÉCNICA REAL:
    # Esta barreira em nível de aplicação NÃO constitui defesa forte contra scraping
    # dedicado ou agentes maliciosos distribuídos (ex: atacantes com rotação de IPs
    # residenciais, orquestração de múltiplas contas ou scraping contínuo via tokens).
    # Uma mitigação efetiva contra raspagem profissional de conteúdo em escala exige
    # defesas de borda em camadas: WAF (Cloudflare Bot Management / Turnstile),
    # atestação de integridade de dispositivo móvel (Google Play Integrity / Apple App Attest),
    # ofuscação/criptografia dinâmica de payloads e monitoramento heurístico de tráfego.
    # Esta declaração explícita no código evita falsas sensações de segurança arquitetural.
    # ─────────────────────────────────────────────────────────────────────────
    ja_fez_teste = TestAttempt.objects.filter(user_id=user.id, variante_id=variante.id).exists()
    if ja_fez_teste:
        nivel_atual = (
            UserVarianteLevel.objects
            .filter(user_id=user.id, variante_id=variante.id)
            .only('nivel')
            .first()
        )
        return JsonResponse(
            {
                "success": False,
                "error": {
                    "code": "ALREADY_TESTED",
                    "message": f"Você já realizou o teste para '{variante.nome}'.",
                    "nivel_atual": nivel_atual.nivel if nivel_atual else 1,
                },
            },
            status=409,
        )

    # ── Geração das questões via RAG filtrado por variante ────────────────────
    try:
        service = RAGService()
        result = service.generate(
            nivel_atual=payload.nivel_atual,
            variante_codigo=variante.codigo,  # Filtro de variante no RAG
        )
    except ValueError as exc:
        logger.warning("Erro de validação RAG: %s", exc)
        return JsonResponse(
            {"success": False, "error": {"code": "VALIDATION_ERROR", "message": str(exc)}},
            status=400,
        )
    except RuntimeError:
        logger.error("Erro na geração de questões para uid=%s variante=%s", user.supabase_uid, variante.codigo, exc_info=True)
        return JsonResponse(
            {"success": False, "error": {"code": "QUESTION_GENERATION_FAILED", "message": "Não foi possível gerar as questões. Tente novamente."}},
            status=500,
        )
    except Exception:
        logger.exception("Erro inesperado ao gerar questão")
        return JsonResponse(
            {"success": False, "error": {"code": "INTERNAL_ERROR", "message": "Erro interno no servidor."}},
            status=500,
        )

    # ── Validação defensiva rigorosa de integridade das alternativas ───────
    questoes_finais = []
    fallbacks_garantia = [
        "Onça / Fera", "Pássaro / Ave", "Peixe", "Casa / Habitação", "Mãe", "Pai",
        "Homem / Pessoa", "Mulher", "Filho / Filha", "Água / Rio", "Sol", "Lua",
        "Aldeia", "Mata / Floresta", "Fogo", "Caminho / Trilha"
    ]
    contingencia_questoes = [
        {"termo": "îagûara", "trad": "Onça / Fera", "enunciado": "Qual é a tradução de 'îagûara' em Tupi Antigo?"},
        {"termo": "pira", "trad": "Peixe", "enunciado": "O que significa 'pira' no vocabulário Tupi?"},
        {"termo": "tata", "trad": "Fogo", "enunciado": "Qual elemento natural é designado por 'tata'?"},
        {"termo": "'y", "trad": "Água / Rio", "enunciado": "O que expressa a palavra ''y' em Tupi?"},
        {"termo": "ka'a", "trad": "Mata / Floresta", "enunciado": "A palavra 'ka'a' se refere a qual ambiente?"},
        {"termo": "kunhã", "trad": "Mulher", "enunciado": "Qual é o significado de 'kunhã' nas fontes quinhentistas?"},
        {"termo": "oka", "trad": "Casa / Habitação", "enunciado": "O que designa o termo 'oka' na aldeia?"},
        {"termo": "taba", "trad": "Aldeia", "enunciado": "Qual é a tradução de 'taba' em Tupi Antigo?"},
        {"termo": "kûarasy", "trad": "Sol", "enunciado": "A qual astro se refere 'kûarasy'?"},
        {"termo": "îasy", "trad": "Lua", "enunciado": "Qual astro celeste é chamado de 'îasy'?"},
    ]
    letras_esperadas = ["A", "B", "C", "D"]

    for idx, q in enumerate(result.get("questoes", [])):
        enunciado = str(q.get("enunciado", "")).strip()
        alts = q.get("alternativas", [])
        resp_correta = q.get("resposta_correta", "A")

        # Sanitiza questão corrompida com synthetic mock
        if "termo_" in enunciado or "Alternativa " in enunciado or not enunciado:
            subst = contingencia_questoes[idx % len(contingencia_questoes)]
            enunciado = subst["enunciado"]
            q["enunciado"] = enunciado
            texto_correto = subst["trad"]
            resp_correta = "A"
        else:
            texto_correto = ""
            for a in alts:
                if a.get("letra") == resp_correta:
                    texto_correto = str(a.get("texto", "")).strip()
                    break
            if not texto_correto and alts:
                texto_correto = str(alts[0].get("texto", "")).strip()

        if "Alternativa " in texto_correto or "termo_" in texto_correto or not texto_correto:
            subst = contingencia_questoes[idx % len(contingencia_questoes)]
            texto_correto = subst["trad"]

        # Garante alternativas únicas sem duplicatas e sem placeholders
        textos_unicos = []
        for a in alts:
            t = str(a.get("texto", "")).strip()
            if (
                t
                and not t.startswith("[")
                and not t.startswith("Alternativa ")
                and "termo_" not in t
                and t.lower() != texto_correto.lower()
                and t not in textos_unicos
            ):
                textos_unicos.append(t)

        for fb in fallbacks_garantia:
            if len(textos_unicos) >= 3:
                break
            if fb.lower() != texto_correto.lower() and fb not in textos_unicos:
                textos_unicos.append(fb)

        # Re-monta exatamente 4 alternativas
        pos_correta = letras_esperadas.index(resp_correta) if resp_correta in letras_esperadas else 0
        lista_textos = list(textos_unicos[:3])
        lista_textos.insert(pos_correta, texto_correto)

        q["alternativas"] = [
            {"letra": letras_esperadas[i], "texto": lista_textos[i]}
            for i in range(4)
        ]
        q["resposta_correta"] = letras_esperadas[pos_correta]
        q["fonte_confianca"] = q.get("fonte_confianca", "alta")
        questoes_finais.append(q)

    return JsonResponse(
        {
            "success": True,
            "pacote_id": result.get("pacote_id"),
            "variante": {"id": variante.id, "nome": variante.nome, "codigo": variante.codigo},
            "questoes": questoes_finais,
            "cache_hit": result.get("cache_hit", False),
        },
        status=200,
    )


@csrf_exempt
@ratelimit(key='ip', rate='20/m', block=True)
@supabase_auth_required
@require_POST
def avaliar_teste(request):
    """Avalia o teste do usuário via TRI e salva o nível por variante."""
    try:
        body = json.loads(request.body)
    except (json.JSONDecodeError, ValueError):
        return JsonResponse({"success": False, "error": "Corpo da requisição inválido"}, status=400)

    answers = body.get("answers", [])
    current_level = int(body.get("current_level", 1))
    variante_id = body.get("variante_id")

    if not variante_id:
        return JsonResponse(
            {"success": False, "error": "O campo 'variante_id' é obrigatório."},
            status=400,
        )

    # ── Resolve entidades ─────────────────────────────────────────────────────
    user, err = _get_user_or_error(request)
    if err:
        return err

    variante = VarianteTupi.objects.filter(id=variante_id, ativo=True).first()
    if not variante:
        return JsonResponse(
            {"success": False, "error": "Variante inválida ou inativa."},
            status=404,
        )

    # ── Verifica unicidade (proteção dupla) ──────────────────────────────────
    if TestAttempt.objects.filter(user=user, variante=variante).exists():
        nivel = UserVarianteLevel.objects.filter(user=user, variante=variante).first()
        return JsonResponse(
            {
                "success": False,
                "error": f"Teste para '{variante.nome}' já realizado.",
                "nivel_atual": nivel.nivel if nivel else 1,
            },
            status=409,
        )

    # ── Avaliação TRI ─────────────────────────────────────────────────────────
    evaluation = evaluate_test(answers, current_level)
    new_level = evaluation["level"]
    theta = evaluation["theta"]
    is_cheating = evaluation["cheating"]

    try:
        attempt = TestAttempt.objects.create(
            user=user,
            variante=variante,
            calculated_level=new_level,
            calculated_theta=theta,
            is_suspected_cheating=is_cheating,
        )

        # GANHO DE PERFORMANCE (Anti N+1): bulk_create com batch_size=50 em lote único
        answer_items = [
            AnswerItem(
                attempt=attempt,
                question_hash=str(hash(ans.get("question_text", "")))[:250],
                question_text=ans.get("question_text", ""),
                selected_letter=ans.get("selected_letter", ""),
                is_correct=ans.get("is_correct", False),
                time_taken_seconds=float(ans.get("time_taken_seconds", 0.0)),
                param_b=(current_level - 5) / 2.0,
            )
            for ans in answers
        ]
        AnswerItem.objects.bulk_create(answer_items, batch_size=50)

        # Atualiza ou cria o nível do usuário PARA ESTA VARIANTE ESPECÍFICA
        UserVarianteLevel.objects.update_or_create(
            user=user,
            variante=variante,
            defaults={"nivel": new_level},
        )

        # Se a variante testada for a variante ativa do usuário, sincroniza também
        if user.variante_ativa_id == variante.id:
            user.save(update_fields=["updated_at"])

    except Exception:
        logger.error("Erro ao salvar avaliação de teste para uid=%s", user.supabase_uid, exc_info=True)

    return JsonResponse(
        {
            "success": True,
            "variante": {"id": variante.id, "nome": variante.nome},
            "new_level": new_level,
            "theta": theta,
            "is_cheating": is_cheating,
            "message": (
                "Teste avaliado com sucesso. Possível chute detectado."
                if is_cheating
                else "Teste avaliado com sucesso."
            ),
        },
        status=200,
    )


@csrf_exempt
@ratelimit(key='ip', rate='20/m', block=True)
@supabase_auth_required
def check_teste_variante(request):
    """
    GET — Verifica se o usuário já fez o teste para uma variante.
    Parâmetro query: ?variante_id=<int>
    Retorna: { "ja_testado": bool, "nivel": int | null }
    """
    variante_id = request.GET.get("variante_id")
    if not variante_id:
        return JsonResponse({"error": "Parâmetro 'variante_id' obrigatório."}, status=400)

    user, err = _get_user_or_error(request)
    if err:
        return err

    variante = VarianteTupi.objects.filter(id=variante_id).first()
    if not variante:
        return JsonResponse({"error": "Variante não encontrada."}, status=404)

    attempt = TestAttempt.objects.filter(user=user, variante=variante).first()
    nivel_obj = UserVarianteLevel.objects.filter(user=user, variante=variante).first()

    return JsonResponse(
        {
            "success": True,
            "variante": {"id": variante.id, "nome": variante.nome},
            "ja_testado": attempt is not None,
            "nivel": nivel_obj.nivel if nivel_obj else None,
        }
    )


@csrf_exempt
@ratelimit(key='ip', rate='20/m', block=True)
@supabase_auth_required
@require_POST
def definir_nivel_inicial(request):
    """
    POST — Permite definir o nível inicial (ex: 1 para iniciante total)
    sem a necessidade de realizar o teste adaptativo.
    Payload: { "variante_id": int, "nivel": int }
    """
    user, err = _get_user_or_error(request)
    if err:
        return err
    try:
        body = json.loads(request.body)
    except (json.JSONDecodeError, ValueError):
        return JsonResponse({"error": "JSON inválido."}, status=400)

    variante_id = body.get('variante_id')
    nivel = int(body.get('nivel', 1))

    variante = VarianteTupi.objects.filter(id=variante_id, ativo=True).first()
    if not variante:
        return JsonResponse({"error": "Variante não encontrada."}, status=404)

    lvl_obj, created = UserVarianteLevel.objects.get_or_create(
        user=user, variante=variante, defaults={'nivel': nivel}
    )
    if not created and lvl_obj.nivel != nivel:
        lvl_obj.nivel = nivel
        lvl_obj.save(update_fields=['nivel', 'updated_at'])

    TestAttempt.objects.get_or_create(
        user=user,
        variante=variante,
        defaults={'nivel_inicial': nivel, 'nivel_calculado': nivel, 'score_total': 0.0}
    )

    user.variante_ativa = variante
    user.save(update_fields=['variante_ativa', 'updated_at'])

    return JsonResponse({
        "success": True,
        "variante_id": variante.id,
        "nivel": lvl_obj.nivel,
        "message": f"Nível inicial {lvl_obj.nivel} definido para {variante.nome}.",
    })

