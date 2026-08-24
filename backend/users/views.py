"""
Views da API de usuários.

Corrigido pela Auditoria Técnica V3.0:
- API-001: @ratelimit adicionado em update_level + validação de valores permitidos
- API-002: str(e) removido das respostas de erro HTTP
- API-003: TOCTOU race condition em register_user corrigida com get_or_create atômico
"""

import json
import logging

from django.db import IntegrityError
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST
from django_ratelimit.decorators import ratelimit

from .decorators import supabase_auth_required
from .models import UserProfile

logger = logging.getLogger('users.views')

# Valores permitidos para tupi_level — API-001
VALID_LEVELS = {
    'nenhum', 'iniciante', 'intermediario', 'avancado',
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '10',
}

# Valores permitidos para source
VALID_SOURCES = {
    'redes_sociais', 'indicacao', 'escola', 'pesquisa', 'outro', '',
}


@csrf_exempt
@ratelimit(key='ip', rate='10/m', block=True)
@supabase_auth_required
def check_user(request):
    """Retorna se o usuário autenticado já possui perfil cadastrado no Django."""
    user_id = request.user_data.get('sub')

    user = UserProfile.objects.filter(supabase_uid=user_id).first()
    exists = user is not None
    tupi_level = user.tupi_level if user else ""

    return JsonResponse({
        "status": "Autenticado com sucesso",
        "exists": exists,
        "tupi_level": tupi_level,
    })


@csrf_exempt
@require_POST
@ratelimit(key='ip', rate='10/m', block=True)
@supabase_auth_required
def register_user(request):
    """Cria o perfil do usuário após a conclusão do onboarding."""
    user_id = request.user_data.get('sub')
    email = request.user_data.get('email', '')

    try:
        body = json.loads(request.body)
    except (json.JSONDecodeError, ValueError):
        return JsonResponse({'error': 'Corpo da requisição inválido'}, status=400)

    name = body.get('name', '').strip()
    source = body.get('source', '').strip()
    tupi_level = body.get('tupi_level', '').strip()

    if not name:
        return JsonResponse({'error': 'O campo "name" é obrigatório'}, status=400)

    # Valida source e tupi_level
    if source not in VALID_SOURCES:
        source = 'outro'

    if tupi_level not in VALID_LEVELS:
        tupi_level = 'nenhum'

    # API-003: get_or_create atômico evita race condition TOCTOU
    try:
        profile, created = UserProfile.objects.get_or_create(
            supabase_uid=user_id,
            defaults={
                'email': email,
                'name': name,
                'source': source,
                'tupi_level': tupi_level,
            },
        )
    except IntegrityError:
        # E-mail duplicado (outro registro com mesmo e-mail)
        logger.warning("Conflito de integridade ao criar UserProfile para uid=%s", user_id)
        return JsonResponse({"status": "Usuario ja registrado", "created": False})

    if not created:
        return JsonResponse({"status": "Usuario ja registrado", "created": False})

    logger.info("Novo UserProfile criado: uid=%s", user_id)
    return JsonResponse({
        "status": "Cadastro realizado com sucesso",
        "created": True,
    }, status=201)


@csrf_exempt
@require_POST
@ratelimit(key='ip', rate='10/m', block=True)
@supabase_auth_required
def update_level(request):
    """Atualiza o nível de Tupi do usuário."""
    user_id = request.user_data.get('sub')
    try:
        body = json.loads(request.body)
        new_level = str(body.get('level', '')).strip()

        # API-001: valida os valores permitidos antes de salvar
        if not new_level:
            return JsonResponse({'error': 'O campo "level" é obrigatório'}, status=400)

        if new_level not in VALID_LEVELS:
            return JsonResponse(
                {'error': f'Nível inválido. Valores permitidos: {sorted(VALID_LEVELS)}'},
                status=400,
            )

        user = UserProfile.objects.filter(supabase_uid=user_id).first()
        if user:
            user.tupi_level = new_level
            user.save(update_fields=['tupi_level', 'updated_at'])
            logger.info("Nível atualizado para uid=%s: %s", user_id, new_level)
            return JsonResponse({"status": "Nível atualizado com sucesso"})

        return JsonResponse({'error': 'Usuário não encontrado'}, status=404)

    except json.JSONDecodeError:
        return JsonResponse({'error': 'Corpo da requisição inválido'}, status=400)
    except Exception:
        # API-002: não expõe str(e) ao cliente
        logger.exception("Erro inesperado em update_level para uid=%s", user_id)
        return JsonResponse({'error': 'Erro interno do servidor'}, status=500)