import json
import re

import openai
from app.ai.exceptions import (
    AuthenticationError,
    NetworkError,
    RateLimitError,
    ServiceUnavailableError,
    StructuredOutputError,
    TimeoutError,
)
from app.ai.providers.base import BaseProvider
from app.core.config import settings
from openai import OpenAI
from pydantic import BaseModel


class GroqProvider(BaseProvider):
    """
    Provider para Groq utilizando cliente OpenAI compatível.
    """
    def __init__(self):
        if not settings.GROQ_API_KEY:
            raise AuthenticationError("GROQ_API_KEY não configurada.")
        self.client = OpenAI(
            api_key=settings.GROQ_API_KEY,
            base_url="https://api.groq.com/openai/v1",
            timeout=6.0
        )

    def _map_exception(self, e: Exception) -> Exception:
        from app.ai.exceptions import AIProviderError
        if isinstance(e, openai.RateLimitError):
            # 413 (request too large) = erro fatal para este modelo, nao faz retry
            err_str = str(e)
            if "413" in err_str or "too large" in err_str.lower() or "request too large" in err_str.lower():
                return AIProviderError(f"Prompt excede limite de tokens do modelo: {e}")
            return RateLimitError(str(e))
        elif isinstance(e, openai.AuthenticationError):
            return AuthenticationError(str(e))
        elif isinstance(e, openai.APITimeoutError):
            return TimeoutError(str(e))
        elif isinstance(e, openai.APIConnectionError):
            return NetworkError(str(e))
        elif isinstance(e, openai.InternalServerError):
            return ServiceUnavailableError(str(e))
        return AIProviderError(str(e))

    def _clean_content(self, content: str) -> str:
        # Remove tags <think> e seu conteúdo
        content = re.sub(r'<think>.*?</think>', '', content, flags=re.DOTALL)
        return content.strip()

    def generate_structured(self, prompt: str, schema: type[BaseModel], model_name: str, **kwargs) -> BaseModel:
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

        except openai.BadRequestError:
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
