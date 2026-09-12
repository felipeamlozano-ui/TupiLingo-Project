"""
Views de Validação e Verificação de Exercícios da Trilha.
"""

import json
from django.core.cache import cache
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST
from django_ratelimit.decorators import ratelimit

from users.decorators import supabase_auth_required
from users.services.validation_service import (
    validar_lista_lacunas,
    calcular_xp_exercicio,
    ValidationResult,
)
from trilha.models import (
    Exercicio,
    ExercicioEscolha,
    ExercicioCompletar,
    ExercicioAssociacao,
)
from .common import _get_user


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
        elif ex_unificado.tipo == 'traducao_livre':
            from users.services.validation_service import validar_resposta_fuzzy_global
            resp_usuario = body.get('resposta', body.get('respostas', [''])[0] if isinstance(body.get('respostas'), list) and body.get('respostas') else '')
            resp_esperada = (ex_unificado.respostas_corretas or [''])[0]
            val_res = validar_resposta_fuzzy_global(resp_usuario, resp_esperada)
            status = val_res.status
            xp = calcular_xp_exercicio(ex_unificado.pontos_base, primeira_tentativa, status)
            return JsonResponse({
                'success': True, 'status': status,
                'similaridade': val_res.similaridade,
                'resposta_correta': resp_esperada,
                'explicacao': ex_unificado.explicacao,
                'earned_xp': xp,
                'mensagem': val_res.mensagem, 'message': val_res.mensagem,
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
