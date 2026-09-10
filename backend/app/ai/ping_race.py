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
import threading
import time

import litellm
import redis
from app.core.config import settings

logger = logging.getLogger(__name__)

# Chaves Redis Globais
REDIS_KEY_RANKING = "pingrace:ranking"
REDIS_KEY_FRESH = "pingrace:fresh"
REDIS_KEY_LOCK = "pingrace:revalidate_lock"
REDIS_KEY_COOLDOWN_PREFIX = "pingrace:cooldown:"
REDIS_KEY_FAIL_COUNT_PREFIX = "pingrace:fail_count:"

# Configurações de TTL
TTL_FRESH_SECONDS = 60         # Ranking é considerado fresco por 60s
TTL_RANKING_STORE = 86400      # Ranking stale é mantido por até 24h
TTL_REVALIDATE_LOCK = 15       # Lock distribuído de revalidação expira em 15s
BASE_COOLDOWN_SECONDS = 120.0  # 2 minutos base de penalidade progressiva

# Singleton Connection Pool Redis para Gunicorn
_redis_pool: redis.ConnectionPool | None = None


def get_redis_client() -> redis.Redis | None:
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
    _local_ranking_cache: list[str] = []
    _local_ranking_ts: float = 0.0

    @classmethod
    def record_failure(cls, target: str) -> None:
        """Registra falha do modelo e ativa cooldown progressivo (2m -> 5m -> 15m)."""
        r = get_redis_client()
        now = time.monotonic()
        if r:
            try:
                count_key = f"{REDIS_KEY_FAIL_COUNT_PREFIX}{target}"
                count = r.incr(count_key)
                r.expire(count_key, 3600)  # Histórico mantido por 1 hora

                duration = BASE_COOLDOWN_SECONDS if count == 1 else (300.0 if count == 2 else 900.0)
                cooldown_key = f"{REDIS_KEY_COOLDOWN_PREFIX}{target}"
                r.set(cooldown_key, "1", ex=int(duration))
                logger.warning(
                    "[PingRace] Modelo %s penalizado em cooldown por %ds (%dª falha) [Redis].",
                    target, int(duration), count
                )
                return
            except Exception as exc:
                logger.warning("[PingRace] Falha ao gravar cooldown no Redis: %s. Usando fallback local.", exc)

        # Fallback local em memória
        count = cls._local_cooldown_map.get(f"count:{target}", 0) + 1
        cls._local_cooldown_map[f"count:{target}"] = count
        duration = BASE_COOLDOWN_SECONDS if count == 1 else (300.0 if count == 2 else 900.0)
        cls._local_cooldown_map[target] = now + duration
        logger.warning(
            "[PingRace] Modelo %s penalizado em cooldown por %ds (%dª falha) [Local].",
            target, int(duration), count
        )

    @classmethod
    def record_success(cls, target: str) -> None:
        """Registra sucesso do modelo e encerra penalidade."""
        r = get_redis_client()
        if r:
            try:
                r.delete(f"{REDIS_KEY_COOLDOWN_PREFIX}{target}")
                r.delete(f"{REDIS_KEY_FAIL_COUNT_PREFIX}{target}")
                return
            except Exception:
                pass
        cls._local_cooldown_map.pop(target, None)
        cls._local_cooldown_map.pop(f"count:{target}", None)

    @classmethod
    def is_in_cooldown(cls, target: str) -> bool:
        """Verifica se o modelo está sob penalidade de circuit breaker."""
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

        # 1. Filtra candidatos fora de cooldown
        active_chain = [m for m in chain if not cls.is_in_cooldown(m)]
        if not active_chain:
            logger.warning("[PingRace] Todos os modelos da cadeia estão em cooldown. Resetando penalidades.")
            r = get_redis_client()
            if r:
                try:
                    for m in chain:
                        r.delete(f"{REDIS_KEY_COOLDOWN_PREFIX}{m}")
                except Exception:
                    pass
            cls._local_cooldown_map.clear()
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
