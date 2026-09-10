"""
Views da API de Trilha — Jornada Histórica do TupiLingo.

Fornece todos os dados que o Flutter precisa para renderizar:
- O mapa interativo (variantes, capítulos, lições com posição e estado).
- O player de lições (StoryBlocks, exercícios, vocabulário).
- A validação de exercícios com tolerância a erros (unaccent + levenshtein).
"""

import json
import logging

from django.db import transaction
from django.db.models import F
from django.http import JsonResponse
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET, require_POST
from django_ratelimit.decorators import ratelimit
from users.decorators import supabase_auth_required
from users.models import UserLesson, UserProfile
from users.services.validation_service import (
    ValidationResult,
    calcular_xp_exercicio,
    validar_lista_lacunas,
)

from .models import (
    Capitulo,
    Exercicio,
    ExercicioAssociacao,
    ExercicioCompletar,
    ExercicioEscolha,
    Licao,
    TrilhaHistorica,
    VarianteTupi,
)

logger = logging.getLogger("trilha.views")


def _get_user(request) -> tuple:
    """Resolve o UserProfile a partir do JWT. Retorna (user, error_response)."""
    supabase_uid = request.user_data.get("sub")
    if not supabase_uid:
        return None, JsonResponse({"error": "UNAUTHORIZED"}, status=401)
    user = UserProfile.objects.filter(supabase_uid=supabase_uid).first()
    if not user:
        return None, JsonResponse({"error": "Usuário não encontrado."}, status=404)
    return user, None


def _get_or_create_user_lesson(user: UserProfile, licao: Licao) -> UserLesson:
    """Garante que o registro de progresso da lição existe para o usuário com status inicial coerente."""
    from users.services.progress_service import ProgressService
    status_default = 'disponivel' if ProgressService.is_lesson_accessible(user, licao) else 'bloqueada'
    obj, _ = UserLesson.objects.get_or_create(
        usuario=user,
        licao=licao,
        defaults={'status': status_default},
    )
    return obj


def _is_celery_broker_reachable() -> bool:
    """Verifica de forma ultra-rápida (<=150ms) se o broker Redis do Celery está acessível."""
    import socket
    from urllib.parse import urlparse

    from django.conf import settings
    broker_url = getattr(settings, 'CELERY_BROKER_URL', '')
    if not broker_url or getattr(settings, 'CELERY_TASK_ALWAYS_EAGER', False):
        return False
    try:
        parsed = urlparse(broker_url)
        host = parsed.hostname or '127.0.0.1'
        port = parsed.port or 6379
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(0.15)
        res = s.connect_ex((host, port))
        s.close()
        return res == 0
    except Exception:
        return False


# ─── Variantes ────────────────────────────────────────────────────────────────

@csrf_exempt
@ratelimit(key='ip', rate='30/m', block=True)
@supabase_auth_required
@require_GET
def listar_variantes(request):
    """Retorna todas as VariantesTupi ativas com status do usuário."""
    user, err = _get_user(request)
    if err:
        return err

    variantes = VarianteTupi.objects.filter(ativo=True).order_by('ordem')
    data = []
    for v in variantes:
        ja_testou = v.test_attempts.filter(user=user).exists()
        data.append({
            'id': v.id,
            'nome': v.nome,
            'codigo': v.codigo,
            'descricao': v.descricao,
            'icone': v.icone,
            'e_variante_ativa': user.variante_ativa_id == v.id,
            'ja_testou': ja_testou,
        })

    return JsonResponse({'success': True, 'variantes': data})


# ─── Mapa / Capítulos ─────────────────────────────────────────────────────────

@csrf_exempt
@ratelimit(key='ip', rate='30/m', block=True)
@supabase_auth_required
@require_GET
def listar_capitulos_mapa(request, variante_id: int):
    """Retorna a estrutura completa do mapa interativo para uma variante."""
    user, err = _get_user(request)
    if err:
        return err

    variante = VarianteTupi.objects.filter(id=variante_id, ativo=True).first()
    if not variante:
        return JsonResponse({'error': 'Variante não encontrada.'}, status=404)

    try:
        trilha = variante.trilha
    except TrilhaHistorica.DoesNotExist:
        return JsonResponse({'error': 'Esta variante ainda não possui uma Trilha cadastrada.'}, status=404)

    # Se a trilha não foi marcada explicitamente como publicada, mas possui conteúdo, publica-a
    if not trilha.publicada:
        if trilha.capitulos.exists():
            trilha.publicada = True
            trilha.save(update_fields=['publicada'])
        else:
            return JsonResponse({'error': 'Trilha não está publicada.'}, status=404)

    # Garante que capítulos narrativos e lições existentes da trilha fiquem visíveis no mapa
    capitulos_base_qs = trilha.capitulos.filter(numero__lt=900)
    if not capitulos_base_qs.filter(publicado=True).exists() and capitulos_base_qs.exists():
        capitulos_base_qs.update(publicado=True)

    if not Licao.objects.filter(capitulo__trilha=trilha, publicada=True).exists() and Licao.objects.filter(capitulo__trilha=trilha).exists():
        Licao.objects.filter(capitulo__trilha=trilha).update(publicada=True)

    # PERF: ProgressService resolve a árvore em O(1) queries com prefetch e estado canônico
    from users.services.progress_service import ProgressService
    trail_data = ProgressService.get_trail_structure_with_progression(user, variante)
    if not trail_data.get('success', False):
        return JsonResponse(trail_data, status=trail_data.get('status', 400))

    return JsonResponse(trail_data)


@csrf_exempt
@ratelimit(key='ip', rate='30/m', block=True)
@supabase_auth_required
@require_GET
def listar_regioes_mapa(request):
    """
    Retorna as regiões históricas (Aldeias) dinâmicas, integradas com o
    progresso real das lições e capítulos do usuário na trilha.
    """
    user, err = _get_user(request)
    if err:
        return err

    from nivelamento.models import UserVarianteLevel
    from users.services.progress_service import ProgressService

    variante = user.variante_ativa
    if not variante:
        variante = VarianteTupi.objects.filter(ativo=True).order_by('ordem').first()

    trail_data = ProgressService.get_trail_structure_with_progression(user, variante) if variante else {}
    capitulos = trail_data.get('capitulos', [])

    regioes_template = [
        {
            'id': 1,
            'name': 'Costa dos Tupinambás (Ubatuba / Guanabara)',
            'indigenous_nation': 'Tupinambá',
            'historical_period': 'Século XVI - Confederação dos Tamoios',
            'relative_x': 0.72,
            'relative_y': 0.68,
            'radius': 26.0,
            'cultural_summary': (
                'Coração da Confederação dos Tamoios liderada por Cunhambebe. Famosos navegadores de canoas '
                'e guerreiros da floresta atlântica, falantes do Tupi clássico registrado por Jean de Léry e Hans Staden.'
            ),
            'vocabulary_highlights': ['Iperoig', 'Tamoio', 'Karai', 'Tupã', 'Maracá'],
            'required_level': 1,
        },
        {
            'id': 2,
            'name': 'Território Carijó (Litoral Sul / Ilha de SC)',
            'indigenous_nation': 'Carijó (Guarani)',
            'historical_period': 'Século XVI - Trilha do Peabiru',
            'relative_x': 0.60,
            'relative_y': 0.84,
            'radius': 24.0,
            'cultural_summary': (
                'Povo pacífico de navegadores e guardiões do mítico caminho sagrado do Peabiru, que ligava o Atlântico aos Andes. '
                'Grandes ceramistas e agricultores de mandioca e milho.'
            ),
            'vocabulary_highlights': ['Peabiru', 'Meiembipe', 'Mandi\'oka', 'Avaxi'],
            'required_level': 2,
        },
        {
            'id': 3,
            'name': 'Alto Xingu & Florestas Centrais',
            'indigenous_nation': 'Kamaiurá / Aweti (Tupi)',
            'historical_period': 'Tradição Milenar das Aldeias Circulares',
            'relative_x': 0.52,
            'relative_y': 0.48,
            'radius': 25.0,
            'cultural_summary': (
                'Complexo cultural do Xingu com aldeias circulares monumentais, rituais sagrados do Kuarup e luta Huka-Huka. '
                'Preservam a língua de tronco Tupi viva em sua forma mais rica e expressiva.'
            ),
            'vocabulary_highlights': ['Kuarup', 'Huka-huka', 'Jawari', 'Moitará'],
            'required_level': 3,
        },
        {
            'id': 4,
            'name': 'Amazônia Nheengatu (Bacia do Rio Negro)',
            'indigenous_nation': 'Povos do Rio Negro (Nheengatu)',
            'historical_period': 'Século XVII aos dias atuais',
            'relative_x': 0.32,
            'relative_y': 0.22,
            'radius': 26.0,
            'cultural_summary': (
                'Berço da Língua Geral Amazônica (Nheengatu), derivada do Tupinambá e reconhecida como patrimônio linguístico vivo. '
                'Riquíssima cosmologia sobre Jurupari e os rios de água preta.'
            ),
            'vocabulary_highlights': ['Yande', 'Paranã', 'Yara', 'Jurupari', 'Puraque'],
            'required_level': 4,
        },
        {
            'id': 5,
            'name': 'Costa dos Tupiniquins (Porto Seguro)',
            'indigenous_nation': 'Tupiniquim',
            'historical_period': '1500 - Primeiro Contato',
            'relative_x': 0.84,
            'relative_y': 0.56,
            'radius': 23.0,
            'cultural_summary': (
                'Habitantes da costa sul da Bahia, foram os primeiros anfitriões dos navegadores portugueses em 1500. '
                'Exímios coletores de moluscos e conhecedores dos segredos das marés.'
            ),
            'vocabulary_highlights': ['Pindorama', 'Mbya', 'Itaparica', 'Pirá'],
            'required_level': 5,
        },
    ]

    regioes_finais = []
    lvl_obj = UserVarianteLevel.objects.filter(user=user, variante=variante).first() if variante else None
    user_nivel = lvl_obj.nivel if lvl_obj else 1

    for idx, reg in enumerate(regioes_template):
        if idx < len(capitulos):
            cap = capitulos[idx]
            licoes = cap.get('licoes', [])
            total_licoes = len(licoes) if licoes else 5
            completadas = sum(1 for l in licoes if l.get('status') == 'concluida')
            is_unlocked = (idx == 0) or (cap.get('unlocked', False)) or (user_nivel >= reg['required_level'])
        else:
            total_licoes = 5
            completadas = 0
            is_unlocked = user_nivel >= reg['required_level']

        reg_data = dict(reg)
        reg_data['lessons_count'] = total_licoes
        reg_data['completed_lessons_count'] = completadas
        reg_data['is_unlocked'] = is_unlocked
        regioes_finais.append(reg_data)

    return JsonResponse({'success': True, 'regioes': regioes_finais})


# ─── Detalhe da Lição ─────────────────────────────────────────────────────────

@csrf_exempt
@ratelimit(key='ip', rate='30/m', block=True)
@supabase_auth_required
@require_GET
def detalhe_licao(request, licao_id: int):
    """Retorna o conteúdo completo de uma Lição para o LessonPlayer do Flutter."""
    user, err = _get_user(request)
    if err:
        return err

    licao = Licao.objects.select_related('capitulo__trilha__variante').filter(
        id=licao_id, publicada=True
    ).first()
    if not licao:
        return JsonResponse({'error': 'Lição não encontrada.'}, status=404)

    from users.decorators import is_request_admin
    from users.services.progress_service import ProgressService
    user_lesson = _get_or_create_user_lesson(user, licao)
    is_admin = is_request_admin(request)

    # Sincroniza a variante ativa do usuário com a variante da lição acessada
    variante_licao = licao.capitulo.trilha.variante
    if user.variante_ativa_id != variante_licao.id:
        user.variante_ativa = variante_licao
        user.save(update_fields=['variante_ativa', 'updated_at'])

    # SEC-005: Validação server-side estrita de progressão sequencial
    if not is_admin and not ProgressService.is_lesson_accessible(user, licao):
        return JsonResponse({
            'error': 'Esta lição está bloqueada na sua jornada. Conclua as anteriores primeiro.',
            'code': 'LESSON_LOCKED',
            'licao_id': licao.id,
        }, status=403)

    # Se a lição for acessível na jornada do usuário, promove o status para disponível
    if user_lesson.status == 'bloqueada':
        user_lesson.status = 'disponivel'
        user_lesson.save(update_fields=['status'])

    if user_lesson.status == 'disponivel':
        user_lesson.status = 'em_andamento'
        user_lesson.iniciada_em = timezone.now()
        user_lesson.save(update_fields=['status', 'iniciada_em'])

    story_blocks = []
    for sb in licao.story_blocks.order_by('ordem'):
        story_blocks.append({
            'id': sb.id, 'tipo': sb.tipo, 'titulo': sb.titulo,
            'conteudo': sb.conteudo, 'midia': sb.midia.url if sb.midia else None,
            'ordem': sb.ordem, 'extra': sb.extra, 'xp_bonus': sb.xp_bonus,
        })

    exercicios = []
    qs_unificado = Exercicio.objects.filter(licao=licao).order_by('ordem')
    if qs_unificado.exists():
        for ex in qs_unificado:
            item_data = {
                'id': ex.id,
                'tipo': ex.tipo,
                'enunciado': ex.enunciado,
                'explicacao': ex.explicacao,
                'dificuldade': ex.dificuldade,
                'pontos_base': ex.pontos_base,
                'ordem': ex.ordem,
                'midia': ex.midia.url if ex.midia else None,
            }
            if ex.tipo == 'escolha_multipla':
                item_data['opcoes'] = ex.opcoes or []
            elif ex.tipo == 'completar':
                item_data['texto_com_lacunas'] = ex.texto_com_lacunas or ''
                item_data['tolerancia_levenshtein'] = ex.tolerancia_levenshtein
            elif ex.tipo == 'associacao':
                item_data['coluna_esquerda'] = ex.coluna_esquerda or []
                item_data['coluna_direita'] = ex.coluna_direita or []
            exercicios.append(item_data)
    else:
        for ex in ExercicioEscolha.objects.filter(licao=licao).order_by('ordem'):
            exercicios.append({
                'id': ex.id, 'tipo': 'escolha_multipla', 'enunciado': ex.enunciado,
                'explicacao': ex.explicacao, 'dificuldade': ex.dificuldade,
                'pontos_base': ex.pontos_base, 'ordem': ex.ordem,
                'midia': ex.midia.url if ex.midia else None,
                'opcoes': ex.opcoes,
            })
        for ex in ExercicioCompletar.objects.filter(licao=licao).order_by('ordem'):
            exercicios.append({
                'id': ex.id, 'tipo': 'completar', 'enunciado': ex.enunciado,
                'explicacao': ex.explicacao, 'dificuldade': ex.dificuldade,
                'pontos_base': ex.pontos_base, 'ordem': ex.ordem,
                'midia': ex.midia.url if ex.midia else None,
                'texto_com_lacunas': ex.texto_com_lacunas,
                'tolerancia_levenshtein': ex.tolerancia_levenshtein,
            })
        for ex in ExercicioAssociacao.objects.filter(licao=licao).order_by('ordem'):
            exercicios.append({
                'id': ex.id, 'tipo': 'associacao', 'enunciado': ex.enunciado,
                'explicacao': ex.explicacao, 'dificuldade': ex.dificuldade,
                'pontos_base': ex.pontos_base, 'ordem': ex.ordem,
                'midia': ex.midia.url if ex.midia else None,
                'coluna_esquerda': ex.coluna_esquerda, 'coluna_direita': ex.coluna_direita,
            })
        exercicios.sort(key=lambda e: e['ordem'])

    vocabulario = []
    for item in licao.vocabulary.order_by('ordem'):
        vocabulario.append({
            'id': item.id, 'palavra_tupi': item.palavra_tupi, 'traducao_pt': item.traducao_pt,
            'transliteracao': item.transliteracao, 'audio': item.audio.url if item.audio else None,
            'exemplo_tupi': item.exemplo_tupi, 'exemplo_pt': item.exemplo_pt,
        })

    return JsonResponse({
        'success': True,
        'licao': {
            'id': licao.id, 'titulo': licao.titulo, 'descricao': licao.descricao, 'xp_base': licao.xp_base,
            'capitulo': {'id': licao.capitulo.id, 'titulo': licao.capitulo.titulo},
        },
        'user_progress': {'status': user_lesson.status, 'completion_percentage': user_lesson.completion_percentage},
        'story_blocks': story_blocks,
        'exercicios': exercicios,
        'vocabulario': vocabulario,
    })


def _recalibrar_nivel(user: UserProfile, variante: VarianteTupi) -> int:
    """
    Recalibra o nível adaptativo do usuário com base no desempenho real
    nas últimas 3 lições concluídas na variante informada.
    Anti-manipulação: calculado exclusivamente no backend com lock pessimista (SCALE-002).
    """
    from nivelamento.models import UserVarianteLevel

    with transaction.atomic():
        level_obj, _ = UserVarianteLevel.objects.select_for_update().get_or_create(
            user=user,
            variante=variante,
            defaults={'nivel': 1}
        )

        ultimas_licoes = list(
            UserLesson.objects.filter(
                usuario=user,
                licao__capitulo__trilha__variante=variante,
                status='concluida',
            ).order_by('-concluida_em')[:3]
        )

        if len(ultimas_licoes) == 3:
            if all(ul.accuracy >= 0.85 for ul in ultimas_licoes):
                if level_obj.nivel < 10:
                    UserVarianteLevel.objects.filter(pk=level_obj.pk).update(
                        nivel=F('nivel') + 1
                    )
                    level_obj.refresh_from_db(fields=['nivel'])
                    logger.info("Usuário %s subiu para nível %d em %s", user.id, level_obj.nivel, variante.nome)
            elif all(ul.accuracy <= 0.40 for ul in ultimas_licoes):
                if level_obj.nivel > 1:
                    UserVarianteLevel.objects.filter(pk=level_obj.pk).update(
                        nivel=F('nivel') - 1
                    )
                    level_obj.refresh_from_db(fields=['nivel'])
                    logger.info("Usuário %s desceu para nível %d em %s", user.id, level_obj.nivel, variante.nome)

    return level_obj.nivel


def _desbloquear_proxima_licao(user: UserProfile, licao: Licao) -> Licao | None:
    """
    Desbloqueia a próxima lição na sequência da trilha.
    1. Procura a próxima lição publicada no mesmo capítulo (numero > licao.numero).
    2. Se não houver, procura o próximo capítulo publicado e sua primeira lição.
    3. Marca a UserLesson encontrada como 'disponivel'.
    Retorna a Licao desbloqueada ou None.
    """
    # 1. Próxima lição no mesmo capítulo
    prox_licao = Licao.objects.filter(
        capitulo=licao.capitulo,
        numero__gt=licao.numero,
        publicada=True
    ).order_by('numero').first()

    # 2. Se não achou, procura no próximo capítulo da mesma trilha
    if not prox_licao:
        prox_capitulo = Capitulo.objects.filter(
            trilha=licao.capitulo.trilha,
            numero__gt=licao.capitulo.numero,
            publicado=True
        ).order_by('numero').first()

        if prox_capitulo:
            prox_licao = Licao.objects.filter(
                capitulo=prox_capitulo,
                publicada=True
            ).order_by('numero').first()

    # 3. Desbloqueia para o usuário
    if prox_licao:
        ul, created = UserLesson.objects.get_or_create(
            usuario=user,
            licao=prox_licao,
            defaults={'status': 'disponivel'}
        )
        if ul.status == 'bloqueada':
            ul.status = 'disponivel'
            ul.save(update_fields=['status'])
        logger.info("Próxima lição desbloqueada para user %s: licao_id=%d (%s)", user.id, prox_licao.id, prox_licao.titulo)

    return prox_licao


# ─── Concluir Lição ───────────────────────────────────────────────────────────

@csrf_exempt
@ratelimit(key='ip', rate='20/m', block=True)
@supabase_auth_required
@require_POST
def concluir_licao(request, licao_id: int):
    """Marca a lição como concluída, calcula o XP e atualiza o progresso."""
    user, err = _get_user(request)
    if err:
        return err

    licao = Licao.objects.select_related('capitulo__trilha__variante').filter(id=licao_id, publicada=True).first()
    if not licao:
        return JsonResponse({'error': 'Lição não encontrada.'}, status=404)

    try:
        body = json.loads(request.body)
    except (json.JSONDecodeError, ValueError):
        return JsonResponse({'error': 'JSON inválido.'}, status=400)

    acertos = int(body.get('acertos', 0))
    # SECURITY-004: total_exercicios vem do banco, não do payload do cliente,
    # para evitar manipulação de XP via body arbitrário.
    total_unificado = Exercicio.objects.filter(licao=licao).count()
    if total_unificado > 0:
        total = total_unificado
    else:
        total_escolha = ExercicioEscolha.objects.filter(licao=licao).count()
        total_completar = ExercicioCompletar.objects.filter(licao=licao).count()
        total_associacao = ExercicioAssociacao.objects.filter(licao=licao).count()
        total = total_escolha + total_completar + total_associacao or 1  # Evita divisão por zero

    # bonus_exploracao ainda aceito do payload (XP de StoryBlocks lidos), mas com cap razoável
    bonus_exploracao = min(int(body.get('bonus_exploracao_xp', 0)), 100)

    user_lesson, _ = UserLesson.objects.get_or_create(usuario=user, licao=licao)

    from nivelamento.models import UserVarianteLevel
    from users.services.progress_service import ProgressService
    from users.services.streak_service import StreakService

    # Sincroniza a variante ativa do usuário com a variante da lição concluída
    variante_licao = licao.capitulo.trilha.variante
    if user.variante_ativa_id != variante_licao.id:
        user.variante_ativa = variante_licao
        user.save(update_fields=['variante_ativa', 'updated_at'])

    # SEC-003: Idempotência com suporte a revisão — previne farm de XP infinito mas
    # garante desbloqueio da próxima lição e registro de estudo diário (streak).
    if user_lesson.status == 'concluida':
        with transaction.atomic():
            prox_licao = ProgressService.unlock_next_lesson(user, licao)
            tempo_gasto = int(body.get('tempo_segundos', 60))
            StreakService.register_study_activity(
                user=user,
                xp_ganho=0,
                tempo_segundos=tempo_gasto,
                is_lesson_completed=True,
                exercicios_respondidos=total,
                exercicios_corretos=acertos,
            )
            user.refresh_from_db(fields=['xp_total', 'streak_atual', 'maior_streak'])
            lvl_obj = UserVarianteLevel.objects.filter(user=user, variante=licao.capitulo.trilha.variante).first()
            ProgressService.invalidate_user_trail_cache(user.id, licao.capitulo.trilha.variante_id)

        return JsonResponse({
            'success': True,
            'already_completed': True,
            'variante_id': variante_licao.id,
            'variante_nome': variante_licao.nome,
            'variante_codigo': variante_licao.codigo,
            'earned_xp': 0,
            'xp_total': user.xp_total,
            'streak_atual': user.streak_atual,
            'dias_ofensiva': user.streak_atual,
            'accuracy': user_lesson.accuracy,
            'total_exercicios_servidor': total,
            'nivel_atual': lvl_obj.nivel if lvl_obj else 1,
            'novas_conquistas': [],
            'proxima_licao_id': prox_licao.id if prox_licao else None,
            'proxima_licao_desbloqueada': prox_licao is not None,
            'message': 'Lição concluída! Ofensiva diária mantida.',
        })

    # SEC-003: Derivar primeira_tentativa exclusivamente do estado do banco
    primeira_tentativa = (
        user_lesson.status in ['disponivel', 'em_andamento', 'bloqueada']
        and (user_lesson.accuracy == 0.0 or user_lesson.accuracy is None)
    )

    # Clamp acertos ao total real do servidor
    acertos = min(acertos, total)
    accuracy = acertos / total
    status_ex = (
        ValidationResult.CORRETO if accuracy == 1.0 else
        ValidationResult.QUASE_CERTO if accuracy >= 0.7 else
        ValidationResult.ERRADO
    )

    earned_xp = calcular_xp_exercicio(
        pontos_base=licao.xp_base,
        primeira_tentativa=primeira_tentativa,
        resultado_status=status_ex,
        bonus_exploracao=bonus_exploracao,
    )

    with transaction.atomic():
        user_lesson.status = 'concluida'
        user_lesson.completion_percentage = 100.0
        user_lesson.accuracy = accuracy
        user_lesson.earned_xp = earned_xp
        user_lesson.concluida_em = timezone.now()
        user_lesson.save()

        # Desbloqueia automaticamente a próxima lição da jornada
        prox_licao = ProgressService.unlock_next_lesson(user, licao)

        # Registra no log de atividade diária e atualiza streak e XP de forma atômica
        tempo_gasto = int(body.get('tempo_segundos', 60))
        StreakService.register_study_activity(
            user=user,
            xp_ganho=earned_xp,
            tempo_segundos=tempo_gasto,
            is_lesson_completed=True,
            exercicios_respondidos=total,
            exercicios_corretos=acertos,
        )
        user.refresh_from_db(fields=['xp_total', 'streak_atual', 'maior_streak'])
        ProgressService.invalidate_user_trail_cache(user.id, licao.capitulo.trilha.variante_id)

    # Nível atual para retorno imediato (sem bloquear worker Gunicorn)
    lvl_obj = UserVarianteLevel.objects.filter(user=user, variante=licao.capitulo.trilha.variante).first()
    novo_nivel = lvl_obj.nivel if lvl_obj else 1

    # SCALE-001: Despacha para Celery se o broker estiver ativo; caso contrário, executa síncrono imediatamente
    novas_ach = []
    dispatched_celery = False
    if _is_celery_broker_reachable():
        try:
            from users.tasks import processar_pos_licao
            processar_pos_licao.apply_async(args=[user.pk, licao.pk, accuracy], connect_timeout=1.0, retry=False)
            dispatched_celery = True
        except Exception as exc:
            logger.warning("Falha ao enfileirar task Celery, executando fallback síncrono: %s", exc)

    if not dispatched_celery:
        try:
            variante = licao.capitulo.trilha.variante
            novo_nivel = _recalibrar_nivel(user, variante)
            from users.services.achievement_service import (
                check_and_grant_lesson_achievements,
                check_and_grant_xp_achievements,
            )
            novas_xp_ach = check_and_grant_xp_achievements(user)
            novas_lesson_ach = check_and_grant_lesson_achievements(user, licao, accuracy)
            novas_ach = [
                {'codigo': a.codigo, 'nome': a.nome, 'icone': a.icone, 'descricao': a.descricao}
                for a in (novas_xp_ach + novas_lesson_ach)
            ]
        except Exception as inner_exc:
            logger.error("Erro no fallback síncrono pós-lição: %s", inner_exc)

    return JsonResponse({
        'success': True,
        'variante_id': variante_licao.id,
        'variante_nome': variante_licao.nome,
        'variante_codigo': variante_licao.codigo,
        'earned_xp': earned_xp,
        'xp_total': user.xp_total,
        'streak_atual': user.streak_atual,
        'dias_ofensiva': user.streak_atual,
        'accuracy': accuracy,
        'total_exercicios_servidor': total,
        'nivel_atual': novo_nivel,
        'novas_conquistas': novas_ach,
        'proxima_licao_id': prox_licao.id if prox_licao else None,
        'proxima_licao_desbloqueada': prox_licao is not None,
        'message': f'Lição concluída! Você ganhou {earned_xp} XP. 🎉',
    })


# ─── Coletar Baú Cultural ────────────────────────────────────────────────────

@csrf_exempt
@ratelimit(key='ip', rate='20/m', block=True)
@supabase_auth_required
@require_POST
def coletar_bau(request, capitulo_id: int, milestone_index: int = 1):
    """Permite ao usuário coletar as recompensas do Baú Cultural de um Capítulo."""
    user, err = _get_user(request)
    if err:
        return err

    from users.services.progress_service import ProgressService
    result = ProgressService.collect_chest(user, capitulo_id, milestone_index)
    status_code = result.get('status', 200) if not result.get('success', False) else 200
    return JsonResponse(result, status=status_code)


# ─── Verificar Resposta ───────────────────────────────────────────────────────

@csrf_exempt
@ratelimit(key='ip', rate='60/m', block=True)
@supabase_auth_required
@require_POST
def verificar_resposta(request):
    """
    Verifica a resposta de um exercício usando tolerância a erros via PostgreSQL.

    Payload:
    {
        "exercicio_id": int,
        "tipo": "completar" | "escolha_multipla" | "associacao",
        "respostas": ["resposta1"],        // para completar (uma por lacuna)
        "resposta_indice": int,            // para múltipla escolha
        "associacoes": {"0": "1"},         // para associação
        "primeira_tentativa": bool
    }
    """
    user, err = _get_user(request)
    if err:
        return err

    try:
        body = json.loads(request.body)
    except (json.JSONDecodeError, ValueError):
        return JsonResponse({'error': 'JSON inválido.'}, status=400)

    tipo = body.get('tipo')
    exercicio_id = body.get('exercicio_id')
    primeira_tentativa = bool(body.get('primeira_tentativa', True))

    if not tipo or not exercicio_id:
        return JsonResponse({'error': 'Campos tipo e exercicio_id são obrigatórios.'}, status=400)

    # 1. Tenta buscar no modelo unificado Exercicio (com cache em memória para resposta instantânea)
    from django.core.cache import cache
    ex_cache_key = f"exercicio_unificado_{exercicio_id}"
    ex_unificado = cache.get(ex_cache_key)
    if ex_unificado is None:
        ex_unificado = Exercicio.objects.filter(id=exercicio_id).first()
        if ex_unificado:
            cache.set(ex_cache_key, ex_unificado, timeout=600)

    if ex_unificado:
        if ex_unificado.tipo == 'escolha_multipla':
            indice = body.get('resposta_indice')
            correto = indice == ex_unificado.resposta_correta
            status = ValidationResult.CORRETO if correto else ValidationResult.ERRADO
            xp = calcular_xp_exercicio(ex_unificado.pontos_base, primeira_tentativa, status)
            opcoes = ex_unificado.opcoes or []
            resp_str = opcoes[ex_unificado.resposta_correta] if (0 <= (ex_unificado.resposta_correta or -1) < len(opcoes)) else str((ex_unificado.resposta_correta or 0) + 1)
            msg = 'Correto! 🎉' if correto else f'Incorreto. A resposta certa era: "{resp_str}".'
            if ex_unificado.explicacao:
                msg += f' — {ex_unificado.explicacao}'
            return JsonResponse({
                'success': True, 'status': status, 'correto': correto,
                'resposta_correta_indice': ex_unificado.resposta_correta, 'explicacao': ex_unificado.explicacao, 'earned_xp': xp,
                'mensagem': msg, 'message': msg,
            })
        elif ex_unificado.tipo == 'completar':
            respostas_usuario = body.get('respostas', [])
            resultado = validar_lista_lacunas(
                respostas_usuario=respostas_usuario,
                respostas_corretas=ex_unificado.respostas_corretas or [],
                tolerancia=ex_unificado.tolerancia_levenshtein,
            )
            status = (
                ValidationResult.CORRETO if resultado['tudo_correto'] else
                ValidationResult.QUASE_CERTO if resultado['algum_quase'] else
                ValidationResult.ERRADO
            )
            xp = calcular_xp_exercicio(ex_unificado.pontos_base, primeira_tentativa, status)
            if status == ValidationResult.CORRETO:
                msg = 'Correto! 🎉'
            elif status == ValidationResult.QUASE_CERTO:
                msg = resultado['resultados'][0].get('mensagem', 'Quase lá!') if resultado['resultados'] else 'Quase lá!'
            else:
                resp_esperada = ', '.join(ex_unificado.respostas_corretas or [])
                msg = f'Incorreto. A resposta certa era: "{resp_esperada}".'
            if ex_unificado.explicacao:
                msg += f' — {ex_unificado.explicacao}'
            return JsonResponse({
                'success': True, 'status': status,
                'resultados_lacunas': resultado['resultados'],
                'acertos': resultado['acertos'], 'total': resultado['total'],
                'explicacao': ex_unificado.explicacao, 'earned_xp': xp,
                'mensagem': msg, 'message': msg,
            })
        elif ex_unificado.tipo == 'associacao':
            assoc_usuario = body.get('associacoes', {})
            correto = all(
                str(assoc_usuario.get(str(k))) == str(v)
                for k, v in (ex_unificado.associacao_correta or {}).items()
            )
            status = ValidationResult.CORRETO if correto else ValidationResult.ERRADO
            xp = calcular_xp_exercicio(ex_unificado.pontos_base, primeira_tentativa, status)
            msg = 'Correto! 🎉' if correto else 'Associação incorreta.'
            if ex_unificado.explicacao:
                msg += f' — {ex_unificado.explicacao}'
            return JsonResponse({
                'success': True, 'status': status, 'correto': correto,
                'associacao_correta': ex_unificado.associacao_correta, 'explicacao': ex_unificado.explicacao, 'earned_xp': xp,
                'mensagem': msg, 'message': msg,
            })

    # 2. Fallback para modelos legados
    if tipo == 'escolha_multipla':
        ex = ExercicioEscolha.objects.filter(id=exercicio_id).first()
        if not ex:
            return JsonResponse({'error': 'Exercício não encontrado.'}, status=404)
        indice = body.get('resposta_indice')
        correto = indice == ex.resposta_correta
        status = ValidationResult.CORRETO if correto else ValidationResult.ERRADO
        xp = calcular_xp_exercicio(ex.pontos_base, primeira_tentativa, status)
        opcoes = ex.opcoes or []
        resp_str = opcoes[ex.resposta_correta] if (0 <= (ex.resposta_correta or -1) < len(opcoes)) else str((ex.resposta_correta or 0) + 1)
        msg = 'Correto! 🎉' if correto else f'Incorreto. A resposta certa era: "{resp_str}".'
        if ex.explicacao:
            msg += f' — {ex.explicacao}'
        return JsonResponse({
            'success': True, 'status': status, 'correto': correto,
            'resposta_correta_indice': ex.resposta_correta, 'explicacao': ex.explicacao, 'earned_xp': xp,
            'mensagem': msg, 'message': msg,
        })

    if tipo == 'completar':
        ex = ExercicioCompletar.objects.filter(id=exercicio_id).first()
        if not ex:
            return JsonResponse({'error': 'Exercício não encontrado.'}, status=404)
        respostas_usuario = body.get('respostas', [])
        resultado = validar_lista_lacunas(
            respostas_usuario=respostas_usuario,
            respostas_corretas=ex.respostas_corretas,
            tolerancia=ex.tolerancia_levenshtein,
        )
        status = (
            ValidationResult.CORRETO if resultado['tudo_correto'] else
            ValidationResult.QUASE_CERTO if resultado['algum_quase'] else
            ValidationResult.ERRADO
        )
        xp = calcular_xp_exercicio(ex.pontos_base, primeira_tentativa, status)
        if status == ValidationResult.CORRETO:
            msg = 'Correto! 🎉'
        elif status == ValidationResult.QUASE_CERTO:
            msg = resultado['resultados'][0].get('mensagem', 'Quase lá!') if resultado['resultados'] else 'Quase lá!'
        else:
            resp_esperada = ', '.join(ex.respostas_corretas or [])
            msg = f'Incorreto. A resposta certa era: "{resp_esperada}".'
        if ex.explicacao:
            msg += f' — {ex.explicacao}'
        return JsonResponse({
            'success': True, 'status': status,
            'resultados_lacunas': resultado['resultados'],
            'acertos': resultado['acertos'], 'total': resultado['total'],
            'explicacao': ex.explicacao, 'earned_xp': xp,
            'mensagem': msg, 'message': msg,
        })

    if tipo == 'associacao':
        ex = ExercicioAssociacao.objects.filter(id=exercicio_id).first()
        if not ex:
            return JsonResponse({'error': 'Exercício não encontrado.'}, status=404)
        assoc_usuario = body.get('associacoes', {})
        correto = all(
            str(assoc_usuario.get(str(k))) == str(v)
            for k, v in ex.associacao_correta.items()
        )
        status = ValidationResult.CORRETO if correto else ValidationResult.ERRADO
        xp = calcular_xp_exercicio(ex.pontos_base, primeira_tentativa, status)
        msg = 'Correto! 🎉' if correto else 'Associação incorreta.'
        if ex.explicacao:
            msg += f' — {ex.explicacao}'
        return JsonResponse({
            'success': True, 'status': status, 'correto': correto,
            'associacao_correta': ex.associacao_correta, 'explicacao': ex.explicacao, 'earned_xp': xp,
            'mensagem': msg, 'message': msg,
        })

    return JsonResponse({'error': f"Tipo '{tipo}' não reconhecido."}, status=400)
