"""
Views de Detalhe e Conclusão de Lições da Trilha.
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
from users.models import UserProfile, UserLesson
from users.services.validation_service import (
    calcular_xp_exercicio,
    ValidationResult,
)
from trilha.models import (
    VarianteTupi,
    Capitulo,
    Licao,
    Exercicio,
    ExercicioCompletar,
    ExercicioEscolha,
    ExercicioAssociacao,
)
from .common import _get_user, _get_or_create_user_lesson, _is_celery_broker_reachable

logger = logging.getLogger("trilha.views.lesson")


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
        ul, _ = UserLesson.objects.get_or_create(
            usuario=user,
            licao=prox_licao,
            defaults={'status': 'disponivel'}
        )
        if ul.status == 'bloqueada':
            ul.status = 'disponivel'
            ul.save(update_fields=['status'])
        logger.info("Próxima lição desbloqueada para user %s: licao_id=%d (%s)", user.id, prox_licao.id, prox_licao.titulo)

    return prox_licao


@csrf_exempt
@ratelimit(key='ip', rate='30/m', block=True)
@supabase_auth_required
@require_GET
def detalhe_licao(request, licao_id: int):
    """Retorna o conteúdo completo de uma Lição para o LessonPlayer do Flutter."""
    user, err = _get_user(request)
    if err:
        return err

    licao = Licao.objects.select_related('capitulo__trilha__variante').prefetch_related(
        'story_blocks',
        'exercicios'
    ).filter(
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

    # Utiliza dados prefetched em memória para evitar N+1 queries
    story_blocks_qs = sorted(licao.story_blocks.all(), key=lambda x: x.ordem)
    story_blocks = []
    for sb in story_blocks_qs:
        story_blocks.append({
            'id': sb.id, 'tipo': sb.tipo, 'titulo': sb.titulo,
            'conteudo': sb.conteudo, 'midia': sb.midia.url if sb.midia else None,
            'ordem': sb.ordem, 'extra': sb.extra, 'xp_bonus': sb.xp_bonus,
        })

    exercicios = []
    exercicios_qs = sorted(licao.exercicios.all(), key=lambda x: x.ordem)
    if exercicios_qs:
        for ex in exercicios_qs:
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

    from users.services.progress_service import ProgressService
    from users.services.streak_service import StreakService
    from nivelamento.models import UserVarianteLevel

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
            user.refresh_from_db(fields=['xp_total', 'streak_atual', 'maior_streak', 'conchas'])
            lvl_obj = UserVarianteLevel.objects.filter(user=user, variante=licao.capitulo.trilha.variante).first()
            ProgressService.invalidate_user_trail_cache(user.id, licao.capitulo.trilha.variante_id)
            from users.services.statistics_service import StatisticsService
            StatisticsService.invalidate_user_stats_cache(user.id)

        return JsonResponse({
            'success': True,
            'already_completed': True,
            'variante_id': variante_licao.id,
            'variante_nome': variante_licao.nome,
            'variante_codigo': variante_licao.codigo,
            'earned_xp': 0,
            'earned_conchas': 0,
            'xp_total': user.xp_total,
            'conchas': getattr(user, 'conchas', 0),
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
        not UserLesson.objects.filter(
            usuario=user,
            licao=licao,
            status='concluida',
        ).exists()
    )

    # Clamp acertos ao total real do servidor
    acertos = min(acertos, total)
    accuracy = round(acertos / total, 2)
    status_ex = (
        ValidationResult.CORRETO if accuracy >= 0.9 else
        ValidationResult.QUASE_CERTO if accuracy >= 0.7 else
        ValidationResult.ERRADO
    )

    earned_xp = calcular_xp_exercicio(
        pontos_base=licao.xp_base,
        primeira_tentativa=primeira_tentativa,
        resultado_status=status_ex,
        bonus_exploracao=bonus_exploracao,
    )
    earned_conchas = 5 if primeira_tentativa else 1

    with transaction.atomic():
        user_lesson.status = 'concluida'
        user_lesson.completion_percentage = 100.0
        user_lesson.accuracy = accuracy
        user_lesson.earned_xp = earned_xp
        user_lesson.concluida_em = timezone.now()
        user_lesson.save()

        # Desbloqueia automaticamente a próxima lição da jornada
        prox_licao = ProgressService.unlock_next_lesson(user, licao)

        # Atualiza conchas do usuário atomicamente
        user.conchas = getattr(user, 'conchas', 0) + earned_conchas
        user.save(update_fields=['conchas', 'updated_at'])

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
        user.refresh_from_db(fields=['xp_total', 'streak_atual', 'maior_streak', 'conchas'])
        ProgressService.invalidate_user_trail_cache(user.id, licao.capitulo.trilha.variante_id)
        from users.services.statistics_service import StatisticsService
        StatisticsService.invalidate_user_stats_cache(user.id)

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
                check_and_grant_xp_achievements,
                check_and_grant_lesson_achievements,
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
        'earned_conchas': earned_conchas,
        'xp_total': user.xp_total,
        'conchas': getattr(user, 'conchas', 0),
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
