from rest_framework.permissions import BasePermission
from users.decorators import is_request_admin
from .security import otp_service


class IsAdminOrDevSession(BasePermission):
    """
    Permite acesso a administradores autenticados (is_staff / is_superuser),
    tokens Supabase vinculados a staff/admin, ou sessões ativas do
    Developer Enclave validadas via header X-Dev-Session.
    """
    def has_permission(self, request, view):
        # 1. Django admin / staff padrão
        user = getattr(request, 'user', None)
        if user and user.is_authenticated and (user.is_staff or user.is_superuser):
            return True

        # 2. Token Supabase autenticado de usuário staff/admin
        if is_request_admin(request):
            return True

        # 3. Token de sessão ativo do Developer Enclave
        dev_session = request.META.get('HTTP_X_DEV_SESSION') or request.headers.get('X-Dev-Session')
        if dev_session and otp_service.is_dev_session_valid(dev_session):
            return True

        return False
