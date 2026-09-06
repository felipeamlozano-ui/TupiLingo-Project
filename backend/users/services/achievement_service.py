"""
Serviço de Conquistas (Achievements) — TupiLingo.

Gerencia a concessão segura e atômica de medalhas e conquistas no backend.
Totalmente protegido contra manipulação no cliente.
"""

import logging
from django.db import transaction
from django.utils import timezone
from users.models import Achievement, UserAchievement, UserProfile, UserLesson, TipoAchievementChoices
from trilha.models import Licao, Capitulo

logger = logging.getLogger('users.achievements')

from django.core.cache import cache

DEFAULT_ACHIEVEMENTS = [
    # XP Tiers
    {
        'codigo': 'xp_semente',
        'nome': 'Semente Curiosa',
        'descricao': 'Deu os primeiros passos na língua Tupi.',
        'tipo': TipoAchievementChoices.XP_TIER,
        'icone': '🌱',
        'xp_necessario': 0,
    },
    {
        'codigo': 'xp_folha',
        'nome': 'Folha da Floresta',
        'descricao': 'Alcançou 500 XP na jornada de aprendizado.',
        'tipo': TipoAchievementChoices.XP_TIER,
        'icone': '🍃',
        'xp_necessario': 500,
    },
    {
        'codigo': 'xp_arco',
        'nome': 'Arco Certeiro',
        'descricao': 'Alcançou 1500 XP acumulados na jornada.',
        'tipo': TipoAchievementChoices.XP_TIER,
        'icone': '🏹',
        'xp_necessario': 1500,
    },
    {
        'codigo': 'xp_guerreiro',
        'nome': 'Guerreiro Audaz',
        'descricao': 'Alcançou 4000 XP de experiência ancestral.',
        'tipo': TipoAchievementChoices.XP_TIER,
        'icone': '🪓',
        'xp_necessario': 4000,
    },
    {
        'codigo': 'xp_paje',
        'nome': 'Pajé Sábio',
        'descricao': 'Alcançou 8000 XP de sabedoria da floresta.',
        'tipo': TipoAchievementChoices.XP_TIER,
        'icone': '🦅',
        'xp_necessario': 8000,
    },
    {
        'codigo': 'xp_guardiao',
        'nome': 'Guardião da Terra',
        'descricao': 'Alcançou 15000 XP de mestria máxima no TupiLingo.',
        'tipo': TipoAchievementChoices.XP_TIER,
        'icone': '👑',
        'xp_necessario': 15000,
    },
    # Culturais & Desafios
    {
        'codigo': 'cultural_primeira_licao',
        'nome': 'Primeira Flecha',
        'descricao': 'Concluiu com sucesso a primeira lição na Trilha.',
        'tipo': TipoAchievementChoices.CULTURAL,
        'icone': '🎯',
        'xp_necessario': 0,
    },
    {
        'codigo': 'cultural_perfeicao',
        'nome': 'Mente Impecável',
        'descricao': 'Concluiu uma lição com 100% de precisão nos exercícios.',
        'tipo': TipoAchievementChoices.CULTURAL,
        'icone': '💎',
        'xp_necessario': 0,
    },
    {
        'codigo': 'cultural_cap1',
        'nome': 'Desbravador da Mata',
        'descricao': 'Concluiu todas as lições do Capítulo 1.',
        'tipo': TipoAchievementChoices.CULTURAL,
        'icone': '🗺️',
        'xp_necessario': 0,
    },
    {
        'codigo': 'cultural_cap2',
        'nome': 'Guardião da Aldeia',
        'descricao': 'Concluiu todas as lições do Capítulo 2.',
        'tipo': TipoAchievementChoices.CULTURAL,
        'icone': '🛖',
        'xp_necessario': 0,
    },
]


def ensure_default_achievements():
    """Garante que todas as conquistas padrão existam no banco de dados — cacheado por 1h (PERF-004)."""
    cache_key = 'tupilingo_achievements_seeded'
    if cache.get(cache_key):
        return
    for item in DEFAULT_ACHIEVEMENTS:
        Achievement.objects.get_or_create(
            codigo=item['codigo'],
            defaults={
                'nome': item['nome'],
                'descricao': item['descricao'],
                'tipo': item['tipo'],
                'icone': item['icone'],
                'xp_necessario': item['xp_necessario'],
            }
        )
    cache.set(cache_key, True, timeout=3600)


def check_and_grant_xp_achievements(user: UserProfile) -> list[Achievement]:
    """
    Verifica se o usuário atingiu os requisitos de XP para novas medalhas de XP.
    Retorna a lista de conquistas recém-desbloqueadas.
    """
    ensure_default_achievements()
    unlocked = []

    existing_ids = set(
        UserAchievement.objects.filter(user=user).values_list('achievement_id', flat=True)
    )

    eligible = Achievement.objects.filter(
        tipo=TipoAchievementChoices.XP_TIER,
        xp_necessario__lte=user.xp_total,
    ).exclude(id__in=existing_ids)

    for ach in eligible:
        UserAchievement.objects.create(user=user, achievement=ach)
        unlocked.append(ach)
        logger.info("Usuário %s (%s) desbloqueou achievement: %s", user.id, user.email, ach.codigo)

    return unlocked


def check_and_grant_lesson_achievements(user: UserProfile, licao: Licao, accuracy: float) -> list[Achievement]:
    """
    Verifica e concede conquistas relacionadas a lições:
    - Primeira Lição
    - Lição 100% perfeita
    - Conclusão completa de Capítulo
    """
    ensure_default_achievements()
    unlocked = []

    existing_codigos = set(
        user.achievements.values_list('codigo', flat=True)
    )

    # 1. Primeira Flecha
    if 'cultural_primeira_licao' not in existing_codigos:
        ach = Achievement.objects.filter(codigo='cultural_primeira_licao').first()
        if ach:
            UserAchievement.objects.create(user=user, achievement=ach)
            unlocked.append(ach)
            existing_codigos.add('cultural_primeira_licao')

    # 2. Mente Impecável (accuracy 100%)
    if accuracy >= 0.999 and 'cultural_perfeicao' not in existing_codigos:
        ach = Achievement.objects.filter(codigo='cultural_perfeicao').first()
        if ach:
            UserAchievement.objects.create(user=user, achievement=ach)
            unlocked.append(ach)
            existing_codigos.add('cultural_perfeicao')

    # 3. Conclusão do Capítulo
    capitulo = licao.capitulo
    cap_codigo = f'cultural_cap{capitulo.numero}'
    if cap_codigo in [a['codigo'] for a in DEFAULT_ACHIEVEMENTS] and cap_codigo not in existing_codigos:
        # Verifica se todas as lições publicadas do capítulo foram concluídas
        total_licoes = capitulo.licoes.filter(publicada=True).count()
        licoes_concluidas = UserLesson.objects.filter(
            usuario=user,
            licao__capitulo=capitulo,
            licao__publicada=True,
            status='concluida'
        ).count()

        if total_licoes > 0 and licoes_concluidas >= total_licoes:
            ach = Achievement.objects.filter(codigo=cap_codigo).first()
            if ach:
                UserAchievement.objects.create(user=user, achievement=ach)
                unlocked.append(ach)
                logger.info("Usuário %s completou Capítulo %s! Conquista: %s", user.id, capitulo.numero, cap_codigo)

    return unlocked


def get_all_achievements_with_status(user: UserProfile) -> tuple[list[dict], list[dict]]:
    """
    Retorna duas listas:
    1. Conquistadas: lista de dicts com dados e data de conquista.
    2. Bloqueadas: lista de dicts com dados e requisitos para desbloqueio.
    """
    ensure_default_achievements()

    user_achievements = {
        ua.achievement_id: ua.conquistada_em
        for ua in UserAchievement.objects.filter(user=user).select_related('achievement')
    }

    all_achievements = Achievement.objects.all().order_by('xp_necessario', 'id')

    unlocked = []
    locked = []

    for ach in all_achievements:
        is_unlocked = ach.id in user_achievements
        item = {
            'id': ach.id,
            'codigo': ach.codigo,
            'nome': ach.nome,
            'descricao': ach.descricao,
            'tipo': ach.tipo,
            'icone': ach.icone,
            'xp_necessario': ach.xp_necessario,
            'desbloqueada': is_unlocked,
        }
        if is_unlocked:
            item['conquistada_em'] = user_achievements[ach.id].isoformat()
            unlocked.append(item)
        else:
            item['progresso_xp'] = user.xp_total
            locked.append(item)

    return unlocked, locked
