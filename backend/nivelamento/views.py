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

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST
from django_ratelimit.decorators import ratelimit
from pydantic import ValidationError

from users.decorators import supabase_auth_required
from users.models import UserProfile
from nivelamento.schemas import GenerateQuestionPayload
from app.ai.rag_service import RAGService
from nivelamento.models import TestAttempt, AnswerItem, UserVarianteLevel
from nivelamento.services.tri_service import evaluate_test
from trilha.models import VarianteTupi

logger = logging.getLogger("nivelamento.views")


def _get_user_or_error(request) -> tuple[UserProfile | None, JsonResponse | None]:
    """Helper: resolve o UserProfile a partir do JWT ou retorna erro 401/404."""
    supabase_uid = request.user_data.get("sub")
    if not supabase_uid:
        return None, JsonResponse(
            {"success": False, "error": {"code": "UNAUTHORIZED", "message": "Token sem identificação."}},
            status=401,
        )

    user = UserProfile.objects.filter(supabase_uid=supabase_uid).first()

    # SECURITY-002: Removida a re-sincronização silenciosa por email.
    # Não atualizamos supabase_uid baseado em email pois isso permite Account Takeover:
    # um atacante com um JWT de uid diferente poderia sequestrar qualquer conta pelo email.
    if not user:
        return None, JsonResponse(
            {"success": False, "error": {"code": "NOT_FOUND", "message": "Usuário não encontrado."}},
            status=404,
        )
    return user, None



@csrf_exempt
@ratelimit(key='ip', rate='20/m', block=True)
@ratelimit(key='user', rate='5/m', block=True)
@supabase_auth_required
@require_POST
def gerar_questao_nivelamento(request):
    """Gera questões de nivelamento adaptativo para uma Variante Tupi específica."""
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

    # ── Resolve Variante ──────────────────────────────────────────────────────
    variante = VarianteTupi.objects.filter(id=payload.variante_id, ativo=True).first()
    if not variante:
        return JsonResponse(
            {"success": False, "error": {"code": "VARIANTE_NOT_FOUND", "message": "Variante inválida ou inativa."}},
            status=404,
        )

    # ── Verifica se o usuário já fez o teste para esta variante ───────────────
    user, err = _get_user_or_error(request)
    if err:
        return err

    ja_fez_teste = TestAttempt.objects.filter(user=user, variante=variante).exists()
    if ja_fez_teste:
        nivel_atual = UserVarianteLevel.objects.filter(user=user, variante=variante).first()
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

    return JsonResponse(
        {
            "success": True,
            "variante": {"id": variante.id, "nome": variante.nome, "codigo": variante.codigo},
            "questoes": result["questoes"],
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

        for ans in answers:
            AnswerItem.objects.create(
                attempt=attempt,
                question_hash=str(hash(ans.get("question_text", "")))[:250],
                question_text=ans.get("question_text", ""),
                selected_letter=ans.get("selected_letter", ""),
                is_correct=ans.get("is_correct", False),
                time_taken_seconds=float(ans.get("time_taken_seconds", 0.0)),
                param_b=(current_level - 5) / 2.0,
            )

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
