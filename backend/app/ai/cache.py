import hashlib
import json
from typing import Any

import redis
from app.core.config import settings


class PromptCache:
    """
    Sistema de Cache para chamadas de IA.
    Evita chamadas redundantes armazenando a saída JSON estruturada para o mesmo prompt + modelo.
    """
    
    def __init__(self):
        self.enabled = settings.ENABLE_PROMPT_CACHE
        if self.enabled:
            try:
                self.redis_client = redis.from_url(settings.REDIS_URL, decode_responses=True)
            except Exception as e:
                print(f"Aviso: Falha ao conectar no Redis para Prompt Cache. Cache desativado. Erro: {e}")
                self.enabled = False

    def _generate_key(self, prompt: str, model_name: str) -> str:
        """Gera uma chave SHA-256 única para o prompt + modelo."""
        payload = f"{model_name}:{prompt}".encode()
        return "prompt_cache:" + hashlib.sha256(payload).hexdigest()

    def get(self, prompt: str, model_name: str) -> dict[str, Any] | None:
        if not self.enabled:
            return None
            
        key = self._generate_key(prompt, model_name)
        cached_data = self.redis_client.get(key)
        if cached_data:
            return json.loads(cached_data)
        return None

    def set(self, prompt: str, model_name: str, response_data: dict[str, Any]):
        if not self.enabled:
            return
            
        key = self._generate_key(prompt, model_name)
        # Store serialized JSON string
        self.redis_client.setex(
            key, 
            settings.PROMPT_CACHE_TTL, 
            json.dumps(response_data)
        )

prompt_cache = PromptCache()
