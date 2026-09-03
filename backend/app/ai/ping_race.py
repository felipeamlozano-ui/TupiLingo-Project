import concurrent.futures
import logging
import time
import litellm

logger = logging.getLogger(__name__)


class PingRaceRouter:
    """
    Implementa Lowest Latency Routing (Corrida de Ping Concorrente) em tempo real:
      - Dispara micro-pings em paralelo para os modelos candidatos via ThreadPoolExecutor.
      - O primeiro modelo a responder com HTTP 200 é eleito o vencedor imediatamente.
      - Circuit Breaker / Cooldown progressivo (5m -> 10m -> 30m) para modelos que falharem.
      - 100% seguro em threads síncronas do Django/WSGI (sem conflitos com event loops de asyncio).
    """

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
    def _ping_single_model(cls, target: str) -> str:
        """Envia um micro-ping síncrono para um único modelo e retorna o nome se HTTP 200."""
        provider_name, model_name = target.split("/", 1)
        full_model = f"{provider_name}/{model_name}"
        messages = [{"role": "user", "content": "ping"}]

        try:
            # max_tokens=1, timeout curto (1.5s) para fail-fast no ping
            litellm.completion(
                model=full_model,
                messages=messages,
                max_tokens=1,
                timeout=1.5,
            )
            return target
        except Exception as e:
            logger.debug("[PingRace] Ping falhou para %s: %s", target, e)
            cls.record_failure(target)
            raise e

    @classmethod
    def get_fastest_model(cls, chain: list[str]) -> str:
        """
        Executa a corrida de ping concorrente entre os modelos ativos (fora de cooldown).
        O primeiro a responder com HTTP 200 é eleito o vencedor da corrida.
        """
        if not chain:
            raise ValueError("Cadeia de modelos vazia para a Ping Race.")

        # 1. Filtra modelos que não estejam em cooldown
        active_chain = [m for m in chain if not cls.is_in_cooldown(m)]

        # Se todos estiverem em cooldown, reseta e tenta a cadeia completa
        if not active_chain:
            logger.warning("[PingRace] Todos os modelos estão em cooldown. Resetando penalidades.")
            cls._cooldown_map.clear()
            active_chain = list(chain)

        # Limita a corrida concorrente aos top 5 candidatos para uso eficiente de rede/tokens
        race_pool = active_chain[:5]
        t_start = time.monotonic()
        logger.info(
            "[PingRace] Iniciando corrida de ping em paralelo entre %d modelos: %s",
            len(race_pool),
            race_pool,
        )

        # Executa pings em paralelo usando ThreadPoolExecutor
        with concurrent.futures.ThreadPoolExecutor(max_workers=len(race_pool)) as executor:
            future_to_model = {
                executor.submit(cls._ping_single_model, target): target
                for target in race_pool
            }

            # as_completed entrega o primeiro future que terminar
            for future in concurrent.futures.as_completed(future_to_model):
                target = future_to_model[future]
                try:
                    winner = future.result()
                    latency_ms = int((time.monotonic() - t_start) * 1000)
                    cls.record_success(winner)
                    logger.info("[PingRace] 🏁 Vencedor: %s em %d ms!", winner, latency_ms)

                    # Cancela os outros futures pendentes que ainda não iniciaram
                    for f in future_to_model:
                        if f != future and not f.done():
                            f.cancel()

                    return winner
                except Exception:
                    # Falhou para esse modelo, continua aguardando o próximo no as_completed
                    continue

        # Se todos os modelos do race_pool falharem no ping
        logger.warning("[PingRace] Todos os modelos testados falharam no ping. Usando topo da cadeia.")
        return chain[0]

