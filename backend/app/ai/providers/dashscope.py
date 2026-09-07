import json
import logging
import re
from typing import Type
from pydantic import BaseModel
from openai import OpenAI
import openai

from app.core.config import settings
from app.ai.providers.base import BaseProvider
from app.ai.exceptions import (
    RateLimitError, TimeoutError, AuthenticationError,
    ServiceUnavailableError, NetworkError, StructuredOutputError, AIProviderError
)

logger = logging.getLogger(__name__)

class DashScopeProvider(BaseProvider):
    """
    Provider para Alibaba Cloud (Model Studio / DashScope).
    Utiliza endpoint compatível com OpenAI (https://dashscope-intl.aliyuncs.com/compatible-mode/v1).
    """
    def __init__(self):
        api_key = settings.DASHSCOPE_API_KEY
        if not api_key:
            raise AuthenticationError("DASHSCOPE_API_KEY não configurada.")
        self.client = OpenAI(
            api_key=api_key,
            base_url=settings.DASHSCOPE_BASE_URL,
            timeout=15.0
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
        
        err_msg = str(e).lower()
        if "402" in err_msg or "quota" in err_msg or "rate limit" in err_msg or "payment" in err_msg:
            return RateLimitError(str(e))

        return AIProviderError(str(e))

    def generate_structured(self, prompt: str, schema: Type[BaseModel], model_name: str, **kwargs) -> BaseModel:
        try:
            # Solicita formato JSON para o modelo
            try:
                response = self.client.chat.completions.create(
                    model=model_name,
                    messages=[{"role": "user", "content": prompt}],
                    response_format={"type": "json_object"},
                    temperature=kwargs.get("temperature", 0.1),
                    max_tokens=kwargs.get("max_tokens", 2048)
                )
            except Exception:
                # Fallback sem response_format estrito caso o modelo específico não o suporte
                response = self.client.chat.completions.create(
                    model=model_name,
                    messages=[{"role": "user", "content": prompt}],
                    temperature=kwargs.get("temperature", 0.1),
                    max_tokens=kwargs.get("max_tokens", 2048)
                )

            content = response.choices[0].message.content or ""
            # Limpa possíveis blocos <think>...</think> de modelos reasoning
            content = re.sub(r'<think>.*?</think>', '', content, flags=re.DOTALL).strip()
            
            if not content:
                raise StructuredOutputError("Resposta vazia do modelo DashScope.")

            # 1. Parse JSON direto
            try:
                parsed = json.loads(content)
                return schema(**parsed)
            except Exception:
                pass

            # 2. Extração via regex de bloco markdown ```json { ... } ```
            match = re.search(r'```(?:json)?\s*(\{.*?\})\s*```', content, re.DOTALL) or re.search(r'\{.*\}', content, re.DOTALL)
            if match:
                try:
                    parsed = json.loads(match.group(1) if match.lastindex else match.group(0))
                    return schema(**parsed)
                except Exception:
                    pass

            # 3. Heurística direta se for ItemCategory / Categoria
            for cat in ["Vocabulário", "Gramática", "História", "Mitologia", "Desconhecido"]:
                if cat.lower() in content.lower():
                    try:
                        return schema(categoria=cat)
                    except Exception:
                        pass

            raise StructuredOutputError(f"Falha ao validar JSON retornado por DashScope ({model_name}): {content[:150]}")

        except Exception as e:
            raise self._map_exception(e)

    def generate_text(self, prompt: str, model_name: str, **kwargs) -> str:
        try:
            response = self.client.chat.completions.create(
                model=model_name,
                messages=[{"role": "user", "content": prompt}],
                temperature=kwargs.get("temperature", 0.7),
                max_tokens=kwargs.get("max_tokens", 2048)
            )
            content = response.choices[0].message.content or ""
            return re.sub(r'<think>.*?</think>', '', content, flags=re.DOTALL).strip()
        except Exception as e:
            raise self._map_exception(e)
