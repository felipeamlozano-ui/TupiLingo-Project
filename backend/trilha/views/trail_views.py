"""
Views de Variantes e Navegação no Mapa da Trilha.
"""

import json
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET
from django_ratelimit.decorators import ratelimit

from users.decorators import supabase_auth_required
from trilha.models import (
    VarianteTupi,
    TrilhaHistorica,
    Licao,
)
from .common import _get_user


@csrf_exempt
@ratelimit(key='ip', rate='30/m', block=True)
@supabase_auth_required
@require_GET
def listar_variantes(request):
    """Retorna todas as VariantesTupi ativas com status do usuário."""
    user, err = _get_user(request)
    if err:
        return err

    variantes = list(VarianteTupi.objects.filter(ativo=True).order_by('ordem'))
    from nivelamento.models import TestAttempt
    user_tested_variant_ids = set(
        TestAttempt.objects.filter(user=user).values_list('variante_id', flat=True)
    )
    data = []
    for v in variantes:
        ja_testou = v.id in user_tested_variant_ids
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
    progresso real das lições e capítulos do usuário na trilha, com cache Redis de 60s.
    """
    user, err = _get_user(request)
    if err:
        return err

    from users.services.progress_service import ProgressService
    from nivelamento.models import UserVarianteLevel
    from app.ai.ping_race import get_redis_client
    from trilha.services.historical_region_service import HistoricalRegionService

    variante = user.variante_ativa
    if not variante:
        variante = VarianteTupi.objects.filter(ativo=True).order_by('ordem').first()

    r = get_redis_client()
    cache_key = f"mapa_regioes_{user.id}_{variante.id if variante else 1}"
    force_refresh = request.GET.get('refresh') in ('1', 'true', 'True')
    if r and not force_refresh:
        try:
            cached = r.get(cache_key)
            if cached:
                return JsonResponse(json.loads(cached))
        except Exception:
            pass

    trail_data = ProgressService.get_trail_structure_with_progression(user, variante) if variante else {}
    capitulos = trail_data.get('capitulos', [])

    lvl_obj = UserVarianteLevel.objects.filter(user=user, variante=variante).first() if variante else None
    user_nivel = lvl_obj.nivel if lvl_obj else 1

    regioes_finais = HistoricalRegionService.build_user_regions(
        capitulos=capitulos,
        user_nivel=user_nivel
    )

    resp_data = {'success': True, 'regioes': regioes_finais}
    if r:
        try:
            r.setex(cache_key, 60, json.dumps(resp_data, ensure_ascii=False))
        except Exception:
            pass

    return JsonResponse(resp_data)
