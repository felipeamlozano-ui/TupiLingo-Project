"""
Serviço de Gerenciamento de Segredos via Supabase Vault (pgsodium).

Garante que chaves confidenciais de LLMs (Groq, Cerebras, Gemini) sejam
obtidas de forma segura e descriptografada em tempo de execução via RPC
no PostgreSQL/Supabase, sem permanecerem expostas em arquivos de texto claro.
Inclui cache em memória com TTL para evitar overhead de rede a cada inferência.
"""

from __future__ import annotations

import logging
import os
import time
from typing import ClassVar

from app.services.supabase_service import supabase_service

logger = logging.getLogger("app.services.vault_service")


class VaultService:
    """Interface de acesso ao Supabase Vault com fallback local transparente."""

    _cache: ClassVar[dict[str, tuple[str, float]]] = {}
    _CACHE_TTL_SECONDS: ClassVar[float] = 300.0  # 5 minutos

    @classmethod
    def get_secret(cls, secret_name: str, fallback_env_var: str | None = None) -> str | None:
        """
        Obtém um segredo descriptografado do Supabase Vault (pgsodium).
        1. Consulta cache em memória.
        2. Se expirado ou ausente, consulta a RPC get_secret no Supabase.
        3. Se falhar ou retornar nulo, utiliza fallback para variável de ambiente local.
        """
        now = time.monotonic()
        env_var_name = fallback_env_var or secret_name

        # 1. Verifica cache em memória
        if secret_name in cls._cache:
            val, expires_at = cls._cache[secret_name]
            if now < expires_at and val:
                return val

        # 2. Consulta Supabase Vault via RPC
        secret_val: str | None = None
        try:
            rpc_res = supabase_service.rpc("get_secret", {"secret_name": secret_name})
            if rpc_res and isinstance(rpc_res, str):
                secret_val = rpc_res.strip()
                logger.debug("[VaultService] Segredo '%s' obtido com sucesso do Supabase Vault.", secret_name)
        except Exception as exc:
            logger.debug("[VaultService] Consulta ao Vault para '%s' falhou (%s). Utilizando fallback.", secret_name, exc)

        # 3. Fallback para variável de ambiente local (dev/testes)
        if not secret_val:
            secret_val = os.environ.get(env_var_name)
            if not secret_val:
                try:
                    from decouple import config
                    secret_val = config(env_var_name, default=None)
                except Exception:
                    pass

        # 4. Atualiza cache se encontrou valor válido
        if secret_val:
            cls._cache[secret_name] = (secret_val, now + cls._CACHE_TTL_SECONDS)

        return secret_val

    @classmethod
    def clear_cache(cls) -> None:
        """Limpa o cache de segredos em memória."""
        cls._cache.clear()
