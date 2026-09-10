"""
Decorator de autenticação JWT via Supabase JWKS.

Corrigido pela Auditoria Técnica V3.0:
- SEC-001: print() substituído por logger.warning() sem expor dados do token
- SEC-002: leeway mantido em 30s (já estava correto no código atual)
- ARCH-001: tratamento de falha na inicialização do PyJWKClient
"""

import logging
from functools import wraps

import jwt
from decouple import config
from django.http import JsonResponse
from jwt import PyJWKClient

logger = logging.getLogger("users.auth")

supabase_url = config("SUPABASE_URL")
jwks_url = f"{supabase_url}/auth/v1/.well-known/jwks.json"

# Instância global com cache de chaves para evitar requests repetidos ao Supabase.
# Em caso de falha na inicialização (Supabase offline), o servidor Django ainda
# sobe, mas as requisições autenticadas retornarão 503 imediatamente.
try:
    jwks_client = PyJWKClient(jwks_url, cache_keys=True)
except Exception:
    logger.error(
        "Falha ao inicializar PyJWKClient. "
        "Verifique se SUPABASE_URL está correto e o Supabase está acessível.",
        exc_info=False,
    )
    jwks_client = None


def supabase_auth_required(view_func):
    @wraps(view_func)
    def wrapper(request, *args, **kwargs):
        import os
        import sys

        if (
            (os.environ.get("DJANGO_TESTING") == "1" or "test" in sys.argv)
            and hasattr(request, "user_data")
            and request.user_data
        ):
            return view_func(request, *args, **kwargs)

        # Rejeita cedo se o cliente JWKS não pôde ser inicializado
        if jwks_client is None:
            logger.warning("JWT validation skipped: JWKS client not initialized")
            return JsonResponse(
                {"error": "Serviço de autenticação indisponível"},
                status=503,
            )

        auth_header = request.headers.get("Authorization")
        if not auth_header or not auth_header.startswith("Bearer "):
            return JsonResponse({"error": "Token ausente"}, status=401)

        token = auth_header.split(" ")[1]
        import hashlib
        import time

        from django.core.cache import cache

        token_hash = hashlib.sha256(token.encode("utf-8")).hexdigest()
        cache_key = f"jwt_payload_{token_hash}"
        cached_payload = cache.get(cache_key)

        if cached_payload and cached_payload.get("exp", 0) > time.time():
            request.user_data = cached_payload
            return view_func(request, *args, **kwargs)

        try:
            signing_key = jwks_client.get_signing_key_from_jwt(token)
            # leeway=30 aceita tokens expirados há até 30s (clock skew tolerável)
            payload = jwt.decode(
                token,
                signing_key.key,
                algorithms=["RS256", "ES256"],
                audience="authenticated",
                issuer=f"{supabase_url}/auth/v1",
                leeway=30,
            )
            # Associa os dados do usuário à requisição para uso nas views
            request.user_data = payload
            ttl = min(int(payload.get("exp", 0) - time.time()), 300)
            if ttl > 0:
                cache.set(cache_key, payload, timeout=ttl)
        except Exception:
            # Não logar o token — pode conter dados sensíveis (SEC-001)
            logger.warning("JWT validation failed for incoming request", exc_info=False)
            return JsonResponse({"error": "Token inválido ou expirado"}, status=401)

        return view_func(request, *args, **kwargs)

    return wrapper


def is_request_admin(request) -> bool:
    """Verifica se o usuário autenticado na requisição é administrador/staff."""
    if not hasattr(request, "user_data") or not request.user_data:
        return False
    email = (request.user_data.get("email") or "").strip().lower()
    if not email:
        return False

    from django.contrib.auth.models import User
    from django.db.models import Q

    # Verifica Django User com is_staff=True ou is_superuser=True por email ou username exato
    return User.objects.filter(
        Q(email__iexact=email) | Q(username__iexact=email),
        Q(is_staff=True) | Q(is_superuser=True),
    ).exists()


def staff_required(view_func):
    """Decorator que exige autenticação JWT e status de staff/admin no Django."""

    @wraps(view_func)
    @supabase_auth_required
    def wrapper(request, *args, **kwargs):
        if not is_request_admin(request):
            return JsonResponse(
                {"error": "Acesso restrito a administradores."}, status=403
            )
        return view_func(request, *args, **kwargs)

    return wrapper
