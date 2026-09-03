"""
Views da API de Trilha — Jornada Histórica do TupiLingo.

Fornece todos os dados que o Flutter precisa para renderizar:
- O mapa interativo (variantes, capítulos, lições com posição e estado).
- O player de lições (StoryBlocks, exercícios, vocabulário).
- A validação de exercícios com tolerância a erros (unaccent + levenshtein).
"""

import json
import logging

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
        return JsonResponse({'error': 'Esta variante ainda não possui uma Trilha publicada.'}, status=404)

    if not trilha.publicada:
        return JsonResponse({'error': 'Trilha não está publicada.'}, status=404)

    user_lessons = {
        ul.licao_id: ul
        for ul in UserLesson.objects.filter(usuario=user, licao__capitulo__trilha=trilha)
    }

    capitulos_data = []
    for capitulo in trilha.capitulos.filter(publicado=True).select_related('scenario').order_by('numero'):
        scenario = capitulo.scenario
        licoes_data = []

        for licao in capitulo.licoes.filter(publicada=True).order_by('numero'):
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
    for ex in ExercicioEscolha.objects.filter(licao=licao).order_by('ordem'):
        exercicios.append({
            'id': ex.id, 'tipo': 'escolha_multipla', 'enunciado': ex.enunciado,
            'explicacao': ex.explicacao, 'dificuldade': ex.dificuldade,
            'pontos_base': ex.pontos_base, 'ordem': ex.ordem,
            'midia': ex.midia.url if ex.midia else None,
            'opcoes': ex.opcoes, 'resposta_correta': ex.resposta_correta,
        })
    for ex in ExercicioCompletar.objects.filter(licao=licao).order_by('ordem'):
        exercicios.append({
            'id': ex.id, 'tipo': 'completar', 'enunciado': ex.enunciado,
            'explicacao': ex.explicacao, 'dificuldade': ex.dificuldade,
            'pontos_base': ex.pontos_base, 'ordem': ex.ordem,
            'midia': ex.midia.url if ex.midia else None,
            'texto_com_lacunas': ex.texto_com_lacunas,
            'tolerancia_levenshtein': ex.tolerancia_levenshtein,
            # NÃO enviamos respostas_corretas ao Flutter — validação é server-side
        })
    for ex in ExercicioAssociacao.objects.filter(licao=licao).order_by('ordem'):
        exercicios.append({
            'id': ex.id, 'tipo': 'associacao', 'enunciado': ex.enunciado,
            'explicacao': ex.explicacao, 'dificuldade': ex.dificuldade,
            'pontos_base': ex.pontos_base, 'ordem': ex.ordem,
            'midia': ex.midia.url if ex.midia else None,
            'coluna_esquerda': ex.coluna_esquerda, 'coluna_direita': ex.coluna_direita,
            # NÃO enviamos associacao_correta — validação é server-side
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

    licao = Licao.objects.filter(id=licao_id, publicada=True).first()
    if not licao:
        return JsonResponse({'error': 'Lição não encontrada.'}, status=404)

    try:
        body = json.loads(request.body)
    except (json.JSONDecodeError, ValueError):
        return JsonResponse({'error': 'JSON inválido.'}, status=400)

    acertos = int(body.get('acertos', 0))
    total = int(body.get('total_exercicios', 1))
    bonus_exploracao = int(body.get('bonus_exploracao_xp', 0))
    primeira_tentativa = bool(body.get('primeira_tentativa', False))

    accuracy = acertos / total if total > 0 else 0.0
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

    user.xp_total = (user.xp_total or 0) + earned_xp
    user.save(update_fields=['xp_total', 'updated_at'])

    return JsonResponse({
        'success': True,
        'earned_xp': earned_xp,
        'xp_total': user.xp_total,
        'accuracy': accuracy,
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

    if tipo == 'escolha_multipla':
        ex = ExercicioEscolha.objects.filter(id=exercicio_id).first()
        if not ex:
            return JsonResponse({'error': 'Exercício não encontrado.'}, status=404)
        indice = body.get('resposta_indice')
        correto = indice == ex.resposta_correta
        status = ValidationResult.CORRETO if correto else ValidationResult.ERRADO
        xp = calcular_xp_exercicio(ex.pontos_base, primeira_tentativa, status)
        return JsonResponse({
            'success': True, 'status': status, 'correto': correto,
            'resposta_correta_indice': ex.resposta_correta, 'explicacao': ex.explicacao, 'earned_xp': xp,
            'mensagem': 'Correto! 🎉' if correto else f'Incorreto. A resposta certa era a opção {ex.resposta_correta + 1}.',
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
        return JsonResponse({
            'success': True, 'status': status,
            'resultados_lacunas': resultado['resultados'],
            'acertos': resultado['acertos'], 'total': resultado['total'],
            'explicacao': ex.explicacao, 'earned_xp': xp,
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
        return JsonResponse({
            'success': True, 'status': status, 'correto': correto,
            'associacao_correta': ex.associacao_correta, 'explicacao': ex.explicacao, 'earned_xp': xp,
            'mensagem': 'Correto! 🎉' if correto else 'Associação incorreta.',
        })

    return JsonResponse({'error': f"Tipo '{tipo}' não reconhecido."}, status=400)
