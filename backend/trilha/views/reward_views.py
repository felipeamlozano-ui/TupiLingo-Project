"""
Views de Recompensas e Baú Cultural da Trilha.
"""

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST
from django_ratelimit.decorators import ratelimit

from users.decorators import supabase_auth_required
from .common import _get_user


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
    from users.services.statistics_service import StatisticsService
    result = ProgressService.collect_chest(user, capitulo_id, milestone_index)
    StatisticsService.invalidate_user_stats_cache(user.id)
    status_code = result.get('status', 200) if not result.get('success', False) else 200
    return JsonResponse(result, status=status_code)
