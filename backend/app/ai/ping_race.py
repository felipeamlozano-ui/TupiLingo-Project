import asyncio
import litellm
import logging
import time

logger = logging.getLogger(__name__)

class PingRaceRouter:
    """
    Implementa a lógica de Lowest Latency Routing (Corrida de Ping) com:
      - Health Cache / TTL (evita queimar cotas de RPM em chamadas subsequentes)
      - Circuit Breaker / Cooldown (penaliza modelos que tomarem 429/timeout por 60s)
      - Cancelamento preemptivo de requisições pendentes
    """
    
    _cached_winner: str | None = None
    _cached_winner_timestamp: float = 0.0
    _CACHE_TTL_SECONDS: float = 30.0  # 30 segundos de cache do modelo vencedor
    
    # Mapa de cooldown: { "provider/model": timestamp_liberacao }
    _cooldown_map: dict[str, float] = {}
    # Histórico de falhas consecutivas: { "provider/model": contagem }
    _failure_counts: dict[str, int] = {}
    _BASE_COOLDOWN_SECONDS: float = 300.0  # 5 minutos base de penalidade

    @classmethod
    def record_failure(cls, target: str) -> None:
        """Registra uma falha e coloca o modelo em cooldown progressivo (5m -> 10m -> 30m)."""
        now = time.monotonic()
        count = cls._failure_counts.get(target, 0) + 1
        cls._failure_counts[target] = count

        # Penalidade progressiva: 1x = 300s (5min), 2x = 600s (10min), 3x+ = 1800s (30min)
        if count == 1:
            duration = cls._BASE_COOLDOWN_SECONDS
        elif count == 2:
            duration = cls._BASE_COOLDOWN_SECONDS * 2
        else:
            duration = cls._BASE_COOLDOWN_SECONDS * 6

        cls._cooldown_map[target] = now + duration
        if cls._cached_winner == target:
            cls._cached_winner = None
            cls._cached_winner_timestamp = 0.0
        logger.warning(
            "[PingRace] Modelo %s penalizado em cooldown por %ds (%dª falha).",
            target,
            int(duration),
            count,
        )

    @classmethod
    def record_success(cls, target: str) -> None:
        """Registra um sucesso e zera o contador de falhas do modelo."""
        cls._failure_counts.pop(target, None)
        cls._cooldown_map.pop(target, None)

    @classmethod
    def is_in_cooldown(cls, target: str) -> bool:
        """Verifica se o modelo está atualmente em período de penalidade (cooldown)."""
        now = time.monotonic()
        expiry = cls._cooldown_map.get(target, 0.0)
        return now < expiry

    @classmethod
    async def _ping_model(cls, target: str) -> str:
        """Envia um micro-ping para um único modelo e retorna o nome se HTTP 200."""
        provider_name, model_name = target.split("/", 1)
        full_model = f"{provider_name}/{model_name}"
        messages = [{"role": "user", "content": "ping"}]
        
        try:
            # max_tokens=1, timeout curto para fail-fast no ping
            await litellm.acompletion(
                model=full_model,
                messages=messages,
                max_tokens=1,
                timeout=1.0
            )
            return target
        except Exception as e:
            logger.debug("[PingRace] Ping falhou para %s: %s", target, e)
            cls.record_failure(target)
            raise e

    @classmethod
    async def get_fastest_model(cls, chain: list[str]) -> str:
        """
        Executa a corrida de ping entre os modelos ativos (fora de cooldown).
        Utiliza cache TTL para evitar pings redundantes se uma rota saudável já foi eleita.
        """
        now = time.monotonic()
        
        # 1. Checa Health Cache
        if cls._cached_winner and (now - cls._cached_winner_timestamp < cls._CACHE_TTL_SECONDS):
            if not cls.is_in_cooldown(cls._cached_winner) and cls._cached_winner in chain:
                logger.info(
                    "[PingRace] Cache HIT: reutilizando rota rápida '%s' (TTL restante: %ds).",
                    cls._cached_winner,
                    int(cls._CACHE_TTL_SECONDS - (now - cls._cached_winner_timestamp)),
                )
                return cls._cached_winner

        if not chain:
            raise ValueError("Cadeia de modelos vazia para a Ping Race.")

        # 2. Filtra modelos que não estejam em cooldown
        active_chain = [m for m in chain if not cls.is_in_cooldown(m)]
        
        # Se todos estiverem em cooldown (raro), reseta e tenta a cadeia completa
        if not active_chain:
            logger.warning("[PingRace] Todos os modelos estão em cooldown. Resetando penalidades.")
            cls._cooldown_map.clear()
            active_chain = list(chain)
            
        t_start = time.monotonic()
        # Limita a corrida concorrente aos top 5 candidatos mais velozes para latência mínima (<500ms)
        race_pool = active_chain[:5]
        logger.info(
            "[PingRace] Iniciando corrida rápida entre os top %d modelos ativos na nuvem...",
            len(race_pool),
        )
        
        # Cria as tasks de ping
        tasks = [asyncio.create_task(cls._ping_model(target)) for target in race_pool]
        
        try:
            for coro in asyncio.as_completed(tasks):
                try:
                    winner = await coro
                    # Vencedor encontrado! Cancela as outras tasks pendentes
                    for task in tasks:
                        if not task.done():
                            task.cancel()
                    
                    latency_ms = int((time.monotonic() - t_start) * 1000)
                    
                    # Salva no Health Cache
                    cls._cached_winner = winner
                    cls._cached_winner_timestamp = time.monotonic()
                    
                    logger.info("[PingRace] ✓ Vencedor: %s em %d ms.", winner, latency_ms)
                    return winner
                except Exception:
                    # Falhou, tenta a próxima task que completar
                    continue
            
            # Se todos falharem
            raise RuntimeError("Todos os modelos ativos falharam na corrida de ping.")
            
        except Exception as e:
            raise RuntimeError(f"Erro na corrida de ping: {e}")
