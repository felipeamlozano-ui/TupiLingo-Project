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
@ratelimit(key='ip', rate='30/m', block=True)
@supabase_auth_required
def admin_check(request):
    """Retorna se o usuário logado possui privilégios de administrador."""
    from .decorators import is_request_admin
    return JsonResponse({
        "success": True,
        "is_admin": is_request_admin(request),
    })


@csrf_exempt
@require_GET
@ratelimit(key='ip', rate='30/m', block=True)
@supabase_auth_required
def get_profile(request):
    """
    Retorna o perfil completo do usuário (RF04 + RF10):
    - Dados básicos e XP
    - Nível calibrado na variante ativa
    - Dias de ofensiva real
    - Histórico detalhado das últimas lições concluídas
    - Desempenho e taxa de acerto por capítulo
    - Galeria completa de conquistas (desbloqueadas e bloqueadas)
    """
    from datetime import date, timedelta
    from django.db.models import Avg, Count
    from nivelamento.models import UserVarianteLevel
    from trilha.models import Capitulo, Licao
    from .models import UserLesson
    from .services.achievement_service import (
        check_and_grant_xp_achievements,
        get_all_achievements_with_status,
    )

    user_id = request.user_data.get('sub')
    user = UserProfile.objects.select_related('variante_ativa').filter(supabase_uid=user_id).first()
    if not user:
        return JsonResponse({'error': 'Usuário não encontrado'}, status=404)

    # 1. Nível calibrado na variante ativa
    nivel_atual = 1
    if user.variante_ativa:
        lvl_obj = UserVarianteLevel.objects.filter(user=user, variante=user.variante_ativa).first()
        if lvl_obj:
            nivel_atual = lvl_obj.nivel

    # 2. Conquistas automáticas por XP e listagem
    check_and_grant_xp_achievements(user)
    achievements_desbloqueadas, achievements_bloqueadas = get_all_achievements_with_status(user)

    # 3. Cálculo de Ofensiva (dias consecutivos)
    datas_conclusao = list(
        UserLesson.objects.filter(usuario=user, status='concluida', concluida_em__isnull=False)
        .dates('concluida_em', 'day', order='DESC')
    )
    dias_ofensiva = 0
    if datas_conclusao:
        hoje = date.today()
        ontem = hoje - timedelta(days=1)
        primeira_data = datas_conclusao[0]
        if primeira_data == hoje or primeira_data == ontem:
            dias_ofensiva = 1
            data_esperada = primeira_data - timedelta(days=1)
            for d in datas_conclusao[1:]:
                if d == data_esperada:
                    dias_ofensiva += 1
                    data_esperada -= timedelta(days=1)
                else:
                    break

    # 4. Histórico recente de lições
    licoes_qs = (
        UserLesson.objects.filter(usuario=user, status='concluida')
        .select_related('licao__capitulo')
        .order_by('-concluida_em')[:10]
    )
    historico_licoes = [
        {
            'id': ul.licao.id,
            'titulo': ul.licao.titulo,
            'capitulo_titulo': ul.licao.capitulo.titulo,
            'capitulo_numero': ul.licao.capitulo.numero,
            'accuracy': ul.accuracy,
            'accuracy_percent': int(round(ul.accuracy * 100)),
            'earned_xp': ul.earned_xp,
            'concluida_em': ul.concluida_em.isoformat() if ul.concluida_em else None,
        }
        for ul in licoes_qs
    ]

    # 5. Desempenho por Capítulo (PERF-001: O(1) queries sem N+1)
    desempenho_por_capitulo = []
    if user.variante_ativa:
        capitulos = list(
            Capitulo.objects.filter(
                trilha__variante=user.variante_ativa, publicado=True
            ).order_by('numero')
        )

        totais_qs = (
            Licao.objects
            .filter(capitulo__trilha__variante=user.variante_ativa, publicada=True)
            .values('capitulo_id')
            .annotate(total=Count('id'))
        )
        totais_map = {row['capitulo_id']: row['total'] for row in totais_qs}

        concluidas_qs = (
            UserLesson.objects
            .filter(
                usuario=user,
                licao__capitulo__trilha__variante=user.variante_ativa,
                licao__publicada=True,
                status='concluida',
            )
            .values('licao__capitulo_id')
            .annotate(
                qtd_concluidas=Count('id'),
                media_acc=Avg('accuracy'),
            )
        )
        concluidas_map = {
            row['licao__capitulo_id']: (row['qtd_concluidas'], row['media_acc'] or 0.0)
            for row in concluidas_qs
        }

        for cap in capitulos:
            qtd_concluidas, media_acc = concluidas_map.get(cap.id, (0, 0.0))
            desempenho_por_capitulo.append({
                'capitulo_id': cap.id,
                'numero': cap.numero,
                'titulo': cap.titulo,
                'total_licoes': totais_map.get(cap.id, 0),
                'licoes_concluidas': qtd_concluidas,
                'accuracy_media': round(media_acc, 2),
                'accuracy_percent': int(round(media_acc * 100)),
            })

    # Total de lições concluídas
    total_licoes_concluidas = UserLesson.objects.filter(usuario=user, status='concluida').count()

    return JsonResponse({
        'success': True,
        'profile': {
            'name': user.name,
            'email': user.email,
            'xp_total': user.xp_total,
            'nivel_atual': nivel_atual,
            'dias_ofensiva': dias_ofensiva,
            'total_licoes_concluidas': total_licoes_concluidas,
            'variante_ativa': {
                'id': user.variante_ativa.id,
                'nome': user.variante_ativa.nome,
                'codigo': user.variante_ativa.codigo,
                'icone': user.variante_ativa.icone,
            } if user.variante_ativa else None,
        },
        'historico_licoes': historico_licoes,
        'desempenho_por_capitulo': desempenho_por_capitulo,
        'achievements': achievements_desbloqueadas,
        'achievements_bloqueadas': achievements_bloqueadas,
    })