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

    from trilha.services.question_variant_engine import QuestionVariantEngine
    from users.models import ItemExposure, HistoricoResposta

    engine = QuestionVariantEngine()
    variant_token = body.get('variant_token')
    resolved_body, selected_versao, token_data = engine.resolve_submission(variant_token, body)

    # 1. Tenta buscar no modelo unificado Exercicio (com cache em memória para resposta instantânea)
    ex_cache_key = f"exercicio_unificado_{exercicio_id}"
    ex_unificado = cache.get(ex_cache_key)
    if ex_unificado is None:
        ex_unificado = Exercicio.objects.filter(id=exercicio_id).first()
        if ex_unificado:
            cache.set(ex_cache_key, ex_unificado, timeout=600)

    if ex_unificado:
        correto = False
        status = ValidationResult.ERRADO
        xp = 0
        resp_payload = {}
        explicacao = (selected_versao.explicacao if selected_versao and selected_versao.explicacao else ex_unificado.explicacao) or ""

        if ex_unificado.tipo == 'escolha_multipla':
            indice_original = resolved_body.get('resposta_indice_original', resolved_body.get('resposta_indice'))
            gabarito_correto = (
                int(selected_versao.payload.get('resposta_correta', 0))
                if selected_versao and selected_versao.payload and 'resposta_correta' in selected_versao.payload
                else int(ex_unificado.resposta_correta or 0)
            )
            correto = (indice_original == gabarito_correto)
            status = ValidationResult.CORRETO if correto else ValidationResult.ERRADO
            xp = calcular_xp_exercicio(ex_unificado.pontos_base, primeira_tentativa, status)

            opcoes_exibidas = (
                token_data.get('opcoes_shuffled')
                or (selected_versao.payload.get('opcoes') if selected_versao and selected_versao.payload else None)
                or ex_unificado.opcoes
                or []
            )
            resp_str = opcoes_exibidas[gabarito_correto] if (0 <= gabarito_correto < len(opcoes_exibidas)) else str(gabarito_correto + 1)
            msg = 'Correto! 🎉' if correto else f'Incorreto. A resposta certa era: "{resp_str}".'
            if explicacao:
                msg += f' — {explicacao}'

            resp_payload = {
                'success': True, 'status': status, 'correto': correto,
                'resposta_correta_indice': token_data.get('correta_shuffled', gabarito_correto) if token_data else gabarito_correto,
                'explicacao': explicacao, 'earned_xp': xp,
                'mensagem': msg, 'message': msg,
            }

        elif ex_unificado.tipo == 'completar':
            respostas_usuario = resolved_body.get('respostas', [])
            respostas_corretas = []
            if selected_versao and selected_versao.payload:
                respostas_corretas = selected_versao.payload.get('respostas_corretas', [])
            if not respostas_corretas:
                respostas_corretas = [r for r in (ex_unificado.respostas_corretas or []) if (r or '').strip()]
            if not respostas_corretas:
                import re
                if explicacao:
                    quoted = re.findall(r"['\"]([^'\"]+)['\"]", explicacao)
                    if quoted:
                        respostas_corretas = [quoted[-1]]
                elif ex_unificado.opcoes:
                    respostas_corretas = [ex_unificado.opcoes[0]]

            resultado = validar_lista_lacunas(
                respostas_usuario=respostas_usuario,
                respostas_corretas=respostas_corretas,
                tolerancia=ex_unificado.tolerancia_levenshtein,
            )
            correto = resultado['tudo_correto']
            status = (
                ValidationResult.CORRETO if correto else
                ValidationResult.QUASE_CERTO if resultado['algum_quase'] else
                ValidationResult.ERRADO
            )
            xp = calcular_xp_exercicio(ex_unificado.pontos_base, primeira_tentativa, status)
            if status == ValidationResult.CORRETO:
                msg = 'Correto! 🎉'
            elif status == ValidationResult.QUASE_CERTO:
                msg = resultado['resultados'][0].get('mensagem', 'Quase lá!') if resultado['resultados'] else 'Quase lá!'
            else:
                resp_esperada = ', '.join(respostas_corretas)
                msg = f'Incorreto. A resposta certa era: "{resp_esperada}".' if resp_esperada else 'Incorreto.'
            if explicacao:
                msg += f' — {explicacao}'

            resp_payload = {
                'success': True, 'status': status,
                'resultados_lacunas': resultado['resultados'],
                'acertos': resultado['acertos'], 'total': resultado['total'],
                'explicacao': explicacao, 'earned_xp': xp,
                'mensagem': msg, 'message': msg,
            }

        elif ex_unificado.tipo == 'associacao':
            assoc_usuario = resolved_body.get('associacoes_originais', resolved_body.get('associacoes', {}))
            assoc_esperada = (
                selected_versao.payload.get('associacao_correta')
                if selected_versao and selected_versao.payload and 'associacao_correta' in selected_versao.payload
                else ex_unificado.associacao_correta or {}
            )

            # Validação estrita: todas as chaves preenchidas, sem colisões e pares idênticos
            tem_tamanho_correto = len(assoc_usuario) == len(assoc_esperada) and len(assoc_esperada) > 0
            sem_duplicatas = len(set(assoc_usuario.values())) == len(assoc_usuario)
            todos_pares_certos = all(
                str(assoc_usuario.get(str(k))) == str(v)
                for k, v in assoc_esperada.items()
            )
            correto = tem_tamanho_correto and sem_duplicatas and todos_pares_certos
            status = ValidationResult.CORRETO if correto else ValidationResult.ERRADO
            xp = calcular_xp_exercicio(ex_unificado.pontos_base, primeira_tentativa, status)
            msg = 'Correto! 🎉' if correto else 'Associação incorreta.'
            if explicacao:
                msg += f' — {explicacao}'

            resp_payload = {
                'success': True, 'status': status, 'correto': correto,
                'associacao_correta': token_data.get('assoc_shuffled', assoc_esperada) if token_data else assoc_esperada,
                'explicacao': explicacao, 'earned_xp': xp,
                'mensagem': msg, 'message': msg,
            }

        elif ex_unificado.tipo == 'traducao_livre':
            from users.services.validation_service import validar_resposta_fuzzy_global
            resp_usuario = resolved_body.get('resposta', resolved_body.get('respostas', [''])[0] if isinstance(resolved_body.get('respostas'), list) and resolved_body.get('respostas') else '')
            resp_esperada = (ex_unificado.respostas_corretas or [''])[0]
            val_res = validar_resposta_fuzzy_global(resp_usuario, resp_esperada)
            status = val_res.status
            correto = (status == ValidationResult.CORRETO)
            xp = calcular_xp_exercicio(ex_unificado.pontos_base, primeira_tentativa, status)
            resp_payload = {
                'success': True, 'status': status,
                'similaridade': val_res.similaridade,
                'resposta_correta': resp_esperada,
                'explicacao': explicacao,
                'earned_xp': xp,
                'mensagem': val_res.mensagem, 'message': val_res.mensagem,
            }

        # ── Registro de Telemetria e Calibração BirdBrain por Item ──
        try:
            exposure = ItemExposure.objects.filter(
                user=user, exercicio=ex_unificado
            ).order_by('-shown_at').first()
            if exposure:
                if exposure.answered_correct is None:
                    exposure.answered_correct = correto
                if body.get('time_ms'):
                    exposure.time_ms = int(body.get('time_ms'))
                exposure.save(update_fields=['answered_correct', 'time_ms'])
            else:
                ItemExposure.objects.create(
                    user=user,
                    exercicio=ex_unificado,
                    versao=selected_versao,
                    answered_correct=correto,
                    time_ms=body.get('time_ms'),
                )

            palavra_audit = (
                (ex_unificado.respostas_corretas or [''])[0]
                if ex_unificado.tipo == 'completar' else
                (ex_unificado.opcoes[ex_unificado.resposta_correta] if (ex_unificado.opcoes and ex_unificado.resposta_correta is not None and 0 <= ex_unificado.resposta_correta < len(ex_unificado.opcoes)) else ex_unificado.enunciado[:30])
            )
            time_s = round((body.get('time_ms', 0) or 0) / 1000.0, 2)
            HistoricoResposta.objects.create(
                user=user,
                exercicio=ex_unificado,
                palavra_tupi=palavra_audit[:200],
                status=status,
                time_taken_seconds=time_s,
                origem='trilha',
            )
        except Exception as e:
            logger.error("Erro ao registrar telemetria de resposta: %s", e)

        return JsonResponse(resp_payload)


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
        respostas_corretas = [r for r in (ex.respostas_corretas or []) if (r or '').strip()]
        if not respostas_corretas and ex.explicacao:
            import re
            quoted = re.findall(r"['\"]([^'\"]+)['\"]", ex.explicacao)
            if quoted:
                respostas_corretas = [quoted[-1]]
                ex.respostas_corretas = respostas_corretas
                ex.save(update_fields=['respostas_corretas'])

        resultado = validar_lista_lacunas(
            respostas_usuario=respostas_usuario,
            respostas_corretas=respostas_corretas,
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
            resp_esperada = ', '.join(respostas_corretas)
            msg = f'Incorreto. A resposta certa era: "{resp_esperada}".' if resp_esperada else 'Incorreto.'
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
