"""
Views da API de Trilha — Jornada Histórica do TupiLingo.

Fornece todos os dados que o Flutter precisa para renderizar:
- O mapa interativo (variantes, capítulos, lições com posição e estado).
- O player de lições (StoryBlocks, exercícios, vocabulário).
- A validação de exercícios com tolerância a erros (unaccent + levenshtein).
"""

import json
import logging

from django.db.models import F
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST, require_GET
from django_ratelimit.decorators import ratelimit
from django.utils import timezone

from users.decorators import supabase_auth_required
from users.models import UserProfile, UserLesson
from users.services.validation_service import (
    validar_lista_lacunas,
    calcular_xp_exercicio,
    ValidationResult,
)
from .models import (
    VarianteTupi,
    TrilhaHistorica,
    Capitulo,
    Licao,
    StoryBlock,
    Exercicio,
    ExercicioCompletar,
    ExercicioEscolha,
    ExercicioAssociacao,
    VocabularyItem,
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
    """Garante que o registro de progresso da lição existe para o usuário."""
    obj, _ = UserLesson.objects.get_or_create(
        usuario=user,
        licao=licao,
        defaults={'status': 'disponivel'},
    )
    return obj


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
    capitulos_qs = trilha.capitulos.filter(numero__lt=900).select_related('scenario').order_by('numero')
    if not capitulos_qs.filter(publicado=True).exists() and capitulos_qs.exists():
        capitulos_qs.update(publicado=True)

    user_lessons = {
        ul.licao_id: ul
        for ul in UserLesson.objects.filter(usuario=user, licao__capitulo__trilha=trilha)
    }

    # Se o usuário não possui nenhuma lição acessível nesta trilha, desbloqueia a primeira lição
    tem_licao_acessivel = any(
        ul.status in ['disponivel', 'em_andamento', 'concluida']
        for ul in user_lessons.values()
    )
    if not tem_licao_acessivel:
        primeira_licao = Licao.objects.filter(
            capitulo__trilha=trilha,
            publicada=True
        ).order_by('capitulo__numero', 'numero').first()
        if primeira_licao:
            ul, _ = UserLesson.objects.get_or_create(
                usuario=user,
                licao=primeira_licao,
                defaults={'status': 'disponivel'}
            )
            if ul.status == 'bloqueada':
                ul.status = 'disponivel'
                ul.save(update_fields=['status'])
            user_lessons[primeira_licao.id] = ul

    capitulos_data = []
    for capitulo in capitulos_qs.filter(publicado=True):
        scenario = capitulo.scenario
        licoes_qs = capitulo.licoes.all().order_by('numero')
        if not licoes_qs.filter(publicada=True).exists() and licoes_qs.exists():
            licoes_qs.update(publicada=True)

        licoes_data = []
        for licao in licoes_qs.filter(publicada=True):
            user_lesson = user_lessons.get(licao.id)
            status = user_lesson.status if user_lesson else 'bloqueada'

            licoes_data.append({
                'id': licao.id,
                'titulo': licao.titulo,
                'descricao': licao.descricao,
                'numero': licao.numero,
                'xp_base': licao.xp_base,
                'pos_x': licao.pos_x,
                'pos_y': licao.pos_y,
                'status': status,
                'completion_percentage': user_lesson.completion_percentage if user_lesson else 0.0,
                'earned_xp': user_lesson.earned_xp if user_lesson else 0,
            })

        capitulos_data.append({
            'id': capitulo.id,
            'numero': capitulo.numero,
            'titulo': capitulo.titulo,
            'descricao': capitulo.descricao,
            'scenario': {
                'nome': scenario.nome if scenario else '',
                'background_image': scenario.background_image.url if scenario and scenario.background_image else None,
                'ambient_audio': scenario.ambient_audio.url if scenario and scenario.ambient_audio else None,
                'palette': scenario.palette if scenario else {},
            } if scenario else None,
            'licoes': licoes_data,
        })

    return JsonResponse({
        'success': True,
        'variante': {'id': variante.id, 'nome': variante.nome, 'codigo': variante.codigo},
        'trilha': {'id': trilha.id, 'titulo': trilha.titulo, 'subtitulo': trilha.subtitulo},
        'capitulos': capitulos_data,
    })


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

    user_lesson = _get_or_create_user_lesson(user, licao)
    if user_lesson.status == 'bloqueada':
        return JsonResponse({'error': 'Esta lição está bloqueada.'}, status=403)

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
    Anti-manipulação: calculado exclusivamente no backend.
    """
    from nivelamento.models import UserVarianteLevel

    level_obj, _ = UserVarianteLevel.objects.get_or_create(
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
                level_obj.nivel += 1
                level_obj.save(update_fields=['nivel', 'updated_at'])
                logger.info("Usuário %s subiu para nível %d em %s", user.id, level_obj.nivel, variante.nome)
        elif all(ul.accuracy <= 0.40 for ul in ultimas_licoes):
            if level_obj.nivel > 1:
                level_obj.nivel -= 1
                level_obj.save(update_fields=['nivel', 'updated_at'])
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
    primeira_tentativa = bool(body.get('primeira_tentativa', False))

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

    user_lesson, _ = UserLesson.objects.get_or_create(usuario=user, licao=licao)
    user_lesson.status = 'concluida'
    user_lesson.completion_percentage = 100.0
    user_lesson.accuracy = accuracy
    user_lesson.earned_xp = earned_xp
    user_lesson.concluida_em = timezone.now()
    user_lesson.save()

    # Desbloqueia automaticamente a próxima lição da jornada
    prox_licao = _desbloquear_proxima_licao(user, licao)

    # PERFORMANCE-001: Atualização atômica com F() para evitar race condition em
    # ambientes com múltiplas workers Gunicorn ou requests concorrentes.
    UserProfile.objects.filter(pk=user.pk).update(
        xp_total=F('xp_total') + earned_xp,
        updated_at=timezone.now(),
    )
    user.refresh_from_db(fields=['xp_total'])

    # Calibração de Nível
    variante = licao.capitulo.trilha.variante
    novo_nivel = _recalibrar_nivel(user, variante)

    # Processamento de Achievements
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

    return JsonResponse({
        'success': True,
        'earned_xp': earned_xp,
        'xp_total': user.xp_total,
        'accuracy': accuracy,
        'total_exercicios_servidor': total,
        'nivel_atual': novo_nivel,
        'novas_conquistas': novas_ach,
        'proxima_licao_id': prox_licao.id if prox_licao else None,
        'proxima_licao_desbloqueada': prox_licao is not None,
        'message': f'Lição concluída! Você ganhou {earned_xp} XP. 🎉',
    })


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

    # 1. Tenta buscar no modelo unificado Exercicio
    ex_unificado = Exercicio.objects.filter(id=exercicio_id).first()
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
