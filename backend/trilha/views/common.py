"""
Utilitários e helpers compartilhados para as views da Trilha.
"""

import socket
from urllib.parse import urlparse
from django.conf import settings
from django.http import JsonResponse
from users.models import UserProfile, UserLesson
from trilha.models import Licao


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
