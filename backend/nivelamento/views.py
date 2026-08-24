"""
View da API REST de nivelamento.

Corrigido pela Auditoria Técnica V3.0:
- API-004: @ratelimit adicionado no endpoint de geração de questões
- API-005: str(exc) removido da resposta HTTP de erro
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
from nivelamento.schemas import GenerateQuestionPayload
from nivelamento.services.rag_service import RAGService

logger = logging.getLogger("nivelamento.views")


@csrf_exempt
@ratelimit(key='ip', rate='20/m', block=True)       # Camada 1: por IP
@ratelimit(key='user', rate='5/m', block=True)       # Camada 2: por usuário autenticado
@supabase_auth_required
@require_POST
def gerar_questao_nivelamento(request):
    """Gera questões de nivelamento adaptativo com base no histórico do usuário."""
    try:
        body = json.loads(request.body)
    except (json.JSONDecodeError, ValueError):
        logger.warning("Corpo da requisição inválido")
        return JsonResponse(
            {
                "success": False,
                "error": {
                    "code": "INVALID_JSON",
                    "message": "O corpo da requisição deve ser um JSON válido.",
                },
            },
            status=400,
        )

    try:
        payload = GenerateQuestionPayload.model_validate(body)
    except ValidationError as exc:
        error_messages = "; ".join(
            f"{e['loc']}: {e['msg']}" for e in exc.errors()
        )
        logger.warning("Payload inválido: %s", error_messages)
        return JsonResponse(
            {
                "success": False,
                "error": {
                    "code": "INVALID_PAYLOAD",
                    "message": "Dados inválidos no payload.",
                    "details": error_messages,
                },
            },
            status=400,
        )

    supabase_uid = request.user_data.get("sub")
    if not supabase_uid:
        return JsonResponse(
            {
                "success": False,
                "error": {
                    "code": "UNAUTHORIZED",
                    "message": "Token inválido ou sem identificação de usuário.",
                },
            },
            status=401,
        )

    try:
        service = RAGService()
        result = service.generate(
            supabase_uid=supabase_uid,
            nivel_atual=payload.nivel_atual,
            acertou_anterior=payload.acertou_anterior,
        )
    except ValueError as exc:
        logger.warning("Erro de validação: %s", exc)
        return JsonResponse(
            {
                "success": False,
                "error": {
                    "code": "VALIDATION_ERROR",
                    "message": str(exc),
                },
            },
            status=400,
        )
    except RuntimeError as exc:
        # API-005: não expor str(exc) com detalhes de infraestrutura
        logger.error("Erro na geração de questões para uid=%s", supabase_uid, exc_info=True)
        return JsonResponse(
            {
                "success": False,
                "error": {
                    "code": "QUESTION_GENERATION_FAILED",
                    "message": "Não foi possível gerar as questões. Tente novamente.",
                },
            },
            status=500,
        )
    except Exception:
        logger.exception("Erro inesperado ao gerar questão para uid=%s", supabase_uid)
        return JsonResponse(
            {
                "success": False,
                "error": {
                    "code": "INTERNAL_ERROR",
                    "message": "Erro interno no servidor.",
                },
            },
            status=500,
        )

    return JsonResponse(
        {
            "success": True,
            "questoes": result["questoes"],
        },
        status=200,
    )
