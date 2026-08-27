import json
from typing import Type
from pydantic import BaseModel
from openai import OpenAI
import openai

from app.core.config import settings
from app.ai.providers.base import BaseProvider
from app.ai.exceptions import (
    RateLimitError, TimeoutError, AuthenticationError,
    ServiceUnavailableError, NetworkError, StructuredOutputError
)

class CerebrasProvider(BaseProvider):
    """
    Provider para Cerebras Cloud.
    """
    def __init__(self):
        if not settings.CEREBRAS_API_KEY:
            raise AuthenticationError("CEREBRAS_API_KEY não configurada.")
        self.client = OpenAI(
            api_key=settings.CEREBRAS_API_KEY,
            base_url="https://api.cerebras.ai/v1",
            timeout=10.0
        )

    def _map_exception(self, e: Exception) -> Exception:
        if isinstance(e, openai.RateLimitError):
            return RateLimitError(str(e))
        elif isinstance(e, openai.AuthenticationError):
            return AuthenticationError(str(e))
        elif isinstance(e, openai.APITimeoutError):
            return TimeoutError(str(e))
        elif isinstance(e, openai.APIConnectionError):
            return NetworkError(str(e))
        elif isinstance(e, openai.InternalServerError):
            return ServiceUnavailableError(str(e))
        from app.ai.exceptions import AIProviderError
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
