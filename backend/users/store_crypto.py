"""
Camada Criptográfica da Loja de Conchas (Demanda 2).
Protege contra adulteração de moedas, saldo forjado, requisições repetidas (replay attacks)
e manipulação de dados em trânsito através de assinaturas HMAC-SHA256 com timestamping.
"""

import hmac
import hashlib
import time
from django.conf import settings

def _get_store_signing_key() -> bytes:
    """Gera chave de assinatura derivada da SECRET_KEY do Django."""
    base_secret = getattr(settings, 'SECRET_KEY', 'tupilingo_store_fallback_secret_key_2026')
    return hashlib.sha256(f"tupilingo_conchas_store_vault:{base_secret}".encode('utf-8')).digest()

def sign_store_state(user_id: int, conchas: int, timestamp: int) -> str:
    """
    Gera assinatura HMAC-SHA256 para o saldo de conchas e estado do usuário.
    Garante que o cliente não consiga alterar seu saldo localmente.
    """
    key = _get_store_signing_key()
    message = f"USER:{user_id}:CONCHAS:{conchas}:TS:{timestamp}".encode('utf-8')
    return hmac.new(key, message, hashlib.sha256).hexdigest()

def verify_store_state(user_id: int, conchas: int, timestamp: int, signature: str, max_age_seconds: int = 300) -> bool:
    """Valida assinatura do estado e rejeita requisições expiradas (anti-replay)."""
    now = int(time.time())
    if abs(now - timestamp) > max_age_seconds:
        return False
    expected = sign_store_state(user_id, conchas, timestamp)
    return hmac.compare_digest(expected, signature)

def sign_purchase_receipt(user_id: int, item_id: str, conchas_paid: int, new_balance: int, timestamp: int) -> str:
    """Gera recibo digital criptograficamente assinado pelo servidor."""
    key = _get_store_signing_key()
    message = f"RECEIPT:{user_id}:ITEM:{item_id}:PAID:{conchas_paid}:BAL:{new_balance}:TS:{timestamp}".encode('utf-8')
    return hmac.new(key, message, hashlib.sha256).hexdigest()
