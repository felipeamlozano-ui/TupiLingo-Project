"""
View da API REST de nivelamento.

Endpoint que recebe requisições do frontend, validado via JWT do Supabase,
e delega toda a lógica para os services.
"""

from __future__ import annotations

import hashlib
import hmac
import json
import logging

from django.conf import settings
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST
from pydantic import ValidationError

from users.decorators import supabase_auth_required
from nivelamento.schemas import GenerateQuestionPayload
from nivelamento.services.rag_service import RAGService

logger = logging.getLogger("nivelamento.views")





@csrf_exempt
@supabase_auth_required
@require_POST
def gerar_questao_nivelamento(request):
    """
    Endpoint para gerar questão de nivelamento adaptativo via API.

    Recebe um POST com JWT válido e payload JSON contendo:
    - nivel_atual: nível atual (1-10)
    - acertou_anterior: bool

    Retorna a questão gerada ou erro estruturado.
    """
    # 1. Parsear body JSON
    try:
        body = json.loads(request.body)
    except (json.JSONDecodeError, ValueError):
        logger.warning("[WEBHOOK] Corpo da requisição não é JSON válido")
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

    # 2. Validar payload com Pydantic
    try:
        payload = GenerateQuestionPayload.model_validate(body)
    except ValidationError as exc:
        error_messages = "; ".join(
            f"{e['loc']}: {e['msg']}" for e in exc.errors()
        )
        logger.warning("[WEBHOOK] Payload inválido: %s", error_messages)
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

    # 3. Extrair UID do usuário a partir do token validado pelo decorator
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

    # 4. Executar pipeline de geração
    logger.info(
        "[API] Iniciando geração para uid='%s...' nivel=%d acertou=%s",
        supabase_uid[:8],
        payload.nivel_atual,
        payload.acertou_anterior,
    )

    try:
        service = RAGService()
        result = service.generate(
            supabase_uid=supabase_uid,
            nivel_atual=payload.nivel_atual,
            acertou_anterior=payload.acertou_anterior,
        )
    except ValueError as exc:
        # Erros de validação de negócio (ex: nível fora do range)
        logger.warning("[API] Erro de validação: %s", exc)
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
        # Erros controlados dos services (ChromaDB, Gemini, Supabase)
        logger.error("[API] Erro na pipeline: %s", exc)
        return JsonResponse(
            {
                "success": False,
                "error": {
                    "code": "QUESTION_GENERATION_FAILED",
                    "message": f"Erro detalhado: {str(exc)}",
                },
            },
            status=500,
        )
    except Exception:
        # Erro inesperado — logar traceback completo mas não expor ao cliente
        logger.exception("[API] Erro inesperado na pipeline")
        return JsonResponse(
            {
                "success": False,
                "error": {
                    "code": "INTERNAL_ERROR",
                    "message": "Erro interno do servidor.",
                },
            },
            status=500,
        )

    # 5. Retornar sucesso
    logger.info(
        "[API] Questões geradas com sucesso para uid='%s...'",
        supabase_uid[:8],
    )

    return JsonResponse(
        {
            "success": True,
            "questoes": result["questoes"],
        },
        status=200,
    )
