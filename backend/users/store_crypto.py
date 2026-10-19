"""
Camada Criptográfica da Loja de Conchas e Outbox de Lições Offline.
Protege contra adulteração de moedas, saldo forjado, requisições repetidas (replay attacks)
e manipulação de dados em trânsito através de assinaturas HMAC-SHA256 com timestamping e nonces.
"""

import hmac
import hashlib
import time
from django.conf import settings
from django.core.cache import cache

def _get_store_signing_key() -> bytes:
    """Gera chave de assinatura derivada da SECRET_KEY do Django."""
    base_secret = getattr(settings, 'SECRET_KEY', 'tupilingo_store_fallback_secret_key_2026')
    return hashlib.sha256(f"tupilingo_conchas_store_vault:{base_secret}".encode('utf-8')).digest()

def _get_outbox_signing_key() -> bytes:
    """Gera chave de assinatura específica para itens do Outbox offline."""
    base_secret = getattr(settings, 'SECRET_KEY', 'tupilingo_store_fallback_secret_key_2026')
    return hashlib.sha256(f"tupilingo_outbox_lesson_vault:{base_secret}".encode('utf-8')).digest()

def sign_store_state(user_id: int | str, conchas: int, timestamp: int) -> str:
    """
    Gera assinatura HMAC-SHA256 para o saldo de conchas e estado do usuário.
    Garante que o cliente não consiga alterar seu saldo localmente.
    """
    key = _get_store_signing_key()
    message = f"USER:{user_id}:CONCHAS:{conchas}:TS:{timestamp}".encode('utf-8')
    return hmac.new(key, message, hashlib.sha256).hexdigest()

def verify_store_state(user_id: int | str, conchas: int, timestamp: int, signature: str, max_age_seconds: int = 300) -> bool:
    """Valida assinatura do estado e rejeita requisições expiradas (anti-replay)."""
    now = int(time.time())
    if abs(now - timestamp) > max_age_seconds:
        return False
    expected = sign_store_state(user_id, conchas, timestamp)
    return hmac.compare_digest(expected, signature)

def sign_purchase_receipt(user_id: int | str, item_id: str, conchas_paid: int, new_balance: int, timestamp: int) -> str:
    """Gera recibo digital criptograficamente assinado pelo servidor."""
    key = _get_store_signing_key()
    message = f"RECEIPT:{user_id}:ITEM:{item_id}:PAID:{conchas_paid}:BAL:{new_balance}:TS:{timestamp}".encode('utf-8')
    return hmac.new(key, message, hashlib.sha256).hexdigest()

def sign_outbox_lesson(user_id: int | str, lesson_id: int, xp_earned: int, timestamp: int, nonce: str) -> str:
    """Gera assinatura HMAC-SHA256 canônica para o pacote de lição concluída offline."""
    key = _get_outbox_signing_key()
    message = f"OUTBOX:{user_id}:LESSON:{lesson_id}:XP:{xp_earned}:TS:{timestamp}:NONCE:{nonce}".encode('utf-8')
    return hmac.new(key, message, hashlib.sha256).hexdigest()

# Alias para compatibilidade
sign_lesson_completion = sign_outbox_lesson

def verify_outbox_lesson(
    user_id: int | str,
    lesson_id: int,
    xp_earned: int,
    timestamp: int,
    nonce: str,
    signature: str,
    max_age_seconds: int = 86400 * 30  # até 30 dias para lições offline legítimas
) -> bool:
    """
    Valida a integridade criptográfica do item sincronizado do Outbox.
    Rejeita pacotes adulterados ou timestamps no futuro distante.
    """
    if not signature or not nonce:
        return False

    now = int(time.time())
    # Rejeita pacotes enviados com timestamp no futuro (> 10 minutos)
    if (timestamp - now) > 600:
        return False

    # Rejeita lições mais velhas que o período máximo de retenção offline
    if (now - timestamp) > max_age_seconds:
        return False

    expected = sign_outbox_lesson(user_id, lesson_id, xp_earned, timestamp, nonce)
    return hmac.compare_digest(expected, signature)

def mark_nonce_used(nonce: str, ttl_seconds: int = 86400 * 7) -> bool:
    """
    Registra um nonce atomicamente no cache (Redis / LocMem).
    Retorna True se o nonce foi gravado com sucesso pela primeira vez.
    Retorna False se o nonce JÁ EXISTIA (tentativa de replay attack detectada).
    """
    if not nonce:
        return False
    cache_key = f"tupilingo:used_nonce:{nonce}"
    # cache.add() é atômico: retorna True se definiu a chave pela 1a vez, False se já existia
    was_set = cache.add(cache_key, "1", timeout=ttl_seconds)
    return bool(was_set)
