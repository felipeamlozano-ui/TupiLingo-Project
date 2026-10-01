"""
Serviço de Conquistas (Achievements) e Medalhas Ancestrais — TupiLingo.

Gerencia a concessão segura e atômica de medalhas e conquistas no backend.
Organizado em 5 categorias e 4 tiers (Bronze, Prata, Ouro e Diamante):
1. XP_TIER: Progressão de Sabedoria Geral (0 a 15.000 XP)
2. STREAK: Constância Diária e Ofensiva (3 a 100 dias)
3. BAU: Caçador de Baús Ancestrais (1 a 20 baús)
4. VOCABULARIO: Mestre do Léxico Tupi (10 a 100 termos)
5. CULTURAL: Desbravador de Capítulos (1 a 20) e Lições Perfeitas
"""

import logging
from django.db import transaction
from django.utils import timezone
from django.core.cache import cache
from users.models import Achievement, UserAchievement, UserProfile, UserLesson, TipoAchievementChoices
from trilha.models import Licao, Capitulo, UserChestReward, VocabularyItem

logger = logging.getLogger('users.achievements')

DEFAULT_ACHIEVEMENTS = [
    # ─── 1. XP TIERS (PROGRESSÃO DE SABEDORIA) ──────────────────────────────────
    {
        'codigo': 'xp_semente',
        'nome': 'Semente Curiosa',
        'descricao': 'Deu os primeiros passos na língua Tupi.',
        'tipo': TipoAchievementChoices.XP_TIER,
        'icone': '🌱',
        'xp_necessario': 0,
        'tier': 'bronze',
    },
    {
        'codigo': 'xp_folha',
        'nome': 'Broto da Floresta',
        'descricao': 'Alcançou 250 XP de experiência nos estudos.',
        'tipo': TipoAchievementChoices.XP_TIER,
        'icone': '🌿',
        'xp_necessario': 250,
        'tier': 'bronze',
    },
    {
        'codigo': 'xp_raiz',
        'nome': 'Raiz Forte',
        'descricao': 'Alcançou 500 XP acumulados na jornada.',
        'tipo': TipoAchievementChoices.XP_TIER,
        'icone': '🍃',
        'xp_necessario': 500,
        'tier': 'bronze',
    },
    {
        'codigo': 'xp_arco',
        'nome': 'Arco Certeiro',
        'descricao': 'Alcançou 1.500 XP acumulados na jornada.',
        'tipo': TipoAchievementChoices.XP_TIER,
        'icone': '🏹',
        'xp_necessario': 1500,
        'tier': 'prata',
    },
    {
        'codigo': 'xp_cangica',
        'nome': 'Fogo Sagrado',
        'descricao': 'Alcançou 2.500 XP de vivência na floresta.',
        'tipo': TipoAchievementChoices.XP_TIER,
        'icone': '🔥',
        'xp_necessario': 2500,
        'tier': 'prata',
    },
    {
        'codigo': 'xp_guerreiro',
        'nome': 'Guerreiro Audaz',
        'descricao': 'Alcançou 4.000 XP de experiência ancestral.',
        'tipo': TipoAchievementChoices.XP_TIER,
        'icone': '🪓',
        'xp_necessario': 4000,
        'tier': 'ouro',
    },
    {
        'codigo': 'xp_cacique',
        'nome': 'Cacique Protetor',
        'descricao': 'Alcançou 6.000 XP de liderança e maestria.',
        'tipo': TipoAchievementChoices.XP_TIER,
        'icone': '🛡️',
        'xp_necessario': 6000,
        'tier': 'ouro',
    },
    {
        'codigo': 'xp_paje',
        'nome': 'Pajé Sábio',
        'descricao': 'Alcançou 8.000 XP de sabedoria originária.',
        'tipo': TipoAchievementChoices.XP_TIER,
        'icone': '🦅',
        'xp_necessario': 8000,
        'tier': 'ouro',
    },
    {
        'codigo': 'xp_serpente',
        'nome': 'Mboi Encantado',
        'descricao': 'Alcançou 12.000 XP de fluência mística.',
        'tipo': TipoAchievementChoices.XP_TIER,
        'icone': '🐍',
        'xp_necessario': 12000,
        'tier': 'diamante',
    },
    {
        'codigo': 'xp_guardiao',
        'nome': 'Guardião de Pindorama',
        'descricao': 'Alcançou 15.000 XP de maestria máxima no TupiLingo.',
        'tipo': TipoAchievementChoices.XP_TIER,
        'icone': '👑',
        'xp_necessario': 15000,
        'tier': 'diamante',
    },

    # ─── 2. STREAK (CONSTÂNCIA E OFENSIVA) ──────────────────────────────────────
    {
        'codigo': 'streak_3',
        'nome': 'Fagulha Matinal',
        'descricao': 'Manteve 3 dias consecutivos de ofensiva.',
        'tipo': TipoAchievementChoices.STREAK,
        'icone': '⚡',
        'xp_necessario': 0,
        'tier': 'bronze',
    },
    {
        'codigo': 'streak_7',
        'nome': 'Chama da Semana',
        'descricao': 'Completou 7 dias seguidos (1 semana invicta).',
        'tipo': TipoAchievementChoices.STREAK,
        'icone': '🔥',
        'xp_necessario': 0,
        'tier': 'prata',
    },
    {
        'codigo': 'streak_14',
        'nome': 'Tocha Indomável',
        'descricao': 'Manteve 14 dias ininterruptos de estudo.',
        'tipo': TipoAchievementChoices.STREAK,
        'icone': '🪵',
        'xp_necessario': 0,
        'tier': 'prata',
    },
    {
        'codigo': 'streak_30',
        'nome': 'Fogueira Ancestral',
        'descricao': 'Manteve 30 dias de ofensiva inabalável (1 mês completo).',
        'tipo': TipoAchievementChoices.STREAK,
        'icone': '🌕',
        'xp_necessario': 0,
        'tier': 'ouro',
    },
    {
        'codigo': 'streak_100',
        'nome': 'Sol Eterno de Pindorama',
        'descricao': 'Alcançou a marca mítica de 100 dias consecutivos de ofensiva!',
        'tipo': TipoAchievementChoices.STREAK,
        'icone': '☀️',
        'xp_necessario': 0,
        'tier': 'diamante',
    },

    # ─── 3. BAÚS (COLETOR DE ARTEFATOS ANCESTRAIS) ──────────────────────────────
    {
        'codigo': 'chest_primeiro',
        'nome': 'O Despertar do Tesouro',
        'descricao': 'Abriu seu primeiro baú ancestral de capítulo na trilha.',
        'tipo': TipoAchievementChoices.BAU,
        'icone': '📦',
        'xp_necessario': 0,
        'tier': 'bronze',
    },
    {
        'codigo': 'chest_cinco',
        'nome': 'Guardião dos Amuletos',
        'descricao': 'Resgatou recompensas em 5 baús de capítulos distintos.',
        'tipo': TipoAchievementChoices.BAU,
        'icone': '🏺',
        'xp_necessario': 0,
        'tier': 'prata',
    },
    {
        'codigo': 'chest_dez',
        'nome': 'Arqueólogo da Floresta',
        'descricao': 'Coletou 10 baús de recompensas ancestrais.',
        'tipo': TipoAchievementChoices.BAU,
        'icone': '💎',
        'xp_necessario': 0,
        'tier': 'ouro',
    },
    {
        'codigo': 'chest_vinte',
        'nome': 'Grande Herdeiro de Pindorama',
        'descricao': 'Completou e abriu os baús de todos os 20 capítulos!',
        'tipo': TipoAchievementChoices.BAU,
        'icone': '🏆',
        'xp_necessario': 0,
        'tier': 'diamante',
    },

    # ─── 4. VOCABULÁRIO (MESTRIA DO LÉXICO) ────────────────────────────────────
    {
        'codigo': 'vocab_10',
        'nome': 'Primeiras Palavras',
        'descricao': 'Dominou 10 palavras em Tupi nos exercícios e práticas.',
        'tipo': TipoAchievementChoices.VOCABULARIO,
        'icone': '🗣️',
        'xp_necessario': 0,
        'tier': 'bronze',
    },
    {
        'codigo': 'vocab_25',
        'nome': 'Falante da Aldeia',
        'descricao': 'Dominou 25 palavras originárias em sua jornada.',
        'tipo': TipoAchievementChoices.VOCABULARIO,
        'icone': '📖',
        'xp_necessario': 0,
        'tier': 'prata',
    },
    {
        'codigo': 'vocab_50',
        'nome': 'Eloquência Ancestral',
        'descricao': 'Dominou 50 termos em Tupi com segurança.',
        'tipo': TipoAchievementChoices.VOCABULARIO,
        'icone': '📜',
        'xp_necessario': 0,
        'tier': 'ouro',
    },
    {
        'codigo': 'vocab_100',
        'nome': 'Dicionário Vivo',
        'descricao': 'Dominou mais de 100 termos fundamentais de Pindorama.',
        'tipo': TipoAchievementChoices.VOCABULARIO,
        'icone': '🗿',
        'xp_necessario': 0,
        'tier': 'diamante',
    },

    # ─── 5. CULTURAIS & CAPÍTULOS ──────────────────────────────────────────────
    {
        'codigo': 'cultural_primeira_licao',
        'nome': 'Primeira Flecha',
        'descricao': 'Concluiu com sucesso sua primeira lição na Trilha.',
        'tipo': TipoAchievementChoices.CULTURAL,
        'icone': '🎯',
        'xp_necessario': 0,
        'tier': 'bronze',
    },
    {
        'codigo': 'cultural_perfeicao',
        'nome': 'Mente Impecável',
        'descricao': 'Concluiu uma lição com 100% de precisão nos exercícios.',
        'tipo': TipoAchievementChoices.CULTURAL,
        'icone': '💎',
        'xp_necessario': 0,
        'tier': 'ouro',
    },
]

# Adiciona conquistas dos Capítulos 1 a 20 dinamicamente
for cap_i in range(1, 21):
    tier_name = 'bronze' if cap_i <= 5 else ('prata' if cap_i <= 10 else ('ouro' if cap_i <= 15 else 'diamante'))
    DEFAULT_ACHIEVEMENTS.append({
        'codigo': f'cultural_cap{cap_i}',
        'nome': f'Desbravador do Cap. {cap_i}',
        'descricao': f'Concluiu todas as lições do Capítulo {cap_i}.',
        'tipo': TipoAchievementChoices.CULTURAL,
        'icone': '🗺️' if cap_i % 2 == 1 else '🛖',
        'xp_necessario': 0,
        'tier': tier_name,
    })


def ensure_default_achievements():
    """Garante que todas as conquistas existam no banco — cacheado por 1h."""
    cache_key = 'tupilingo_achievements_seeded_v2'
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
                'xp_necessario': item.get('xp_necessario', 0),
            }
        )
    cache.set(cache_key, True, timeout=3600)


def check_and_grant_xp_achievements(user: UserProfile) -> list[Achievement]:
    """Verifica e concede medalhas de patamar de XP."""
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
        logger.info("Usuário %s desbloqueou medalha de XP: %s", user.id, ach.codigo)

    return unlocked


def check_and_grant_streak_achievements(user: UserProfile) -> list[Achievement]:
    """Verifica e concede medalhas de ofensiva contínua."""
    ensure_default_achievements()
    unlocked = []
    streak = user.streak_atual

    existing_codigos = set(user.achievements.values_list('codigo', flat=True))

    streak_milestones = [
        (3, 'streak_3'),
        (7, 'streak_7'),
        (14, 'streak_14'),
        (30, 'streak_30'),
        (100, 'streak_100'),
    ]

    for req, codigo in streak_milestones:
        if streak >= req and codigo not in existing_codigos:
            ach = Achievement.objects.filter(codigo=codigo).first()
            if ach:
                UserAchievement.objects.create(user=user, achievement=ach)
                unlocked.append(ach)
                existing_codigos.add(codigo)
                logger.info("Usuário %s desbloqueou medalha de Ofensiva: %s", user.id, codigo)

    return unlocked


def check_and_grant_chest_achievements(user: UserProfile) -> list[Achievement]:
    """Verifica e concede medalhas pela abertura de baús da trilha."""
    ensure_default_achievements()
    unlocked = []

    total_chests = UserChestReward.objects.filter(user=user).count()
    existing_codigos = set(user.achievements.values_list('codigo', flat=True))

    chest_milestones = [
        (1, 'chest_primeiro'),
        (5, 'chest_cinco'),
        (10, 'chest_dez'),
        (20, 'chest_vinte'),
    ]

    for req, codigo in chest_milestones:
        if total_chests >= req and codigo not in existing_codigos:
            ach = Achievement.objects.filter(codigo=codigo).first()
            if ach:
                UserAchievement.objects.create(user=user, achievement=ach)
                unlocked.append(ach)
                existing_codigos.add(codigo)
                logger.info("Usuário %s desbloqueou medalha de Baú: %s", user.id, codigo)

    return unlocked


def check_and_grant_lesson_achievements(user: UserProfile, licao: Licao, accuracy: float) -> list[Achievement]:
    """Verifica e concede conquistas relacionadas a lições e conclusão de capítulos."""
    ensure_default_achievements()
    unlocked = []

    existing_codigos = set(user.achievements.values_list('codigo', flat=True))

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

    # 3. Conclusão do Capítulo (1 a 20)
    capitulo = licao.capitulo
    cap_codigo = f'cultural_cap{capitulo.numero}'
    if cap_codigo not in existing_codigos:
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

    # Verifica também medalhas de XP e Streak
    unlocked.extend(check_and_grant_xp_achievements(user))
    unlocked.extend(check_and_grant_streak_achievements(user))

    return unlocked


def get_all_achievements_with_status(user: UserProfile) -> tuple[list[dict], list[dict]]:
    """
    Retorna duas listas enriquecidas com categoria, tier metálico e progresso:
    1. Conquistadas: lista de dicts com data e tier.
    2. Bloqueadas: lista de dicts com requisitos e progresso parcial.
    """
    ensure_default_achievements()

    user_achievements = {
        ua.achievement_id: ua.conquistada_em
        for ua in UserAchievement.objects.filter(user=user).select_related('achievement')
    }

    tier_map = {item['codigo']: item.get('tier', 'bronze') for item in DEFAULT_ACHIEVEMENTS}

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
            'tier': tier_map.get(ach.codigo, 'bronze'),
            'desbloqueada': is_unlocked,
        }
        if is_unlocked:
            item['conquistada_em'] = user_achievements[ach.id].isoformat()
            unlocked.append(item)
        else:
            item['progresso_xp'] = user.xp_total
            locked.append(item)

    return unlocked, locked
