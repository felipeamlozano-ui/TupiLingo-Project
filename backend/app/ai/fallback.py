"""
TupiLingo — Fallback Orchestrator (RFC v3.0 Fail-Fast por Modelo)

Executa a cadeia de fallback de modelos LLM sobre a lista ranqueada do PingRaceRouter:
  - Política Fail-Fast por Modelo: 1 tentativa por modelo (stop_after_attempt(1)).
    Isso significa: NUNCA insiste no mesmo modelo após timeout, 429 ou esgotamento de cota.
    Em vez de re-tentar o mesmo modelo falho por 5-10s, faz failover IMEDIATO para o próximo do ranking.
  - Itera sobre todos os modelos ranqueados até esgotar a lista ou obter sucesso.
  - Se todos os modelos falharem, lança explicitamente AllModelsUnavailableError com detalhes
    de telemetria, nunca retornando None silencioso ou mascarando a falha.
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

# Compatibilidade retroativa para mocks de teste legados
wait_exponential_jitter = wait_none

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

# Exceções que indicam falha no modelo
_RETRYABLE: tuple[type[Exception], ...] = (
    RateLimitError,
    TimeoutError,
    NetworkError,
    ServiceUnavailableError,
)


class AllModelsUnavailableError(AIProviderError):
    """Exceção explícita lançada quando TODOS os modelos da cadeia de inferência falham."""
    pass


class FallbackOrchestrator:
    """
    Orquestrador Fail-Fast de inferência estruturada entre provedores/modelos LLM.
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
        Tenta gerar a resposta estruturada percorrendo a cadeia ranqueada pelo PingRace.

        Args:
            prompt: Prompt completo a ser enviado ao modelo.
            schema: Classe Pydantic que valida a saída da LLM.
            chain: Lista de alvos no formato "provider/model_name".
                   Se None, usa settings.FALLBACK_CHAIN.
            **kwargs: Argumentos adicionais passados ao provider (temperature, max_tokens).

        Returns:
            Instância do schema validada via Pydantic.

        Raises:
            AllModelsUnavailableError: Quando todos os modelos da cadeia falham.
        """
        base_chain = chain or list(settings.FALLBACK_CHAIN)
        t_start = time.monotonic()
        errors_history: dict[str, str] = {}

        # ── OBTÉM RANKING DO PINGRACE GLOBAL (SWR NO REDIS) ───────────────────
        # GANHO DE PERFORMANCE: Obtém ranking compartilhado já ordenado pelo menor tempo de resposta
        try:
            ranked_chain = PingRaceRouter.get_ranked_models(base_chain)
        except Exception as race_exc:
            logger.warning("[FallbackOrchestrator] Falha ao obter ranking PingRace (%s). Usando base.", race_exc)
            ranked_chain = list(base_chain)

        # Filtra modelos que não estejam em cooldown ativo
        active_chain = [m for m in ranked_chain if not PingRaceRouter.is_in_cooldown(m)]
        if not active_chain:
            logger.info(
                "[FallbackOrchestrator] Todos os modelos (%d) em cooldown. Resetando penalidades para tentativa de emergência.",
                len(ranked_chain),
            )
            active_chain = list(ranked_chain)

        logger.info("[FallbackOrchestrator] Iniciando cadeia de fallback com %d modelos: %s", len(active_chain), active_chain)

        # ── ITERAÇÃO FAIL-FAST POR MODELO ─────────────────────────────────────
        # Itera sobre a lista ranqueada. Se um modelo falhar, faz failover IMEDIATO
        # para o próximo sem repetir tentativas no mesmo modelo falho.
        for target in active_chain:
            try:
                provider_name, model_name = target.split("/", 1)
            except ValueError:
                logger.error("[FallbackOrchestrator] Alvo inválido: '%s'. Esperado 'provider/modelo'.", target)
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
                    provider_name, model_name, latency_ms,
                )
                return result

            except ProviderNotFoundError:
                logger.warning(
                    "[FallbackOrchestrator] Provedor '%s' inativo/inexistente. Failover → próximo modelo.",
                    provider_name,
                )
                errors_history[target] = "ProviderNotFoundError"
                continue

            except RetryError as exc:
                # 1 única tentativa executada; failover imediato para o próximo
                latency_ms = int((time.monotonic() - t_model) * 1000)
                inner = exc.last_attempt.exception()
                err_msg = f"{type(inner).__name__}: {str(inner)[:180]}"
                errors_history[target] = err_msg
                PingRaceRouter.record_failure(target)
                logger.warning(
                    "[FallbackOrchestrator] ✗ %s/%s falhou em %d ms [%s]. Failover imediato → próximo.",
                    provider_name, model_name, latency_ms, err_msg,
                )
                continue

            except (AIProviderError, Exception) as exc:
                latency_ms = int((time.monotonic() - t_model) * 1000)
                err_msg = f"{type(exc).__name__}: {str(exc)[:180]}"
                errors_history[target] = err_msg
                PingRaceRouter.record_failure(target)
                logger.error(
                    "[FallbackOrchestrator] ✗ %s/%s erro fatal em %d ms [%s]. Failover imediato → próximo.",
                    provider_name, model_name, latency_ms, err_msg,
                )
                continue

        # ── COMPORTAMENTO EXPLÍCITO DE ERRO ───────────────────────────────────
        # CRITÉRIO DE ACEITAÇÃO: Não retorna None nem omite a falha. Lança exceção tipada.
        total_ms = int((time.monotonic() - t_start) * 1000)
        error_summary = "; ".join(f"{k}: {v}" for k, v in errors_history.items())
        logger.critical(
            "[FallbackOrchestrator] 💥 Todos os %d modelos falharam após %d ms. Resumo: %s",
            len(active_chain), total_ms, error_summary,
        )
        raise AllModelsUnavailableError(
            f"Todos os provedores da cadeia falharam após {total_ms} ms. Detalhes: {error_summary}"
        )

    @classmethod
    @retry(
        # GANHO DE PERFORMANCE: stop_after_attempt(1) garante Fail-Fast por modelo.
        # Não re-tenta o mesmo modelo após falha (evita desperdiçar 4s-10s no mesmo endpoint falho).
        stop=stop_after_attempt(1),
        wait=wait_none(),
        retry=retry_if_exception_type(_RETRYABLE),
        reraise=False,
    )
    def _invoke_with_single_retry(
        cls,
        provider_name: str,
        model_name: str,
        prompt: str,
        schema: Type[BaseModel],
        **kwargs: object,
    ) -> BaseModel:
        """
        Executa 1 tentativa de chamada no modelo com suporte prioritário
        a provedores nativos do registry e fallback para LiteLLM.
        """
        from app.ai.registry import registry
        
        # 1. Prioriza provedor especializado registrado nativamente (DashScope, Cerebras, SambaNova, Groq, Gemini)
        if provider_name.lower() in registry._providers:
            return AIInvoker.invoke_structured(
                provider_name, model_name, prompt, schema, **kwargs
            )

        # 2. Se não estiver no registry nativo, executa via LiteLLM (ex: openrouter/*)
        import litellm
        from litellm.exceptions import (
            RateLimitError as LiteLLMRateLimit,
            Timeout as LiteLLMTimeout,
            APIConnectionError as LiteLLMConnection,
            ServiceUnavailableError as LiteLLMServiceUnavailable,
            BadRequestError as LiteLLMBadRequest,
        )
        import re

        full_model = f"{provider_name}/{model_name}"
        messages = [{"role": "user", "content": prompt}]
        
        try:
            try:
                response = litellm.completion(
                    model=full_model,
                    messages=messages,
                    response_format=schema,
                    **kwargs
                )
            except LiteLLMBadRequest:
                response = litellm.completion(
                    model=full_model,
                    messages=messages,
                    **kwargs
                )

            content = response.choices[0].message.content or ""
            content = re.sub(r'<think>.*?</think>', '', content, flags=re.DOTALL).strip()
            
            try:
                return schema.model_validate_json(content)
            except Exception:
                match = re.search(r'```(?:json)?\s*(\{.*?\})\s*```', content, re.DOTALL) or re.search(r'\{[^{}]*\}', content, re.DOTALL)
                if match:
                    try:
                        raw_json = match.group(1) if match.lastindex else match.group(0)
                        return schema.model_validate_json(raw_json)
                    except Exception:
                        pass

                for cat in ["Vocabulário", "Gramática", "História", "Mitologia", "Desconhecido"]:
                    if cat.lower() in content.lower():
                        try:
                            return schema(categoria=cat)
                        except Exception:
                            pass

                raise AIProviderError(f"Não foi possível extrair JSON válido de {full_model}: {content[:100]}")
                
        except LiteLLMRateLimit as e:
            raise RateLimitError(str(e))
        except LiteLLMTimeout as e:
            raise TimeoutError(str(e))
        except LiteLLMConnection as e:
            raise NetworkError(str(e))
        except LiteLLMServiceUnavailable as e:
            raise ServiceUnavailableError(str(e))
        except Exception as e:
            err_str = str(e).lower()
            if "429" in err_str or "rate limit" in err_str or "quota" in err_str or "402" in err_str:
                raise RateLimitError(str(e))
            raise AIProviderError(f"Erro no provedor {full_model}: {str(e)}")
