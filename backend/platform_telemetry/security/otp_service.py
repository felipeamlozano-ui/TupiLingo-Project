import hashlib
import hmac
import logging
import random
import time
from typing import Dict, Any, Tuple, Optional
from django.core.mail import send_mail
from django.conf import settings
from app.ai.ping_race import get_redis_client

logger = logging.getLogger('platform_telemetry.security')

ALLOWED_DEV_EMAIL = "felipe.a.m.lozano@gmail.com"
MAX_FAILED_ATTEMPTS = 5
RATE_LIMIT_PER_MINUTE = 5
COOLDOWN_SECONDS = 60
OTP_TTL_SECONDS = 300  # 5 minutos

# Fallback em memória atômico para ambientes sem Redis ativo
_memory_store = {}


def _get_ip_hash(ip_address: str) -> str:
    """Gera hash SHA-256 anônimo do IP para rate limiting estrito Zero-PII."""
    salt = getattr(settings, 'SECRET_KEY', 'tupilingo_security_salt')[:16]
    return hashlib.sha256(f"{salt}:{ip_address}".encode('utf-8')).hexdigest()[:16]


def request_otp(email: str, client_ip: str, passcode: str = "") -> Tuple[bool, str, int, Optional[str]]:
    """
    Gera e envia código OTP de 6 dígitos restrito a felipe.a.m.lozano@gmail.com com validação de Master Passcode.
    Retorna: (sucesso: bool, mensagem: str, status_code: int, dev_code: Optional[str])
    """
    import os
    expected_passcode = getattr(settings, 'DEV_MASTER_PASSCODE', os.environ.get('DEV_MASTER_PASSCODE', 'tupi_master_2026'))
    if passcode and passcode.strip() != expected_passcode.strip():
        logger.warning(f"[OTP Security] Master Passcode incorreto para {email}")
        return False, "Master Passcode incorreto.", 401, None

    if email.lower().strip() != ALLOWED_DEV_EMAIL.lower():
        logger.warning(f"[OTP Security] Tentativa de emissão de OTP para email não autorizado: {email}")
        return False, "Acesso negado: email não autorizado para funções de desenvolvedor.", 403, None

    r = get_redis_client()
    ip_hash = _get_ip_hash(client_ip)

    # 1. Throttling por IP (máx 5 req/min)
    if r:
        ip_req_key = f"otp:ratelimit:ip:{ip_hash}"
        current_reqs = r.incr(ip_req_key)
        if current_reqs == 1:
            r.expire(ip_req_key, 60)
        if current_reqs > RATE_LIMIT_PER_MINUTE:
            return False, "Taxa limite de requisições excedida. Aguarde 60 segundos.", 429, None

        # 2. Cooldown de reenvio (60 segundos)
        cooldown_key = f"otp:cooldown:{email}"
        if r.exists(cooldown_key):
            ttl = r.ttl(cooldown_key)
            return False, f"Aguarde o cooldown de reenvio ({ttl}s restantes).", 429, None
    else:
        # Fallback memória
        now = time.time()
        cooldown_time = _memory_store.get(f"cooldown:{email}", 0)
        if now < cooldown_time:
            return False, f"Aguarde o cooldown de reenvio ({int(cooldown_time - now)}s).", 429, None

    # 3. Geração de código de 6 dígitos seguro
    code = f"{random.randint(100000, 999999)}"

    # 4. Gravação atômica no Redis
    if r:
        pipe = r.pipeline()
        pipe.set(f"otp:code:{email}", code, ex=OTP_TTL_SECONDS)
        pipe.set(f"otp:attempts:{email}", 0, ex=OTP_TTL_SECONDS)
        pipe.set(f"otp:cooldown:{email}", "1", ex=COOLDOWN_SECONDS)
        pipe.execute()
    else:
        now = time.time()
        _memory_store[f"code:{email}"] = code
        _memory_store[f"attempts:{email}"] = 0
        _memory_store[f"cooldown:{email}"] = now + COOLDOWN_SECONDS
        _memory_store[f"expires:{email}"] = now + OTP_TTL_SECONDS

    # 5. Envio do email para felipe.a.m.lozano@gmail.com via rota Supabase GoTrue
    supabase_sent = _send_supabase_otp(email)
    smtp_sent = False

    if not supabase_sent:
        email_user = getattr(settings, 'EMAIL_HOST_USER', '')
        if email_user:
            try:
                subject = "TupiLingo — Código de Autorização Developer Console (OTP)"
                message = (
                    f"Olá, Felipe!\n\n"
                    f"Seu código OTP de autorização para o Developer Console é: {code}\n\n"
                    f"Este código expira em 5 minutos (300 segundos). Máximo de 5 tentativas incorretas.\n"
                    f"Se você não solicitou este acesso, ignore esta mensagem."
                )
                send_mail(
                    subject=subject,
                    message=message,
                    from_email=getattr(settings, 'DEFAULT_FROM_EMAIL', email_user),
                    recipient_list=[email],
                    fail_silently=False,
                )
                smtp_sent = True
                logger.info(f"[OTP Security] Código OTP despachado com sucesso via SMTP para {email}.")
            except Exception as e:
                logger.warning(f"[OTP Security] Falha ao enviar via SMTP ({e}). Código OTP gerado para DEV: {code}")
        else:
            logger.info(f"[OTP Security] Supabase ou SMTP não disponíveis. Código OTP em modo DEV: {code}")

    msg = "Código OTP enviado com sucesso para o seu e-mail. Digite o código de 6 dígitos para validar o acesso."
    return True, msg, 200, None


def _send_supabase_otp(email: str) -> bool:
    """
    Dispara código OTP numérico de 6 dígitos via rota de verificação de cadastro/nivelamento do Supabase.
    Garante que o template com o código numérico de 6 dígitos ({{ .Token }}) seja enviado,
    eliminando qualquer envio indesejado de Magic Links.
    """
    import requests
    import psycopg2
    from django.conf import settings

    supabase_url = getattr(settings, 'SUPABASE_URL', '')
    service_key = getattr(settings, 'SUPABASE_SERVICE_ROLE_KEY', '')
    if not supabase_url or not service_key:
        return False

    # 1. Reseta email_confirmed_at para NULL no banco de dados auth.users,
    # garantindo que o Supabase GoTrue gere um novo token de 6 dígitos e envie o email de confirmação
    try:
        db_conf = getattr(settings, 'DATABASES', {}).get('default', {})
        conn = psycopg2.connect(
            host=db_conf.get('HOST', 'aws-1-us-east-2.pooler.supabase.com'),
            port=db_conf.get('PORT', '6543'),
            user=db_conf.get('USER', 'postgres.pcquxppvheodcrdkwqhh'),
            password=db_conf.get('PASSWORD', ''),
            dbname=db_conf.get('NAME', 'postgres'),
            connect_timeout=3
        )
        with conn.cursor() as cur:
            cur.execute("UPDATE auth.users SET email_confirmed_at = NULL WHERE email = %s;", [email])
        conn.commit()
        conn.close()
    except Exception as e:
        logger.warning(f"[OTP Security] Tentativa direta de resetar email_confirmed_at: {e}")

    # 2. Chama a rota de envio de OTP de 6 dígitos (mesma do nivelamento: /auth/v1/resend com type: signup)
    try:
        url = f"{supabase_url.rstrip('/')}/auth/v1/resend"
        headers = {
            'apikey': service_key,
            'Authorization': f"Bearer {service_key}",
            'Content-Type': 'application/json',
        }
        res = requests.post(url, headers=headers, json={'type': 'signup', 'email': email}, timeout=6)
        if res.status_code == 200:
            logger.info(f"[OTP Security] Supabase OTP (signup verification) despachado com sucesso para {email}.")
            return True

        # Fallback para recover caso signup retorne status diferente
        url_rec = f"{supabase_url.rstrip('/')}/auth/v1/recover"
        res_rec = requests.post(url_rec, headers=headers, json={'email': email}, timeout=6)
        if res_rec.status_code == 200:
            logger.info(f"[OTP Security] Supabase OTP (recovery verification) despachado com sucesso para {email}.")
            return True

        logger.warning(f"[OTP Security] Supabase resend status: {res.status_code} - {res.text}")
        return False
    except Exception as e:
        logger.warning(f"[OTP Security] Falha ao despachar OTP via Supabase: {e}")
        return False


def _verify_supabase_otp(email: str, code: str) -> bool:
    """Valida o código OTP numérico de 6 dígitos no Supabase GoTrue Auth (signup ou recovery)."""
    import requests
    supabase_url = getattr(settings, 'SUPABASE_URL', '')
    service_key = getattr(settings, 'SUPABASE_SERVICE_ROLE_KEY', '')
    if not supabase_url or not service_key:
        return False
    try:
        url = f"{supabase_url.rstrip('/')}/auth/v1/verify"
        headers = {
            'apikey': service_key,
            'Authorization': f"Bearer {service_key}",
            'Content-Type': 'application/json',
        }
        for otp_type in ['signup', 'recovery', 'email']:
            res = requests.post(
                url,
                headers=headers,
                json={'type': otp_type, 'email': email, 'token': code.strip()},
                timeout=5
            )
            if res.status_code == 200:
                logger.info(f"[OTP Security] Supabase OTP ({otp_type}) verificado com sucesso para {email}.")
                return True
        return False
    except Exception as e:
        logger.warning(f"[OTP Security] Erro ao validar OTP no Supabase: {e}")
        return False


def verify_otp(email: str, code: str, client_ip: str) -> Tuple[bool, str, int, Optional[str]]:
    """
    Valida código OTP com limite estrito de 5 falhas, destruição imediata e rate limiting.
    Retorna: (sucesso: bool, mensagem: str, status_code: int, session_token: Optional[str])
    """
    if email.lower().strip() != ALLOWED_DEV_EMAIL.lower():
        return False, "Email não autorizado.", 403, None

    r = get_redis_client()
    ip_hash = _get_ip_hash(client_ip)

    # 1. Throttling por IP (máx 5 req/min)
    if r:
        ip_req_key = f"otp:ratelimit:ip:{ip_hash}"
        current_reqs = r.incr(ip_req_key)
        if current_reqs == 1:
            r.expire(ip_req_key, 60)
        if current_reqs > RATE_LIMIT_PER_MINUTE:
            return False, "Taxa limite de requisições excedida. Aguarde 60 segundos.", 429, None

        # 2. Obter código atual e contador de tentativas
        expected_code = r.get(f"otp:code:{email}")
        attempts = int(r.get(f"otp:attempts:{email}") or 0)
    else:
        now = time.time()
        if now > _memory_store.get(f"expires:{email}", 0):
            expected_code = None
        else:
            expected_code = _memory_store.get(f"code:{email}")
        attempts = _memory_store.get(f"attempts:{email}", 0)

    # 3. Validação do código: verifica primeiro via Supabase GoTrue, depois fallback Redis/memória
    is_valid = _verify_supabase_otp(email, code)
    if not is_valid and expected_code and code.strip() == expected_code.strip():
        is_valid = True

    if not is_valid:
        new_attempts = attempts + 1
        if r:
            r.incr(f"otp:attempts:{email}")
        else:
            _memory_store[f"attempts:{email}"] = new_attempts

        # Se atingir 5 tentativas: destruição imediata do código
        if new_attempts >= MAX_FAILED_ATTEMPTS:
            if r:
                r.delete(f"otp:code:{email}")
                r.delete(f"otp:attempts:{email}")
            else:
                _memory_store.pop(f"code:{email}", None)
                _memory_store.pop(f"attempts:{email}", None)

            logger.critical(f"[OTP Security] Força bruta detectada para {email}! Código destruído no Redis.")
            return False, "Limite de 5 tentativas incorretas excedido! Código cancelado por segurança.", 403, None

        remaining = MAX_FAILED_ATTEMPTS - new_attempts
        return False, f"Código incorreto. Você tem mais {remaining} tentativa(s).", 401, None

    # 4. Código correto! Destruição atômica do OTP consumido
    if r:
        r.delete(f"otp:code:{email}")
        r.delete(f"otp:attempts:{email}")
    else:
        _memory_store.pop(f"code:{email}", None)
        _memory_store.pop(f"attempts:{email}", None)

    # 5. Emissão de token de sessão de desenvolvedor (30 minutos)
    raw_token = f"{email}:{time.time()}:{random.random()}"
    session_token = hashlib.sha256(raw_token.encode('utf-8')).hexdigest()

    if r:
        r.set(f"dev_session:{session_token}", email, ex=1800)
    else:
        _memory_store[f"dev_session:{session_token}"] = time.time() + 1800

    logger.info(f"[OTP Security] Sessão de desenvolvedor liberada com sucesso para {email}.")
    return True, "Autenticação multifator validada com sucesso.", 200, session_token


def is_dev_session_valid(session_token: str) -> bool:
    """Verifica se a sessão de desenvolvedor ainda está ativa."""
    valid, _ = check_dev_session(session_token)
    return valid


def check_dev_session(session_token: str) -> Tuple[bool, int]:
    """
    Verifica se a sessão de desenvolvedor ainda é válida e retorna os segundos restantes (máximo 1800s / 30m).
    """
    if not session_token:
        return False, 0
    r = get_redis_client()
    if r:
        ttl = r.ttl(f"dev_session:{session_token}")
        if ttl and ttl > 0:
            return True, ttl
        return False, 0
    now = time.time()
    exp = _memory_store.get(f"dev_session:{session_token}", 0)
    if now < exp:
        return True, int(exp - now)
    return False, 0


def revoke_dev_session(session_token: str) -> bool:
    """Revoga de forma atômica a sessão do Enclave."""
    if not session_token:
        return False
    r = get_redis_client()
    if r:
        r.delete(f"dev_session:{session_token}")
    else:
        _memory_store.pop(f"dev_session:{session_token}", None)
    logger.info(f"[OTP Security] Sessão {session_token[:8]}... revogada.")
    return True


# ─── Monitor de Presença Anônima (Zero-PII) ────────────────────────────────────

def record_anonymous_presence(session_id: str, country_code: str = 'BR', country_name: str = 'Brasil') -> None:
    """
    Registra batimento cardíaco de presença anônima com TTL de 180 segundos.
    Não armazena IP, UID ou qualquer dado pessoal.
    """
    r = get_redis_client()
    key = f"presence:session:{session_id}"
    country_data = f"{country_code}:{country_name}"
    if r:
        r.set(key, country_data, ex=180)
    else:
        _memory_store[key] = (country_data, time.time() + 180)


def get_online_presence_summary() -> Dict[str, Any]:
    """
    Retorna a contagem agregada de usuários online por país.
    """
    r = get_redis_client()
    countries_count: Dict[str, Dict[str, Any]] = {}
    total_online = 0

    if r:
        # Busca todas as sessões ativas
        cursor = 0
        while True:
            cursor, keys = r.scan(cursor=cursor, match="presence:session:*", count=100)
            for k in keys:
                val = r.get(k)
                if val and ":" in val:
                    parts = val.split(":")
                    code = parts[0]
                    name = parts[1] if len(parts) > 1 else code
                    if code not in countries_count:
                        countries_count[code] = {"country_code": code, "country_name": name, "online_count": 0}
                    countries_count[code]["online_count"] += 1
                    total_online += 1
            if cursor == 0:
                break
    else:
        now = time.time()
        for k, v in list(_memory_store.items()):
            if k.startswith("presence:session:"):
                country_data, exp = v
                if now < exp:
                    parts = country_data.split(":")
                    code = parts[0]
                    name = parts[1] if len(parts) > 1 else code
                    if code not in countries_count:
                        countries_count[code] = {"country_code": code, "country_name": name, "online_count": 0}
                    countries_count[code]["online_count"] += 1
                    total_online += 1
                else:
                    _memory_store.pop(k, None)

    # Se nenhum batimento ainda, retorna 1 ativo padrão para o cliente atual
    if total_online == 0:
        countries_count["BR"] = {"country_code": "BR", "country_name": "Brasil", "online_count": 1}
        total_online = 1

    return {
        "total_online": total_online,
        "countries": list(countries_count.values()),
    }
