"""
Views da API de usuários.

Atualizado para a arquitetura da Jornada Histórica V2:
- Removido tupi_level (substituído por UserVarianteLevel no app nivelamento).
- update_level agora delega ao UserVarianteLevel por variante.
- register_user não cria mais tupi_level — o nivelamento ocorre por variante separadamente.
"""

import json
import logging

from django.db import IntegrityError
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST, require_GET
from django_ratelimit.decorators import ratelimit

from .decorators import supabase_auth_required
from .models import UserProfile

logger = logging.getLogger('users.views')

# Valores permitidos para source
VALID_SOURCES = {
    'redes_sociais', 'indicacao', 'escola', 'pesquisa', 'outro', '',
}


@csrf_exempt
@ratelimit(key='ip', rate='10/m', block=True)
@supabase_auth_required
def check_user(request):
    """
    Retorna se o usuário autenticado já possui perfil cadastrado no Django.
    Inclui a variante ativa e XP total do usuário.
    """
    user_id = request.user_data.get('sub')
    user = UserProfile.objects.select_related('variante_ativa').filter(supabase_uid=user_id).first()
    exists = user is not None

    variante_ativa_data = None
    if user and user.variante_ativa:
        # Inclui status de nivelamento para que o Flutter saiba se deve redirecionar ao teste
        from nivelamento.models import TestAttempt, UserVarianteLevel
        variante = user.variante_ativa
        ja_testou = TestAttempt.objects.filter(user=user, variante=variante).exists()
        nivel_obj = UserVarianteLevel.objects.filter(user=user, variante=variante).first()
        variante_ativa_data = {
            "id": variante.id,
            "nome": variante.nome,
            "codigo": variante.codigo,
            "ja_testou": ja_testou,
            "nivel": nivel_obj.nivel if nivel_obj else None,
        }

    return JsonResponse({
        "status": "Autenticado com sucesso",
        "exists": exists,
        "xp_total": user.xp_total if user else 0,
        "variante_ativa": variante_ativa_data,
    })



@csrf_exempt
@require_POST
@ratelimit(key='ip', rate='10/m', block=True)
@supabase_auth_required
def register_user(request):
    """
    Cria o perfil do usuário após a conclusão do onboarding.
    Não define mais tupi_level — o nível é definido pelo teste de nivelamento por variante.
    """
    user_id = request.user_data.get('sub')
    email = request.user_data.get('email', '')

    try:
        body = json.loads(request.body)
    except (json.JSONDecodeError, ValueError):
        return JsonResponse({'error': 'Corpo da requisição inválido'}, status=400)

    name = body.get('name', '').strip()
    source = body.get('source', '').strip()

    if not name:
        return JsonResponse({'error': 'O campo "name" é obrigatório'}, status=400)

    if source not in VALID_SOURCES:
        source = 'outro'

    # API-003: get_or_create atômico evita race condition TOCTOU
    try:
        profile, created = UserProfile.objects.get_or_create(
            supabase_uid=user_id,
            defaults={
                'email': email,
                'name': name,
                'source': source,
            },
        )
    except IntegrityError:
        logger.warning("Conflito de integridade ao criar UserProfile para uid=%s", user_id)
        existing_user = UserProfile.objects.filter(email=email).first()
        if existing_user:
            # SECURITY-001: Nunca sobrescrevemos o supabase_uid de um perfil existente
            # para evitar Account Takeover. O email já está vinculado a outra conta.
            logger.warning(
                "Tentativa de re-registro com email já existente. "
                "email=%s novo_uid=%s uid_existente=%s",
                email, user_id, existing_user.supabase_uid,
            )
            return JsonResponse(
                {
                    "error": "Este e-mail já está associado a uma conta. "
                             "Por favor, faça login com a conta original.",
                    "code": "EMAIL_ALREADY_EXISTS",
                },
                status=409,
            )
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
def update_variante_ativa(request):
    """
    Atualiza a variante (língua) ativa do usuário.
    Se o usuário ainda não fez o teste de nivelamento para esta variante,
    o Flutter deve redirecionar para o fluxo de nivelamento.

    Payload: { "variante_id": int }
    """
    user_id = request.user_data.get('sub')
    try:
        body = json.loads(request.body)
        variante_id = body.get('variante_id')

        if not variante_id:
            return JsonResponse({'error': 'O campo "variante_id" é obrigatório'}, status=400)

        from trilha.models import VarianteTupi
        variante = VarianteTupi.objects.filter(id=variante_id, ativo=True).first()
        if not variante:
            return JsonResponse({'error': 'Variante inválida ou inativa.'}, status=404)

        user = UserProfile.objects.filter(supabase_uid=user_id).first()
        if not user:
            return JsonResponse({'error': 'Usuário não encontrado'}, status=404)

        user.variante_ativa = variante
        user.save(update_fields=['variante_ativa', 'updated_at'])

        # Verifica se o usuário já fez o teste para esta variante
        from nivelamento.models import TestAttempt, UserVarianteLevel
        ja_testou = TestAttempt.objects.filter(user=user, variante=variante).exists()
        nivel_obj = UserVarianteLevel.objects.filter(user=user, variante=variante).first()

        logger.info("Variante ativa atualizada para uid=%s: %s", user_id, variante.codigo)
        return JsonResponse({
            "status": "Variante atualizada com sucesso",
            "variante": {"id": variante.id, "nome": variante.nome, "codigo": variante.codigo},
            "ja_testou": ja_testou,
            "nivel": nivel_obj.nivel if nivel_obj else None,
            "precisa_nivelar": not ja_testou,
        })

    except json.JSONDecodeError:
        return JsonResponse({'error': 'Corpo da requisição inválido'}, status=400)
    except Exception:
        logger.exception("Erro inesperado em update_variante_ativa para uid=%s", user_id)
        return JsonResponse({'error': 'Erro interno do servidor'}, status=500)


@csrf_exempt
@require_GET
@ratelimit(key='ip', rate='20/m', block=True)
@supabase_auth_required
def get_profile(request):
    """Retorna o perfil completo do usuário com XP, achievements e progresso."""
    user_id = request.user_data.get('sub')
    user = UserProfile.objects.select_related('variante_ativa').filter(supabase_uid=user_id).first()
    if not user:
        return JsonResponse({'error': 'Usuário não encontrado'}, status=404)

    # Achievements conquistados
    achievements = []
    for ua in user.userachievement_set.select_related('achievement').order_by('-conquistada_em'):
        achievements.append({
            'codigo': ua.achievement.codigo,
            'nome': ua.achievement.nome,
            'icone': ua.achievement.icone,
            'tipo': ua.achievement.tipo,
            'conquistada_em': ua.conquistada_em.isoformat(),
        })

    return JsonResponse({
        'success': True,
        'profile': {
            'name': user.name,
            'email': user.email,
            'xp_total': user.xp_total,
            'variante_ativa': {
                'id': user.variante_ativa.id,
                'nome': user.variante_ativa.nome,
                'codigo': user.variante_ativa.codigo,
                'icone': user.variante_ativa.icone,
            } if user.variante_ativa else None,
        },
        'achievements': achievements,
    })