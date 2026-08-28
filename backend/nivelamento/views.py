

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
from nivelamento.models import TestAttempt, AnswerItem
from nivelamento.services.tri_service import evaluate_test

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
        result = service.generate(nivel_atual=payload.nivel_atual)
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

@csrf_exempt
@ratelimit(key='ip', rate='20/m', block=True)
@supabase_auth_required
@require_POST
def avaliar_teste(request):
    """Avalia o teste do usuário via TRI e heurísticas anti-chute."""
    try:
        body = json.loads(request.body)
    except (json.JSONDecodeError, ValueError):
        return JsonResponse({"success": False, "error": "Corpo da requisição inválido"}, status=400)
        
    answers = body.get("answers", [])
    current_level = int(body.get("current_level", 1))
    
    supabase_uid = request.user_data.get("sub")
    if not supabase_uid:
        return JsonResponse({"success": False, "error": "UNAUTHORIZED"}, status=401)
        
    user = UserProfile.objects.filter(supabase_uid=supabase_uid).first()
    if not user:
        email = request.user_data.get("email")
        if email:
            user = UserProfile.objects.filter(email=email).first()
            if user:
                user.supabase_uid = supabase_uid
                user.save(update_fields=['supabase_uid'])
                
    if not user:
        return JsonResponse({"success": False, "error": "Usuário não encontrado"}, status=404)
        
    # Chama o serviço de TRI
    evaluation = evaluate_test(answers, current_level)
    new_level = evaluation["level"]
    theta = evaluation["theta"]
    is_cheating = evaluation["cheating"]
    
    # Salva no banco de dados para calibração futura
    try:
        attempt = TestAttempt.objects.create(
            user=user,
            calculated_level=new_level,
            calculated_theta=theta,
            is_suspected_cheating=is_cheating
        )
        
        for ans in answers:
            AnswerItem.objects.create(
                attempt=attempt,
                question_hash=str(hash(ans.get("question_text", "")))[:250],
                question_text=ans.get("question_text", ""),
                selected_letter=ans.get("selected_letter", ""),
                is_correct=ans.get("is_correct", False),
                time_taken_seconds=float(ans.get("time_taken_seconds", 0.0)),
                param_b=(current_level - 5) / 2.0
            )
            
        # Atualiza o nível do usuário
        user.tupi_level = str(new_level)
        user.save(update_fields=['tupi_level', 'updated_at'])
        
    except Exception as e:
        logger.error(f"Erro ao salvar avaliação de teste: {e}")
        
    return JsonResponse({
        "success": True,
        "new_level": new_level,
        "theta": theta,
        "is_cheating": is_cheating,
        "message": "Teste avaliado com sucesso. Chute detectado." if is_cheating else "Teste avaliado com sucesso."
    }, status=200)
