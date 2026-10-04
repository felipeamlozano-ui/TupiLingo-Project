"""
Módulo de autenticação segura e gerenciamento de credenciais do TupiLingo.

Este módulo atua como uma ponte autorizada entre o frontend (Flutter) e o serviço
de autenticação do Supabase (GoTrue). Utiliza a chave administrativa do servidor
(SUPABASE_SERVICE_ROLE_KEY) para garantir o envio confiável de requisições de login,
cadastro e recuperação de senha, contornando bloqueios de captcha em clientes móveis
e web enquanto aplica sanitização, validação e mensagens de erro amigáveis em português.
"""

import json
import logging
import re
import requests
from django.conf import settings
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST
from django_ratelimit.decorators import ratelimit

logger = logging.getLogger('users.auth')

EMAIL_REGEX = re.compile(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$')


def _get_supabase_config():
    supabase_url = getattr(settings, 'SUPABASE_URL', '').rstrip('/')
    service_key = getattr(settings, 'SUPABASE_SERVICE_ROLE_KEY', '')
    if not supabase_url or not service_key:
        raise ValueError("Configurações do Supabase ausentes no backend (SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY).")
    return supabase_url, service_key


def _auth_headers(service_key: str):
    return {
        'apikey': service_key,
        'Authorization': f'Bearer {service_key}',
        'Content-Type': 'application/json',
    }


@csrf_exempt
@require_POST
@ratelimit(key='ip', rate='30/m', block=True)
def login_user(request):
    """
    Autentica um usuário com email e senha via GoTrue Supabase.
    Retorna access_token, refresh_token e dados do usuário.
    """
    try:
        data = json.loads(request.body)
    except (json.JSONDecodeError, ValueError):
        return JsonResponse({'error': 'Requisição inválida. Dados mal formatados.'}, status=400)

    email = (data.get('email') or '').strip().lower()
    password = data.get('password') or ''

    if not email:
        return JsonResponse({'error': 'Por favor, digite seu e-mail.'}, status=400)
    if not password:
        return JsonResponse({'error': 'Por favor, digite sua senha.'}, status=400)

    try:
        supabase_url, service_key = _get_supabase_config()
        url = f"{supabase_url}/auth/v1/token?grant_type=password"
        headers = _auth_headers(service_key)

        response = requests.post(
            url,
            headers=headers,
            json={'email': email, 'password': password},
            timeout=8
        )

        res_json = response.json() if response.content else {}

        if response.status_code == 200:
            return JsonResponse({
                'status': 'success',
                'access_token': res_json.get('access_token'),
                'refresh_token': res_json.get('refresh_token'),
                'token_type': res_json.get('token_type', 'bearer'),
                'expires_in': res_json.get('expires_in'),
                'user': res_json.get('user'),
            })

        error_msg = res_json.get('msg') or res_json.get('error_description') or ''
        error_code = res_json.get('error_code', '')

        if 'invalid login credentials' in error_msg.lower() or error_code == 'invalid_credentials':
            return JsonResponse({
                'error': 'E-mail ou senha incorretos. Verifique seus dados e tente novamente.',
                'code': 'invalid_credentials'
            }, status=401)

        if 'email not confirmed' in error_msg.lower():
            return JsonResponse({
                'error': 'E-mail ainda não verificado. Por favor, confirme o código enviado para o seu e-mail.',
                'code': 'email_not_confirmed'
            }, status=403)

        if 'too many requests' in error_msg.lower() or response.status_code == 429:
            return JsonResponse({
                'error': 'Muitas tentativas em pouco tempo. Aguarde alguns minutos e tente novamente.',
                'code': 'rate_limit'
            }, status=429)

        logger.warning(f"[Auth Bridge] Falha no login para {email}: {response.status_code} - {error_msg}")
        return JsonResponse({'error': error_msg or 'Falha ao autenticar usuário.'}, status=response.status_code)

    except requests.RequestException as e:
        logger.error(f"[Auth Bridge] Erro de rede conectando ao Supabase: {e}")
        return JsonResponse({'error': 'Não foi possível conectar ao servidor de autenticação. Tente novamente.'}, status=503)
    except Exception as e:
        logger.error(f"[Auth Bridge] Erro inesperado no login: {e}")
        return JsonResponse({'error': 'Erro interno no processo de autenticação.'}, status=500)


@csrf_exempt
@require_POST
@ratelimit(key='ip', rate='15/m', block=True)
def register_account(request):
    """
    Cria uma nova conta de usuário no Supabase Auth com validação de credenciais.
    Dispara o email de verificação OTP e retorna os dados do usuário criado.
    """
    try:
        data = json.loads(request.body)
    except (json.JSONDecodeError, ValueError):
        return JsonResponse({'error': 'Requisição inválida. Dados mal formatados.'}, status=400)

    email = (data.get('email') or '').strip().lower()
    password = data.get('password') or ''
    name = (data.get('name') or '').strip()
    source = (data.get('source') or '').strip()
    tupi_level = (data.get('tupi_level') or '').strip()

    if not email or not EMAIL_REGEX.match(email):
        return JsonResponse({'error': 'Formato de e-mail inválido.'}, status=400)
    if not password or len(password) < 6:
        return JsonResponse({'error': 'A senha deve conter no mínimo 6 caracteres.'}, status=400)

    try:
        supabase_url, service_key = _get_supabase_config()
        url = f"{supabase_url}/auth/v1/signup"
        headers = _auth_headers(service_key)

        payload = {
            'email': email,
            'password': password,
            'data': {
                'name': name,
                'source': source,
                'tupi_level': tupi_level,
            }
        }

        response = requests.post(url, headers=headers, json=payload, timeout=8)
        res_json = response.json() if response.content else {}

        if response.status_code == 200:
            # Caso o usuário já exista, o GoTrue costuma retornar 200 com identities vazio
            identities = res_json.get('identities')
            if identities is not None and len(identities) == 0:
                return JsonResponse({
                    'error': 'Este e-mail já está cadastrado. Faça login para continuar.',
                    'code': 'already_registered'
                }, status=409)

            return JsonResponse({
                'status': 'success',
                'user': res_json.get('user') or res_json,
                'session': res_json.get('session'),
            })

        error_msg = res_json.get('msg') or res_json.get('error_description') or ''
        if 'already registered' in error_msg.lower() or 'user already exists' in error_msg.lower():
            return JsonResponse({
                'error': 'Este e-mail já está cadastrado. Faça login para continuar.',
                'code': 'already_registered'
            }, status=409)

        logger.warning(f"[Auth Bridge] Falha no cadastro para {email}: {response.status_code} - {error_msg}")
        return JsonResponse({'error': error_msg or 'Não foi possível cadastrar a conta.'}, status=response.status_code)

    except requests.RequestException as e:
        logger.error(f"[Auth Bridge] Erro de rede ao cadastrar no Supabase: {e}")
        return JsonResponse({'error': 'Não foi possível conectar ao servidor de cadastro. Tente novamente.'}, status=503)
    except Exception as e:
        logger.error(f"[Auth Bridge] Erro inesperado no cadastro: {e}")
        return JsonResponse({'error': 'Erro interno ao processar o cadastro.'}, status=500)


@csrf_exempt
@require_POST
@ratelimit(key='ip', rate='10/m', block=True)
def recover_password(request):
    """
    Dispara e-mail de recuperação de senha com OTP via Supabase.
    """
    try:
        data = json.loads(request.body)
    except (json.JSONDecodeError, ValueError):
        return JsonResponse({'error': 'Requisição inválida.'}, status=400)

    email = (data.get('email') or '').strip().lower()
    if not email:
        return JsonResponse({'error': 'Informe o e-mail para recuperação.'}, status=400)

    try:
        from platform_telemetry.security.otp_service import _dispatch_supabase_otp
        # Tenta pelo helper unificado com reset de status
        dispatched = _dispatch_supabase_otp(email)
        if dispatched:
            return JsonResponse({'status': 'success', 'message': 'Código de recuperação enviado para seu e-mail.'})

        # Fallback direto via rota /recover com service role
        supabase_url, service_key = _get_supabase_config()
        url = f"{supabase_url}/auth/v1/recover"
        headers = _auth_headers(service_key)
        res = requests.post(url, headers=headers, json={'email': email}, timeout=6)
        if res.status_code == 200:
            return JsonResponse({'status': 'success', 'message': 'Código de recuperação enviado para seu e-mail.'})

        return JsonResponse({'error': 'Não foi possível enviar o código de recuperação.'}, status=res.status_code)
    except Exception as e:
        logger.error(f"[Auth Bridge] Erro ao recuperar senha para {email}: {e}")
        return JsonResponse({'error': 'Erro interno ao solicitar recuperação de senha.'}, status=500)


@csrf_exempt
@require_POST
@ratelimit(key='ip', rate='10/m', block=True)
def resend_code(request):
    """
    Reenvia o código OTP para validação de e-mail ou recuperação.
    """
    try:
        data = json.loads(request.body)
    except (json.JSONDecodeError, ValueError):
        return JsonResponse({'error': 'Requisição inválida.'}, status=400)

    email = (data.get('email') or '').strip().lower()
    otp_type = data.get('type') or 'signup'

    if not email:
        return JsonResponse({'error': 'Informe o e-mail para reenviar o código.'}, status=400)

    try:
        supabase_url, service_key = _get_supabase_config()
        url = f"{supabase_url}/auth/v1/resend"
        headers = _auth_headers(service_key)
        res = requests.post(url, headers=headers, json={'email': email, 'type': otp_type}, timeout=6)

        if res.status_code == 200:
            return JsonResponse({'status': 'success', 'message': 'Código reenviado com sucesso!'})

        res_json = res.json() if res.content else {}
        return JsonResponse({'error': res_json.get('msg') or 'Falha ao reenviar código.'}, status=res.status_code)
    except Exception as e:
        logger.error(f"[Auth Bridge] Erro ao reenviar código para {email}: {e}")
        return JsonResponse({'error': 'Erro interno ao reenviar código.'}, status=500)
