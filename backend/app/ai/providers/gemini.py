import json
from typing import Type
from pydantic import BaseModel
from google import genai
from google.genai import types
from google.genai.errors import APIError

from app.core.config import settings
from app.ai.providers.base import BaseProvider
from app.ai.exceptions import (
    RateLimitError, TimeoutError, AuthenticationError,
    ServiceUnavailableError, NetworkError, StructuredOutputError
)

class GeminiProvider(BaseProvider):
    """
    Provider para Google Gemini usando google-genai SDK.
    """
    def __init__(self):
        if not settings.GEMINI_API_KEY:
            raise AuthenticationError("GEMINI_API_KEY não configurada.")
        self.client = genai.Client(api_key=settings.GEMINI_API_KEY)

    def _map_exception(self, e: Exception) -> Exception:
        if isinstance(e, APIError):
            if e.code == 429:
                return RateLimitError(str(e))
            elif e.code in (401, 403):
                return AuthenticationError(str(e))
            elif e.code in (500, 503):
                return ServiceUnavailableError(str(e))
            elif e.code == 504:
                return TimeoutError(str(e))
        return NetworkError(str(e))

    def generate_structured(self, prompt: str, schema: Type[BaseModel], model_name: str, **kwargs) -> BaseModel:
        try:
            response = self.client.models.generate_content(
                model=model_name,
                contents=prompt,
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    response_schema=schema,
                    temperature=kwargs.get("temperature", 0.1),
                ),
            )
            content = response.text
            if not content:
                raise StructuredOutputError("Resposta vazia do modelo Gemini.")
            
            try:
                parsed = json.loads(content)
                return schema(**parsed)
            except (json.JSONDecodeError, ValueError) as ve:
                raise StructuredOutputError(f"Gemini falhou ao processar JSON: {ve}")
                
        except Exception as e:
            raise self._map_exception(e)

    def generate_text(self, prompt: str, model_name: str, **kwargs) -> str:
        try:
            response = self.client.models.generate_content(
                model=model_name,
                contents=prompt,
                config=types.GenerateContentConfig(
                    temperature=kwargs.get("temperature", 0.7),
                ),
            )
            return response.text or ""
        except Exception as e:
            raise self._map_exception(e)
