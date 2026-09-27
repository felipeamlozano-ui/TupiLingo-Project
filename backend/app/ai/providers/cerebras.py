import json
from typing import Type
from pydantic import BaseModel
from openai import OpenAI
import openai

from app.core.config import settings
from app.ai.providers.base import BaseProvider
from app.ai.exceptions import (
    RateLimitError, TimeoutError, AuthenticationError,
    ServiceUnavailableError, NetworkError, StructuredOutputError, AIProviderError,
    FatalModelError, TransientModelError, ModelNotFoundError, QuotaExhaustedError
)

class CerebrasProvider(BaseProvider):
    """
    Provider para Cerebras Cloud.
    """
    def __init__(self):
        from app.services.vault_service import VaultService
        api_key = VaultService.get_secret("CEREBRAS_API_KEY", fallback_env_var="CEREBRAS_API_KEY") or settings.CEREBRAS_API_KEY
        if not api_key:
            raise AuthenticationError("CEREBRAS_API_KEY não configurada.")
        self.client = OpenAI(
            api_key=api_key,
            base_url="https://api.cerebras.ai/v1",
            timeout=10.0
        )

    def _map_exception(self, e: Exception) -> Exception:
        if isinstance(e, openai.NotFoundError):
            return ModelNotFoundError(str(e))
        elif isinstance(e, openai.PermissionDeniedError):
            return QuotaExhaustedError(str(e))
        elif isinstance(e, openai.AuthenticationError):
            return AuthenticationError(str(e))
        elif isinstance(e, openai.RateLimitError):
            return RateLimitError(str(e))
        elif isinstance(e, openai.APITimeoutError):
            return TimeoutError(str(e))
        elif isinstance(e, openai.APIConnectionError):
            return NetworkError(str(e))
        elif isinstance(e, openai.InternalServerError):
            return ServiceUnavailableError(str(e))
        elif isinstance(e, openai.APIStatusError):
            if e.status_code == 404:
                return ModelNotFoundError(str(e))
            elif e.status_code == 401:
                return AuthenticationError(str(e))
            elif e.status_code in (402, 403):
                return QuotaExhaustedError(str(e))
            elif e.status_code == 429:
                return RateLimitError(str(e))
            elif e.status_code in (500, 502, 503, 504):
                return ServiceUnavailableError(str(e))

        err_msg = str(e).lower()
        if "404" in err_msg or "not found" in err_msg or "model not exist" in err_msg or "invalid model" in err_msg:
            return ModelNotFoundError(str(e))
        if "402" in err_msg or "403" in err_msg or "payment" in err_msg or "quota" in err_msg:
            return QuotaExhaustedError(str(e))
        if "401" in err_msg or "unauthorized" in err_msg:
            return AuthenticationError(str(e))
        if "429" in err_msg or "rate limit" in err_msg:
            return RateLimitError(str(e))

        return AIProviderError(str(e))


    def generate_structured(self, prompt: str, schema: Type[BaseModel], model_name: str, **kwargs) -> BaseModel:
        try:
            response = self.client.chat.completions.create(
                model=model_name,
                messages=[{"role": "user", "content": prompt}],
                response_format={"type": "json_object"},
                temperature=kwargs.get("temperature", 0.1),
                max_tokens=kwargs.get("max_tokens", 2048)
            )
            content = response.choices[0].message.content
            if not content:
                raise StructuredOutputError("Resposta vazia do modelo.")
            
            try:
                parsed = json.loads(content)
                return schema(**parsed)
            except (json.JSONDecodeError, ValueError) as ve:
                raise StructuredOutputError(f"Falha ao processar JSON: {ve}")
                
        except Exception as e:
            raise self._map_exception(e)

    def generate_text(self, prompt: str, model_name: str, **kwargs) -> str:
        try:
            response = self.client.chat.completions.create(
                model=model_name,
                messages=[{"role": "user", "content": prompt}],
                temperature=kwargs.get("temperature", 0.7),
            )
            return response.choices[0].message.content or ""
        except Exception as e:
            raise self._map_exception(e)
