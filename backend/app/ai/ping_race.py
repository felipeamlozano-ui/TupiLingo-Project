"""
TupiLingo — PingRace Router (RFC v3.0 Global Stale-While-Revalidate)

Implementa Lowest Latency Routing concorrente e distribuído para múltiplos workers (Gunicorn):
  1. Ping concorrente em paralelo de todos os modelos ativos via ThreadPoolExecutor.
  2. Ranking persistido no Redis (não em memória de processo), compartilhado entre todos os workers.
  3. Padrão Stale-While-Revalidate: se o cache de 60s expirou, entrega o ranking anterior imediatamente
     e revalida em background, zerando a latência percebida pelo usuário.
  4. Lock distribuído no Redis (SET NX EX 15) para impedir 'stampede' (múltiplas revalidações simultâneas).
  5. Cooldown/Circuit Breaker persistido no Redis para isolar modelos com erro ou estouro de cota.
"""

from __future__ import annotations

import concurrent.futures
import json
import logging
import os
import threading
import time
from typing import Optional

try:
    import litellm
except ImportError:
    litellm = None
import redis

from app.core.config import settings

logger = logging.getLogger(__name__)

# Chaves Redis Globais
REDIS_KEY_RANKING = "pingrace:ranking"
REDIS_KEY_FRESH = "pingrace:fresh"
REDIS_KEY_LOCK = "pingrace:revalidate_lock"
REDIS_KEY_COOLDOWN_PREFIX = "pingrace:cooldown:"
REDIS_KEY_FAIL_COUNT_PREFIX = "pingrace:fail_count:"
REDIS_KEY_FATAL_PREFIX = "pingrace:fatal:"
REDIS_KEY_METRICS_PREFIX = "pingrace:metrics:"

# Configurações de TTL
TTL_FRESH_SECONDS = 60         # Ranking é considerado fresco por 60s
TTL_RANKING_STORE = 86400      # Ranking stale é mantido por até 24h
TTL_REVALIDATE_LOCK = 15       # Lock distribuído de revalidação expira em 15s
BASE_COOLDOWN_SECONDS = 120.0  # 2 minutos base de penalidade progressiva transitória
# TTL configurável para desativação de modelos com erro fatal (401, 402, 403, 404)
TTL_FATAL_SECONDS = int(os.getenv("FATAL_BAN_TTL_SECONDS", getattr(settings, "FATAL_BAN_TTL_SECONDS", 86400)))

# Singleton Connection Pool Redis para Gunicorn
_redis_pool: Optional[redis.ConnectionPool] = None


def get_redis_client() -> Optional[redis.Redis]:
    """Retorna cliente Redis a partir de ConnectionPool thread-safe compartilhado."""
    global _redis_pool
    if not settings.ENABLE_PROMPT_CACHE:
        return None
    if _redis_pool is None:
        try:
            _redis_pool = redis.ConnectionPool.from_url(
                settings.REDIS_URL,
                decode_responses=True,
                max_connections=20,
            )
        except Exception as exc:
            logger.warning("[PingRace] Falha ao criar pool de conexões Redis: %s", exc)
            return None
    try:
        return redis.Redis(connection_pool=_redis_pool)
    except Exception as exc:
        logger.warning("[PingRace] Falha ao obter cliente Redis: %s", exc)
        return None


class PingRaceRouter:
    """
    Roteador de Menor Latência com Stale-While-Revalidate distribuído.
    """

    # Fallbacks locais em memória (caso Redis esteja indisponível em dev)
    _local_cooldown_map: dict[str, float] = {}
    _local_fatal_map: dict[str, float] = {}
    _local_metrics: dict[str, dict] = {}
    _local_ranking_cache: list[str] = []
    _local_ranking_ts: float = 0.0

    @classmethod
    def record_fatal_failure(cls, target: str, reason: str = "") -> None:
        """
        Desativa o modelo fatalmente por 24h persistido no Redis (sobrevive a restarts).
        Aplicável a erros 401, 402, 403, 404 e modelos inexistentes.
        """
        r = get_redis_client()
        now = time.monotonic()
        if r:
            try:
                fatal_key = f"{REDIS_KEY_FATAL_PREFIX}{target}"
                r.set(fatal_key, reason or "fatal_error", ex=TTL_FATAL_SECONDS)
                r.delete(f"{REDIS_KEY_COOLDOWN_PREFIX}{target}")
                r.delete(f"{REDIS_KEY_FAIL_COUNT_PREFIX}{target}")
                r.incr(f"{REDIS_KEY_METRICS_PREFIX}fatal:{target}")
                logger.error(
                    "[PingRace] ⛔ Modelo %s DESATIVADO FATALMENTE por 24h [Redis]. Motivo: %s",
                    target, reason
                )
                return
            except Exception as exc:
                logger.warning("[PingRace] Falha ao gravar erro fatal no Redis: %s. Usando fallback local.", exc)

        cls._local_fatal_map[target] = now + TTL_FATAL_SECONDS
        cls._local_cooldown_map.pop(target, None)
        cls._local_cooldown_map.pop(f"count:{target}", None)
        metrics = cls._local_metrics.setdefault(target, {"sucessos": 0, "erros_fatais": 0, "erros_transitorios": 0, "latencias": []})
        metrics["erros_fatais"] += 1
        logger.error(
            "[PingRace] ⛔ Modelo %s DESATIVADO FATALMENTE por 24h [Local]. Motivo: %s",
            target, reason
        )

    @classmethod
    def is_fatal_disabled(cls, target: str) -> bool:
        """Verifica se o modelo está fatalmente desativado (por 24h)."""
        r = get_redis_client()
        if r:
            try:
                return bool(r.exists(f"{REDIS_KEY_FATAL_PREFIX}{target}"))
            except Exception:
                pass
        now = time.monotonic()
        expiry = cls._local_fatal_map.get(target, 0.0)
        return now < expiry

    @classmethod
    def record_failure(cls, target: str) -> None:
        """Registra falha transitória do modelo e ativa cooldown progressivo (2m -> 5m -> 15m)."""
        r = get_redis_client()
        now = time.monotonic()
        if r:
            try:
                r.incr(f"{REDIS_KEY_METRICS_PREFIX}transient:{target}")
                count_key = f"{REDIS_KEY_FAIL_COUNT_PREFIX}{target}"
                count = r.incr(count_key)
                r.expire(count_key, 3600)  # Histórico mantido por 1 hora

                duration = BASE_COOLDOWN_SECONDS if count == 1 else (300.0 if count == 2 else 900.0)
                cooldown_key = f"{REDIS_KEY_COOLDOWN_PREFIX}{target}"
                r.set(cooldown_key, "1", ex=int(duration))
                logger.warning(
                    "[PingRace] Modelo %s penalizado em cooldown transitório por %ds (%dª falha) [Redis].",
                    target, int(duration), count
                )
                return
            except Exception as exc:
                logger.warning("[PingRace] Falha ao gravar cooldown no Redis: %s. Usando fallback local.", exc)

        # Fallback local em memória
        metrics = cls._local_metrics.setdefault(target, {"sucessos": 0, "erros_fatais": 0, "erros_transitorios": 0, "latencias": []})
        metrics["erros_transitorios"] += 1
        count = cls._local_cooldown_map.get(f"count:{target}", 0) + 1
        cls._local_cooldown_map[f"count:{target}"] = count
        duration = BASE_COOLDOWN_SECONDS if count == 1 else (300.0 if count == 2 else 900.0)
        cls._local_cooldown_map[target] = now + duration
        logger.warning(
            "[PingRace] Modelo %s penalizado em cooldown transitório por %ds (%dª falha) [Local].",
            target, int(duration), count
        )

    @classmethod
    def record_success(cls, target: str, latency_ms: float = 0.0) -> None:
        """Registra sucesso do modelo, encerra penalidade transitória e atualiza métricas."""
        r = get_redis_client()
        if r:
            try:
                r.delete(f"{REDIS_KEY_COOLDOWN_PREFIX}{target}")
                r.delete(f"{REDIS_KEY_FAIL_COUNT_PREFIX}{target}")
                r.incr(f"{REDIS_KEY_METRICS_PREFIX}success:{target}")
                if latency_ms > 0:
                    r.incrbyfloat(f"{REDIS_KEY_METRICS_PREFIX}lat_sum:{target}", latency_ms)
                    r.incr(f"{REDIS_KEY_METRICS_PREFIX}lat_cnt:{target}")
                return
            except Exception:
                pass
        cls._local_cooldown_map.pop(target, None)
        cls._local_cooldown_map.pop(f"count:{target}", None)
        metrics = cls._local_metrics.setdefault(target, {"sucessos": 0, "erros_fatais": 0, "erros_transitorios": 0, "latencias": []})
        metrics["sucessos"] += 1
        if latency_ms > 0:
            metrics["latencias"].append(latency_ms)

    @classmethod
    def is_in_cooldown(cls, target: str) -> bool:
        """Verifica se o modelo está sob penalidade fatal ou transitória."""
        if cls.is_fatal_disabled(target):
            return True
        r = get_redis_client()
        if r:
            try:
                return bool(r.exists(f"{REDIS_KEY_COOLDOWN_PREFIX}{target}"))
            except Exception:
                pass
        now = time.monotonic()
        expiry = cls._local_cooldown_map.get(target, 0.0)
        return now < expiry

    @classmethod
    def get_circuit_metrics(cls, targets: list[str] | None = None) -> dict[str, dict]:
        """Retorna métricas consolidadas de telemetria por modelo/provedor."""
        r = get_redis_client()
        results: dict[str, dict] = {}
        target_list = targets or list(cls._local_metrics.keys())
        if r and not targets:
            try:
                keys = r.keys(f"{REDIS_KEY_METRICS_PREFIX}*")
                for k in keys:
                    parts = k.split(":", 2)
                    if len(parts) >= 3 and parts[2] not in target_list:
                        target_list.append(parts[2])
            except Exception:
                pass

        for target in set(target_list):
            sucessos = 0
            erros_fatais = 0
            erros_transitorios = 0
            tempo_medio_ms = 0.0

            if r:
                try:
                    sucessos = int(r.get(f"{REDIS_KEY_METRICS_PREFIX}success:{target}") or 0)
                    erros_fatais = int(r.get(f"{REDIS_KEY_METRICS_PREFIX}fatal:{target}") or 0)
                    erros_transitorios = int(r.get(f"{REDIS_KEY_METRICS_PREFIX}transient:{target}") or 0)
                    lat_sum = float(r.get(f"{REDIS_KEY_METRICS_PREFIX}lat_sum:{target}") or 0.0)
                    lat_cnt = int(r.get(f"{REDIS_KEY_METRICS_PREFIX}lat_cnt:{target}") or 0)
                    if lat_cnt > 0:
                        tempo_medio_ms = round(lat_sum / lat_cnt, 1)
                except Exception:
                    pass

            local = cls._local_metrics.get(target, {})
            sucessos = max(sucessos, local.get("sucessos", 0))
            erros_fatais = max(erros_fatais, local.get("erros_fatais", 0))
            erros_transitorios = max(erros_transitorios, local.get("erros_transitorios", 0))
            if not tempo_medio_ms and local.get("latencias"):
                tempo_medio_ms = round(sum(local["latencias"]) / len(local["latencias"]), 1)

            status = "fatal_24h" if cls.is_fatal_disabled(target) else ("cooldown" if cls.is_in_cooldown(target) else "ativo")
            results[target] = {
                "sucessos": sucessos,
                "erros_fatais": erros_fatais,
                "erros_transitorios": erros_transitorios,
                "tempo_medio_ms": tempo_medio_ms,
                "status": status,
            }
        return results

    @classmethod
    def _ping_single_model(cls, target: str) -> tuple[str, float]:
        """
        Envia micro-ping com timeout estrito de 1.5s e retorna (target, latency_ms).
        Lança exceção e penaliza o modelo em caso de falha.
        """
        litellm.suppress_debug_info = True
        provider_name, model_name = target.split("/", 1)
        full_model = f"{provider_name}/{model_name}"
        messages = [{"role": "user", "content": "ping"}]
        t_start = time.monotonic()

        try:
            from app.ai.registry import registry
            if provider_name in registry._providers:
                provider = registry.get_provider(provider_name)
                if hasattr(provider, "client") and hasattr(provider.client, "chat"):
                    provider.client.chat.completions.create(
                        model=model_name,
                        messages=messages,
                        max_tokens=1,
                        timeout=1.5,
                    )
                else:
                    provider.generate_text("ping", model_name, max_tokens=1)
            else:
                litellm.completion(
                    model=full_model,
                    messages=messages,
                    max_tokens=1,
                    timeout=1.5,
                )

            latency_ms = (time.monotonic() - t_start) * 1000
            cls.record_success(target)
            return target, latency_ms

        except Exception as exc:
            from app.ai.exceptions import FatalModelError
            is_fatal = False
            err_str = str(exc).lower()
            try:
                from app.ai.registry import registry
                if provider_name in registry._providers:
                    p = registry.get_provider(provider_name)
                    mapped = p._map_exception(exc)
                    if isinstance(mapped, FatalModelError):
                        is_fatal = True
            except Exception:
                pass

            if not is_fatal:
                if any(code in err_str for code in ["401", "402", "403", "404", "payment", "quota", "balance_units"]):
                    is_fatal = True

            if is_fatal:
                cls.record_fatal_failure(target, reason=str(exc)[:150])
            else:
                cls.record_failure(target)
            raise exc

    @classmethod
    def _run_race_and_persist(cls, chain: list[str]) -> list[str]:
        """
        Executa a corrida em paralelo para todos os modelos da cadeia,
        ordena pelo tempo de resposta (menor para maior) e persiste no Redis.
        """
        if not chain:
            return []

        # 1. Filtra candidatos fora de erro fatal e fora de cooldown transitório
        active_chain = [m for m in chain if not cls.is_fatal_disabled(m) and not cls.is_in_cooldown(m)]
        if not active_chain:
            # Apenas modelos que NÃO são fatais podem ter cooldown transitório resetado
            non_fatal = [m for m in chain if not cls.is_fatal_disabled(m)]
            if non_fatal:
                logger.warning("[PingRace] Todos os modelos ativos estão em cooldown transitório. Resetando penalidades transitórias.")
                r = get_redis_client()
                if r:
                    try:
                        for m in non_fatal:
                            r.delete(f"{REDIS_KEY_COOLDOWN_PREFIX}{m}")
                    except Exception:
                        pass
                cls._local_cooldown_map.clear()
                active_chain = list(non_fatal)
            else:
                logger.error("[PingRace] ⛔ Todos os modelos da cadeia estão fatalmente desativados (24h).")
                active_chain = list(chain)

        # Limita o pool concorrente a até 6 modelos top para economia de recursos
        race_pool = active_chain[:6]
        successful_results: list[tuple[str, float]] = []
        failed_models: list[str] = []

        logger.info("[PingRace] 🏁 Iniciando corrida simultânea entre %d modelos: %s", len(race_pool), race_pool)
        t_start = time.monotonic()

        # GANHO DE PERFORMANCE: ThreadPoolExecutor dispara pings simultâneos em I/O paralelo
        with concurrent.futures.ThreadPoolExecutor(max_workers=len(race_pool)) as executor:
            future_to_model = {
                executor.submit(cls._ping_single_model, target): target
                for target in race_pool
            }
            for future in concurrent.futures.as_completed(future_to_model):
                target = future_to_model[future]
                try:
                    target_name, latency_ms = future.result()
                    successful_results.append((target_name, latency_ms))
                    logger.debug("[PingRace] Modelo %s respondeu em %.1f ms", target_name, latency_ms)
                except Exception as e:
                    failed_models.append(target)
                    logger.debug("[PingRace] Modelo %s falhou no ping: %s", target, e)

        # Ordena do mais rápido ao mais lento (Lowest Latency Ranking)
        successful_results.sort(key=lambda x: x[1])
        ranked_models = [m for m, _ in successful_results]

        # Modelos que falharam ou não foram testados vão para o final da cadeia
        for m in chain:
            if m not in ranked_models:
                ranked_models.append(m)

        total_ms = int((time.monotonic() - t_start) * 1000)
        logger.info(
            "[PingRace] 🏆 Ranking estabelecido em %d ms! Vencedor: %s | Ordem completa: %s",
            total_ms,
            ranked_models[0] if ranked_models else "Nenhum",
            ranked_models,
        )

        # 2. Persistência distribuída no Redis
        r = get_redis_client()
        if r:
            try:
                # Salva o ranking com TTL longo (24h)
                r.set(REDIS_KEY_RANKING, json.dumps(ranked_models), ex=TTL_RANKING_STORE)
                # Marca a chave de frescor com TTL de 60s
                r.set(REDIS_KEY_FRESH, "1", ex=TTL_FRESH_SECONDS)
                # Libera o lock distribuído de revalidação
                r.delete(REDIS_KEY_LOCK)
            except Exception as exc:
                logger.warning("[PingRace] Falha ao persistir ranking no Redis: %s", exc)

        # Atualiza cache local de contingência
        cls._local_ranking_cache = list(ranked_models)
        cls._local_ranking_ts = time.monotonic()

        return ranked_models

    @classmethod
    def _dispatch_async_revalidation(cls, chain: list[str]) -> None:
        """
        Dispara a revalidação assíncrona da corrida via Celery (se disponível)
        ou thread daemon em background, sem prender a requisição do usuário.
        """
        try:
            if settings.ENABLE_CELERY:
                # Fila assíncrona Celery disponível no backend
                from app.infra.workers import revalidate_ping_race_task
                revalidate_ping_race_task.delay(chain)
                logger.info("[PingRace] Revalidação do ranking agendada via Celery.")
                return
        except Exception as exc:
            logger.debug("[PingRace] Celery indisponível ou desativado (%s). Usando threading.Thread.", exc)

        # Fallback assíncrono: thread daemon (limitação: concorrência local se Celery offline)
        t = threading.Thread(
            target=cls._run_race_and_persist,
            args=(chain,),
            daemon=True,
            name="PingRace-Revalidate-Worker",
        )
        t.start()
        logger.info("[PingRace] Revalidação do ranking disparada via daemon thread.")

    @classmethod
    def get_ranked_models(cls, chain: list[str]) -> list[str]:
        """
        Padrão Stale-While-Revalidate Distribuído:
          1. Se o ranking no Redis é 'fresh' (< 60s), retorna imediatamente (< 1ms).
          2. Se o ranking expirou mas ainda existe (stale), retorna o ranking antigo
             IMEDIATAMENTE e dispara revalidação em background protegida por lock distribuído.
          3. Se o ranking não existe (cold boot), executa corrida síncrona uma única vez.
        """
        if not chain:
            raise ValueError("Cadeia de modelos vazia para PingRace.")

        r = get_redis_client()
        if r:
            try:
                is_fresh = bool(r.exists(REDIS_KEY_FRESH))
                cached_ranking_raw = r.get(REDIS_KEY_RANKING)

                # CENÁRIO 1: Cache Fresh (< 60s) — Retorno instantâneo
                if is_fresh and cached_ranking_raw:
                    ranked = json.loads(cached_ranking_raw)
                    # Filtra apenas os modelos pertinentes à cadeia solicitada
                    active_ranked = [m for m in ranked if m in chain]
                    if active_ranked:
                        return active_ranked

                # CENÁRIO 2: Stale-While-Revalidate (Expirou, mas temos ranking anterior)
                if cached_ranking_raw:
                    stale_ranked = json.loads(cached_ranking_raw)
                    active_stale = [m for m in stale_ranked if m in chain]

                    # GANHO DE PERFORMANCE: Lock distribuído anti-stampede (SET NX EX 15)
                    # Garante que apenas 1 worker realize o ping concorrente por vez
                    lock_acquired = bool(r.set(REDIS_KEY_LOCK, "1", nx=True, ex=TTL_REVALIDATE_LOCK))
                    if lock_acquired:
                        logger.info("[PingRace] Cache stale detectado. Disparando revalidação em background (SWR).")
                        cls._dispatch_async_revalidation(chain)
                    else:
                        logger.debug("[PingRace] Revalidação já em voo por outro worker. Reutilizando stale.")

                    if active_stale:
                        return active_stale

                # CENÁRIO 3: Cold Boot (Cache totalmente vazio)
                # Tenta pegar lock para rodar a primeira corrida síncrona
                lock_acquired = bool(r.set(REDIS_KEY_LOCK, "1", nx=True, ex=TTL_REVALIDATE_LOCK))
                if lock_acquired:
                    return cls._run_race_and_persist(chain)
                else:
                    # Outro worker está rodando o cold boot; retorne a cadeia padrão imediatamente
                    return chain

            except Exception as exc:
                logger.warning("[PingRace] Erro ao consultar Redis para SWR: %s. Usando fallback.", exc)

        # Contingência sem Redis
        now = time.monotonic()
        if cls._local_ranking_cache and (now - cls._local_ranking_ts < TTL_FRESH_SECONDS):
            return [m for m in cls._local_ranking_cache if m in chain]

        return cls._run_race_and_persist(chain)

    @classmethod
    def get_fastest_model(cls, chain: list[str]) -> str:
        """Atalho de conveniência: retorna o 1º colocado do ranking ranqueado."""
        ranked = cls.get_ranked_models(chain)
        return ranked[0] if ranked else chain[0]

    @classmethod
    def warm_up(cls, chain: list[str]) -> None:
        """Executado no boot do servidor (apps.py:ready) para pré-popular o ranking no Redis."""
        logger.info("[PingRace] Warm-up do ranking solicitado na inicialização.")
        cls._run_race_and_persist(chain)
