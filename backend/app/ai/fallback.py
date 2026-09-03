"""
TupiLingo — Fallback Orchestrator (RFC v3.0)

Executa a cadeia de fallback de modelos LLM com política Fail-Fast:
  - Timeout por chamada: 2.5 s
  - Máximo de 1 retry por modelo
  - Sem exponential backoff
  - Failover imediato para o próximo modelo na cadeia

Registra provedor, modelo e motivo do failover em cada troca.
"""

from __future__ import annotations

import logging
import time
from typing import Type

from pydantic import BaseModel
from tenacity import (
    RetryError,
    retry,
    retry_if_exception_type,
    stop_after_attempt,
    wait_none,
)

from app.core.config import settings
from app.ai.invoker import AIInvoker
from app.ai.exceptions import (
    AIProviderError,
    NetworkError,
    ProviderNotFoundError,
    RateLimitError,
    ServiceUnavailableError,
    TimeoutError,
)
from app.ai.ping_race import PingRaceRouter

logger = logging.getLogger(__name__)

# Exceções que justificam um único retry imediato no MESMO modelo
_RETRYABLE: tuple[type[Exception], ...] = (
    RateLimitError,
    TimeoutError,
    NetworkError,
    ServiceUnavailableError,
)


class FallbackOrchestrator:
    """
    Orquestrador de fallback entre provedores/modelos LLM.

    Política RFC v3.0 (Fail-Fast):
      - Cada modelo tem no máximo 1 retry (2 tentativas totais).
      - Sem espera entre tentativas (``wait_none``).
      - Failover imediato para o próximo modelo da cadeia.
      - Registra provedor + modelo + motivo em cada failover.
    """

    @classmethod
    def execute_with_fallback(
        cls,
        prompt: str,
        schema: Type[BaseModel],
        chain: list[str] | None = None,
        **kwargs: object,
    ) -> BaseModel:
        """
        Tenta gerar a resposta estruturada percorrendo a cadeia de modelos.

        Args:
            prompt: Prompt completo a ser enviado ao modelo.
            schema: Classe Pydantic que valida a saída da LLM.
            chain: Lista de alvos no formato ``"provider/model_name"``.
                   Se None, usa ``settings.FALLBACK_CHAIN``.
            **kwargs: Argumentos adicionais passados ao provider
                      (ex: ``temperature``, ``max_tokens``).

        Returns:
            Instância do ``schema`` validada via Pydantic.

        Raises:
            Exception: Quando todos os modelos da cadeia falham.
        """
        model_chain = chain or list(settings.FALLBACK_CHAIN)
        last_exception: Exception | None = None
        t_start = time.monotonic()

        # RFC v3.0: Filtra modelos que já estão em cooldown (penalizados por 429 ou erro recente)
        # Evita desperdiçar requisições ou tomar 429 repetidamente no mesmo modelo
        active_chain = [m for m in model_chain if not PingRaceRouter.is_in_cooldown(m)]
        if not active_chain:
            logger.info(
                "[FallbackOrchestrator] Todos os modelos da cadeia (%d) estão em cooldown. Resetando penalidades.",
                len(model_chain),
            )
            PingRaceRouter._cooldown_map.clear()
            active_chain = list(model_chain)

        for target in active_chain:
            try:
                provider_name, model_name = target.split("/", 1)
            except ValueError:
                logger.error(
                    "[FallbackOrchestrator] Formato de alvo inválido: '%s'. "
                    "Esperado 'provider/modelo'. Ignorando.",
                    target,
                )
                continue

            t_model = time.monotonic()
            try:
                result = cls._invoke_with_single_retry(
                    provider_name, model_name, prompt, schema, **kwargs
                )
                latency_ms = int((time.monotonic() - t_model) * 1000)
                PingRaceRouter.record_success(target)
                logger.info(
                    "[FallbackOrchestrator] ✓ Sucesso via %s/%s em %d ms.",
                    provider_name,
                    model_name,
                    latency_ms,
                )
                return result

            except ProviderNotFoundError:
                logger.warning(
                    "[FallbackOrchestrator] Provedor '%s' inativo/inexistente. "
                    "Failover → próximo modelo.",
                    provider_name,
                )
                continue

            except RetryError as exc:
                # Único retry esgotado
                latency_ms = int((time.monotonic() - t_model) * 1000)
                inner = exc.last_attempt.exception()
                PingRaceRouter.record_failure(target)
                logger.warning(
                    "[FallbackOrchestrator] ✗ %s/%s falhou após retry em %d ms "
                    "[%s: %s]. Failover → próximo.",
                    provider_name,
                    model_name,
                    latency_ms,
                    type(inner).__name__,
                    str(inner)[:200],
                )
                last_exception = inner or exc
                continue

            except (AIProviderError, Exception) as exc:
                latency_ms = int((time.monotonic() - t_model) * 1000)
                PingRaceRouter.record_failure(target)
                logger.error(
                    "[FallbackOrchestrator] ✗ %s/%s erro fatal em %d ms "
                    "[%s: %s]. Failover → próximo.",
                    provider_name,
                    model_name,
                    latency_ms,
                    type(exc).__name__,
                    str(exc)[:200],
                )
                last_exception = exc
                continue

        total_ms = int((time.monotonic() - t_start) * 1000)
        raise RuntimeError(
            f"Todos os provedores da cadeia falharam após {total_ms} ms. "
            f"Último erro: {last_exception}"
        )

    @classmethod
    @retry(
        stop=stop_after_attempt(2),       # 1 tentativa original + 1 retry = 2 total
        wait=wait_none(),                  # sem espera — Fail-Fast
        retry=retry_if_exception_type(_RETRYABLE),
        reraise=False,                     # propaga via RetryError para logging preciso
    )
    def _invoke_with_single_retry(
        cls,
        provider_name: str,
        model_name: str,
        prompt: str,
        schema: Type[BaseModel],
        **kwargs: object,
    ) -> BaseModel:
        """Executa uma única chamada ao provider com 1 retry em caso de erro transitório. Usa LiteLLM por baixo."""
        import litellm
        from litellm.exceptions import (
            RateLimitError as LiteLLMRateLimit,
            Timeout as LiteLLMTimeout,
            APIConnectionError as LiteLLMConnection,
            ServiceUnavailableError as LiteLLMServiceUnavailable,
            BadRequestError as LiteLLMBadRequest,
        )
        import json
        import re

        full_model = f"{provider_name}/{model_name}"
        messages = [{"role": "user", "content": prompt}]
        
        try:
            # 1. Tenta com response_format (Pydantic ou JSON mode)
            try:
                response = litellm.completion(
                    model=full_model,
                    messages=messages,
                    response_format=schema,
                    **kwargs
                )
            except LiteLLMBadRequest:
                # Caso o provider/modelo não suporte response_format / tools, tenta completion de texto puro
                response = litellm.completion(
                    model=full_model,
                    messages=messages,
                    **kwargs
                )

            content = response.choices[0].message.content or ""
            # Limpa tags think caso modelo reasoning seja usado
            content = re.sub(r'<think>.*?</think>', '', content, flags=re.DOTALL).strip()
            
            try:
                return schema.model_validate_json(content)
            except Exception:
                # 1. Fallback regex block ```json { ... } ``` ou { ... }
                match = re.search(r'```(?:json)?\s*(\{.*?\})\s*```', content, re.DOTALL) or re.search(r'\{[^{}]*\}', content, re.DOTALL)
                if match:
                    try:
                        raw_json = match.group(1) if match.lastindex else match.group(0)
                        return schema.model_validate_json(raw_json)
                    except Exception:
                        pass

                # 2. Heurística de extração direta de campos literais se presente
                for cat in ["Vocabulário", "Gramática", "História", "Mitologia", "Desconhecido"]:
                    if cat.lower() in content.lower():
                        try:
                            return schema(categoria=cat)
                        except Exception:
                            pass

                raise AIProviderError(f"Não foi possível extrair JSON válido da resposta do modelo: {content[:100]}")
                
        except LiteLLMRateLimit as e:
            raise RateLimitError(str(e))
        except LiteLLMTimeout as e:
            raise TimeoutError(str(e))
        except LiteLLMConnection as e:
            raise NetworkError(str(e))
        except LiteLLMServiceUnavailable as e:
            raise ServiceUnavailableError(str(e))
        except Exception as e:
            # Fallback for internal registered providers if litellm fails with auth or unknown
            try:
                from app.ai.registry import registry
                if provider_name in registry._providers:
                    return AIInvoker.invoke_structured(
                        provider_name, model_name, prompt, schema, **kwargs
                    )
            except Exception:
                pass
            raise AIProviderError(f"Erro LiteLLM/Invoker: {str(e)}")
