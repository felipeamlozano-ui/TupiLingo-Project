"""
Validação de autenticação de usuários via Supabase JWT.
Garante que a requisição contenha um token válido emitido pelo Supabase
e anexa as informações do usuário autenticado a `request.user_data`.
"""

import hashlib
import json
import logging
import time
from functools import wraps
from urllib.request import Request, urlopen

import jwt
from decouple import config
from django.core.cache import cache
from django.http import JsonResponse
from jwt import PyJWKClient

logger = logging.getLogger('users.auth')

supabase_url = config('SUPABASE_URL', default='https://pcquxppvheodcrdkwqhh.supabase.co').rstrip('/')
supabase_jwt_secret = config('SUPABASE_JWT_SECRET', default='')
supabase_service_key = config('SUPABASE_SERVICE_ROLE_KEY', default='')
jwks_url = f"{supabase_url}/auth/v1/.well-known/jwks.json"

# Inicializa cliente JWKS para projetos com chaves assimétricas (RS256/ES256)
try:
    jwks_client = PyJWKClient(jwks_url, cache_keys=True)
except Exception:
    jwks_client = None


def _validate_with_supabase_api(token: str) -> dict | None:
    """Valida o token diretamente na API do Supabase caso a decodificação local falhe."""
    try:
        url = f"{supabase_url}/auth/v1/user"
        req = Request(url)
        req.add_header('Authorization', f'Bearer {token}')
        if supabase_service_key:
            req.add_header('apikey', supabase_service_key)
        
        with urlopen(req, timeout=5) as response:
            if response.status == 200:
                data = json.loads(response.read().decode('utf-8'))
                user_id = data.get('id')
                if not user_id:
                    return None
                return {
                    'sub': user_id,
                    'email': data.get('email', ''),
                    'user_metadata': data.get('user_metadata', {}),
                    'app_metadata': data.get('app_metadata', {}),
                    'exp': time.time() + 300,
                }
    except Exception as exc:
        logger.debug("Falha na validação remota de token pelo Supabase: %s", exc)
    return None


def supabase_auth_required(view_func):
    """Garante que a requisição possua um token JWT válido do Supabase."""
    @wraps(view_func)
    def wrapper(request, *args, **kwargs):
        import os
        import sys
        if ((os.environ.get('DJANGO_TESTING') == '1' or 'test' in sys.argv)
                and hasattr(request, 'user_data')
                and request.user_data):
            return view_func(request, *args, **kwargs)

        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return JsonResponse({'error': 'Token de autenticação ausente.'}, status=401)

        token = auth_header.split(' ')[1].strip()
        if not token:
            return JsonResponse({'error': 'Token vazio.'}, status=401)

        token_hash = hashlib.sha256(token.encode('utf-8')).hexdigest()
        cache_key = f"jwt_payload_{token_hash}"
        cached_payload = cache.get(cache_key)

        if cached_payload and cached_payload.get('exp', 0) > time.time():
            request.user_data = cached_payload
            return view_func(request, *args, **kwargs)

        payload = None

        # 1. Tenta decodificar o token inspecionando o algoritmo do cabeçalho
        try:
            unverified_header = jwt.get_unverified_header(token)
            alg = unverified_header.get('alg', 'HS256')

            if alg == 'HS256' and supabase_jwt_secret:
                payload = jwt.decode(
                    token,
                    supabase_jwt_secret,
                    algorithms=['HS256'],
                    options={"verify_aud": False},
                    leeway=30,
                )
            elif alg in ['RS256', 'ES256'] and jwks_client is not None:
                signing_key = jwks_client.get_signing_key_from_jwt(token)
                payload = jwt.decode(
                    token,
                    signing_key.key,
                    algorithms=['RS256', 'ES256'],
                    options={"verify_aud": False},
                    leeway=30,
                )
        except Exception as e:
            logger.debug("Tentativa local de decodificação falhou (%s), tentando validação direta...", e)

        # 2. Se a decodificação local não tiver obtido o payload, valida diretamente com a API do Supabase
        if not payload:
            payload = _validate_with_supabase_api(token)

        if not payload:
            logger.warning("Validação de JWT falhou: token inválido ou não reconhecido pelo Supabase.")
            return JsonResponse({'error': 'Token inválido ou expirado.'}, status=401)

        request.user_data = payload
        ttl = max(30, min(int(payload.get('exp', 0) - time.time()), 300))
        cache.set(cache_key, payload, timeout=ttl)

        return view_func(request, *args, **kwargs)
    return wrapper


def is_request_admin(request) -> bool:
    """Verifica se o usuário autenticado na requisição é administrador/staff."""
    if not hasattr(request, 'user_data') or not request.user_data:
        return False
    email = (request.user_data.get('email') or '').strip().lower()
    if not email:
        return False

    from django.contrib.auth.models import User
    from django.db.models import Q

    # Verifica Django User com is_staff=True ou is_superuser=True por email ou username exato
    return User.objects.filter(
        Q(email__iexact=email) | Q(username__iexact=email),
        Q(is_staff=True) | Q(is_superuser=True)
    ).exists()


def staff_required(view_func):
    """Decorator que exige autenticação JWT e status de staff/admin no Django."""
    @wraps(view_func)
    @supabase_auth_required
    def wrapper(request, *args, **kwargs):
        if not is_request_admin(request):
            return JsonResponse({'error': 'Acesso restrito a administradores.'}, status=403)
        return view_func(request, *args, **kwargs)
    return wrapper