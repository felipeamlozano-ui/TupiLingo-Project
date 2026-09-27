import json
import re
from typing import Type
from pydantic import BaseModel
from openai import OpenAI
import openai

from app.core.config import settings
from app.ai.providers.base import BaseProvider
from app.ai.exceptions import (
    RateLimitError, TimeoutError, AuthenticationError,
    ServiceUnavailableError, NetworkError, StructuredOutputError, AIProviderError,
    FatalModelError, TransientModelError, ModelNotFoundError, QuotaExhaustedError,
    ContextWindowExceededError
)

class GroqProvider(BaseProvider):
    """
    Provider para Groq utilizando cliente OpenAI compatível.
    """
    def __init__(self):
        from app.services.vault_service import VaultService
        api_key = VaultService.get_secret("GROQ_API_KEY", fallback_env_var="GROQ_API_KEY") or settings.GROQ_API_KEY
        if not api_key:
            raise AuthenticationError("GROQ_API_KEY não configurada.")
        self.client = OpenAI(
            api_key=api_key,
            base_url="https://api.groq.com/openai/v1",
            timeout=6.0
        )

    def _map_exception(self, e: Exception) -> Exception:
        if isinstance(e, openai.NotFoundError):
            return ModelNotFoundError(str(e))
        elif isinstance(e, openai.PermissionDeniedError):
            return QuotaExhaustedError(str(e))
        elif isinstance(e, openai.AuthenticationError):
            return AuthenticationError(str(e))
        elif isinstance(e, openai.RateLimitError):
            err_str = str(e).lower()
            if "413" in err_str or "too large" in err_str or "request too large" in err_str:
                return ContextWindowExceededError(f"Prompt excede limite de tokens do modelo: {e}")
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
            elif e.status_code == 413:
                return ContextWindowExceededError(str(e))
            elif e.status_code == 429:
                return RateLimitError(str(e))
            elif e.status_code in (500, 502, 503, 504):
                return ServiceUnavailableError(str(e))

        err_msg = str(e).lower()
        if "404" in err_msg or "not found" in err_msg or "model not exist" in err_msg or "invalid model" in err_msg:
            return ModelNotFoundError(str(e))
        if "413" in err_msg or "too large" in err_msg:
            return ContextWindowExceededError(str(e))
        if "402" in err_msg or "403" in err_msg or "payment" in err_msg or "quota" in err_msg:
            return QuotaExhaustedError(str(e))
        if "401" in err_msg or "unauthorized" in err_msg:
            return AuthenticationError(str(e))
        if "429" in err_msg or "rate limit" in err_msg:
            return RateLimitError(str(e))

        return AIProviderError(str(e))

    def _clean_content(self, content: str) -> str:
        # Remove tags <think> e seu conteúdo
        content = re.sub(r'<think>.*?</think>', '', content, flags=re.DOTALL)
        return content.strip()

    def generate_structured(self, prompt: str, schema: Type[BaseModel], model_name: str, **kwargs) -> BaseModel:
        base_params = dict(
            model=model_name,
            messages=[{"role": "user", "content": prompt}],
            temperature=kwargs.get("temperature", 0.1),
            max_tokens=kwargs.get("max_tokens", 2048),
        )

        def _parse(content: str) -> BaseModel:
            content = self._clean_content(content)
            if not content:
                raise StructuredOutputError("Resposta vazia do modelo.")
            # Tenta parse direto
            try:
                return schema(**json.loads(content))
            except (json.JSONDecodeError, ValueError):
                pass
            # Extração manual do bloco { ... }
            match = re.search(r'\{.*\}', content, re.DOTALL)
            if match:
                try:
                    return schema(**json.loads(match.group(0)))
                except (json.JSONDecodeError, ValueError):
                    pass
            raise StructuredOutputError("Não foi possível extrair JSON válido da resposta.")

        try:
            # Estratégia 1: response_format=json_object (gpt-oss-20b, gpt-oss-120b)
            response = self.client.chat.completions.create(
                **base_params,
                response_format={"type": "json_object"},
            )
            return _parse(response.choices[0].message.content or "")

        except openai.BadRequestError as e:
            # Estratégia 2: sem response_format (qwen e outros que rejeitam json_object)
            # Alguns modelos rejeitam json_object com 400 — tentamos sem e extraímos manualmente
            try:
                response = self.client.chat.completions.create(**base_params)
                return _parse(response.choices[0].message.content or "")
            except Exception as inner_e:
                raise self._map_exception(inner_e)

        except Exception as e:
            raise self._map_exception(e)

    def generate_text(self, prompt: str, model_name: str, **kwargs) -> str:
        try:
            response = self.client.chat.completions.create(
                model=model_name,
                messages=[{"role": "user", "content": prompt}],
                temperature=kwargs.get("temperature", 0.7),
            )
            content = response.choices[0].message.content or ""
            return self._clean_content(content)
        except Exception as e:
            raise self._map_exception(e)
