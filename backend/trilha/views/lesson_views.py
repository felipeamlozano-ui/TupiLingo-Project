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


def _recalibrar_nivel(user: UserProfile, variante: VarianteTupi, licao: Licao | None = None, accuracy: float = 1.0) -> int:
    """
    Recalibra o nível adaptativo do usuário (BirdBrain IRT 3PL EAP) com base no desempenho real.
    Atualiza continuamente theta (habilidade latente) e erro padrão (SE), registrando auditoria.
    Anti-manipulação: calculado exclusivamente no backend com lock pessimista (SCALE-002).
    """
    import math
    from datetime import timedelta
    from django.utils import timezone
    from nivelamento.models import UserVarianteLevel, BirdbrainCalibrationLog
    from pedagogico.calibracao.birdbrain_service import BirdbrainService
    from users.services.progress_service import ProgressService
    from trilha.models import Exercicio

    with transaction.atomic():
        level_obj, _ = UserVarianteLevel.objects.select_for_update().get_or_create(
            user=user,
            variante=variante,
            defaults={'nivel': 1, 'current_theta': 0.0, 'current_se': 1.0}
        )

        old_theta = float(level_obj.current_theta)
        old_se = float(level_obj.current_se if level_obj.current_se > 0.05 else 0.5)
        old_nivel = level_obj.nivel

        # Caso A: Invocação sem lição específica (avaliação baseada no histórico recente)
        if licao is None:
            recentes = list(UserLesson.objects.filter(
                usuario=user,
                status='concluida'
            ).order_by('-concluida_em', '-id')[:3])

            if len(recentes) >= 3:
                avg_acc = sum(float(ul.accuracy or 0.0) for ul in recentes) / len(recentes)
                if avg_acc >= 0.85:
                    novo_nivel = min(10, old_nivel + 1)
                elif avg_acc <= 0.40:
                    novo_nivel = max(1, old_nivel - 1)
                else:
                    novo_nivel = old_nivel
            else:
                novo_nivel = old_nivel

            level_obj.nivel = novo_nivel
            level_obj.save(update_fields=['nivel', 'updated_at'])
            return novo_nivel

        # Caso B: Recalibração psicométrica adaptativa (BirdBrain IRT 3PL EAP)
        # Idempotência: impede re-calibração duplicada nos últimos 15 segundos para a mesma lição
        recent_log = BirdbrainCalibrationLog.objects.filter(
            user=user,
            variante=variante,
            licao=licao,
            created_at__gte=timezone.now() - timedelta(seconds=15)
        ).first()
        if recent_log:
            logger.info("Recalibração ignorada por idempotência (evento recente registrado para licao %s)", licao.id)
            return level_obj.nivel

        cap_num = licao.capitulo.numero if (licao and licao.capitulo) else 1
        item_b = round(-2.5 + (cap_num - 1) * (5.0 / 19.0), 3)

        # Utiliza os exercícios reais da lição
        exercicios_reais = list(Exercicio.objects.filter(licao=licao).order_by('ordem'))
        total_items = len(exercicios_reais) if exercicios_reais else 5
        correct_count = int(round(accuracy * total_items))

        lesson_responses = []
        for i in range(total_items):
            ex_id = exercicios_reais[i].id if i < len(exercicios_reais) else f"LES_{licao.id}_{i}"
            lesson_responses.append({
                "item_id": f"EX_{ex_id}",
                "param_a": 1.2,
                "param_b": item_b,
                "param_c": 0.25,
                "is_correct": (i < correct_count),
                "dominio": licao.capitulo.titulo if licao and licao.capitulo else "geral"
            })

        bb = BirdbrainService()
        new_theta, new_se, diag = bb.update_theta_after_lesson(
            current_theta=old_theta,
            current_se=old_se,
            lesson_responses=lesson_responses,
            learning_rate=0.20
        )

        mapped_info = bb.irt_engine.map_theta_to_entry_chapter(new_theta)
        entry_ch = mapped_info.get("entry_chapter", 1)
        novo_nivel = max(1, min(10, math.ceil(entry_ch / 2.0)))

        level_obj.current_theta = new_theta
        level_obj.current_se = new_se
        level_obj.nivel = novo_nivel
        level_obj.calibracoes_count = F('calibracoes_count') + 1
        level_obj.save(update_fields=['current_theta', 'current_se', 'nivel', 'calibracoes_count', 'updated_at'])
        level_obj.refresh_from_db(fields=['calibracoes_count'])

        # Registra no log de auditoria do BirdBrain
        BirdbrainCalibrationLog.objects.create(
            user=user,
            variante=variante,
            licao=licao,
            old_theta=old_theta,
            new_theta=new_theta,
            old_se=old_se,
            new_se=new_se,
            delta=round(new_theta - old_theta, 3),
            accuracy_pct=round(accuracy * 100, 1),
            items_count=total_items,
            old_nivel=old_nivel,
            new_nivel=novo_nivel,
        )

        if novo_nivel != old_nivel:
            ProgressService.invalidate_user_trail_cache(user.id, variante.id)
            logger.info("BirdBrain: Usuário %s mudou de nível %d -> %d em %s (θ: %.3f -> %.3f, SE: %.3f)",
                        user.id, old_nivel, novo_nivel, variante.nome, old_theta, new_theta, new_se)

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
        id=licao_id
    ).first()

    # Se não encontrar por ID direto, busca por número sequencial na variante ativa ou trilha
    if not licao:
        variante_user = user.variante_ativa
        if variante_user:
            licao = Licao.objects.select_related('capitulo__trilha__variante').prefetch_related(
                'story_blocks',
                'exercicios'
            ).filter(
                capitulo__trilha__variante=variante_user, numero=licao_id
            ).first()
        if not licao:
            licao = Licao.objects.select_related('capitulo__trilha__variante').prefetch_related(
                'story_blocks',
                'exercicios'
            ).filter(numero=licao_id).first()

    if not licao:
        return JsonResponse({'error': 'Lição não encontrada.'}, status=404)

    # A lição só deve estar marcada como publicada se realmente existir no banco
    if not licao.publicada:
        licao.publicada = True
        licao.save(update_fields=['publicada'])

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
            'numero': licao.numero, 'is_dynamic_ai': licao.is_dynamic_ai,
            'ai_prompt_theme': licao.ai_prompt_theme,
            'ai_vocabulary_anchors': licao.ai_vocabulary_anchors,
            'capitulo': {'id': licao.capitulo.id, 'numero': licao.capitulo.numero, 'titulo': licao.capitulo.titulo},
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

    licao = Licao.objects.select_related('capitulo__trilha__variante').filter(id=licao_id).first()
    if not licao:
        variante_user = user.variante_ativa
        if variante_user:
            licao = Licao.objects.select_related('capitulo__trilha__variante').filter(
                capitulo__trilha__variante=variante_user, numero=licao_id
            ).first()
        if not licao:
            licao = Licao.objects.select_related('capitulo__trilha__variante').filter(numero=licao_id).first()

    if not licao:
        return JsonResponse({'error': 'Lição não encontrada.'}, status=404)

    from users.decorators import is_request_admin
    from users.services.progress_service import ProgressService
    is_admin = is_request_admin(request)
    if not is_admin and not ProgressService.is_lesson_accessible(user, licao):
        return JsonResponse({
            'error': 'Esta lição está bloqueada na sua jornada. Conclua as anteriores primeiro.',
            'code': 'LESSON_LOCKED',
            'licao_id': licao.id,
        }, status=403)

    if not licao.publicada:
        licao.publicada = True
        licao.save(update_fields=['publicada'])

    try:
        body = json.loads(request.body)
    except (json.JSONDecodeError, ValueError):
        return JsonResponse({'error': 'JSON inválido.'}, status=400)

    # SEC-005: Sanitização e Anti-Cheat robusto
    try:
        tempo_gasto = int(body.get('tempo_segundos', 60))
    except (ValueError, TypeError):
        tempo_gasto = 60
    tempo_gasto = max(1, min(tempo_gasto, 86400))

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

    # Anti-cheat: Validação fisiológica temporal mínima (impede bots completando em < 3s lições com múltiplos exercícios)
    if total > 1 and tempo_gasto < 3:
        return JsonResponse({'error': 'Tempo de lição insuficiente para validação fisiológica.'}, status=400)

    try:
        acertos_raw = int(body.get('acertos', 0))
    except (ValueError, TypeError):
        acertos_raw = 0
    acertos = max(0, min(acertos_raw, total))

    # bonus_exploracao ainda aceito do payload (XP de StoryBlocks lidos), mas com cap razoável
    try:
        bonus_raw = int(body.get('bonus_exploracao_xp', 0))
    except (ValueError, TypeError):
        bonus_raw = 0
    bonus_exploracao = max(0, min(bonus_raw, 100))

    # Anti-replay e idempotência: valida nonce se enviado
    nonce = body.get('nonce') or body.get('idempotency_key')
    if nonce:
        from users.store_crypto import mark_nonce_used
        if not mark_nonce_used(str(nonce)):
            logger.warning("Replay attack ou duplicata detectada para nonce: %s", nonce)
            return JsonResponse({
                'success': True,
                'already_completed': True,
                'replayed': True,
                'message': 'Requisição já processada anteriormente.',
            })

    from users.services.progress_service import ProgressService
    from users.services.streak_service import StreakService
    from nivelamento.models import UserVarianteLevel

    # SEC-002: Trava pessimista transacional atômica (select_for_update) contra Race Conditions
    with transaction.atomic():
        locked_user = UserProfile.objects.select_for_update().get(pk=user.pk)
        user_lesson, _ = UserLesson.objects.select_for_update().get_or_create(usuario=locked_user, licao=licao)

        # Sincroniza a variante ativa do usuário com a variante da lição concluída
        variante_licao = licao.capitulo.trilha.variante
        if locked_user.variante_ativa_id != variante_licao.id:
            locked_user.variante_ativa = variante_licao
            locked_user.save(update_fields=['variante_ativa', 'updated_at'])

        # SEC-003: Idempotência com suporte a revisão — previne farm de XP infinito
        if user_lesson.status == 'concluida':
            prox_licao = ProgressService.unlock_next_lesson(locked_user, licao)
            StreakService.register_study_activity(
                user=locked_user,
                xp_ganho=0,
                tempo_segundos=tempo_gasto,
                is_lesson_completed=True,
                exercicios_respondidos=total,
                exercicios_corretos=acertos,
            )
            locked_user.refresh_from_db(fields=['xp_total', 'streak_atual', 'maior_streak', 'conchas'])
            lvl_obj = UserVarianteLevel.objects.filter(user=locked_user, variante=licao.capitulo.trilha.variante).first()
            ProgressService.invalidate_user_trail_cache(locked_user.id, licao.capitulo.trilha.variante_id)
            from users.services.statistics_service import StatisticsService
            StatisticsService.invalidate_user_stats_cache(locked_user.id)

            return JsonResponse({
                'success': True,
                'already_completed': True,
                'variante_id': variante_licao.id,
                'variante_nome': variante_licao.nome,
                'variante_codigo': variante_licao.codigo,
                'earned_xp': 0,
                'earned_conchas': 0,
                'xp_total': locked_user.xp_total,
                'conchas': getattr(locked_user, 'conchas', 0),
                'streak_atual': locked_user.streak_atual,
                'dias_ofensiva': locked_user.streak_atual,
                'accuracy': user_lesson.accuracy,
                'total_exercicios_servidor': total,
                'nivel_atual': lvl_obj.nivel if lvl_obj else 1,
                'novas_conquistas': [],
                'proxima_licao_id': prox_licao.id if prox_licao else None,
                'proxima_licao_desbloqueada': prox_licao is not None,
                'message': 'Lição concluída! Ofensiva diária mantida.',
            })

        # Primeira conclusão legítima
        acertos = min(acertos, total)
        accuracy = round(acertos / total, 2)
        status_ex = (
            ValidationResult.CORRETO if accuracy >= 0.9 else
            ValidationResult.QUASE_CERTO if accuracy >= 0.7 else
            ValidationResult.ERRADO
        )

        earned_xp = calcular_xp_exercicio(
            pontos_base=licao.xp_base,
            primeira_tentativa=True,
            resultado_status=status_ex,
            bonus_exploracao=bonus_exploracao,
        )
        earned_conchas = 5

        user_lesson.status = 'concluida'
        user_lesson.completion_percentage = 100.0
        user_lesson.accuracy = accuracy
        user_lesson.earned_xp = earned_xp
        user_lesson.concluida_em = timezone.now()
        user_lesson.save()

        # Desbloqueia automaticamente a próxima lição da jornada
        prox_licao = ProgressService.unlock_next_lesson(locked_user, licao)

        # Atualiza conchas do usuário atomicamente
        locked_user.conchas = getattr(locked_user, 'conchas', 0) + earned_conchas
        locked_user.save(update_fields=['conchas', 'updated_at'])

        # Registra no log de atividade diária e atualiza streak e XP de forma atômica
        StreakService.register_study_activity(
            user=locked_user,
            xp_ganho=earned_xp,
            tempo_segundos=tempo_gasto,
            is_lesson_completed=True,
            exercicios_respondidos=total,
            exercicios_corretos=acertos,
        )
        locked_user.refresh_from_db(fields=['xp_total', 'streak_atual', 'maior_streak', 'conchas'])
        ProgressService.invalidate_user_trail_cache(locked_user.id, licao.capitulo.trilha.variante_id)
        from users.services.statistics_service import StatisticsService
        StatisticsService.invalidate_user_stats_cache(locked_user.id)
        user = locked_user

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
            novo_nivel = _recalibrar_nivel(user, variante, licao=licao, accuracy=accuracy)
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
