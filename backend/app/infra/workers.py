import logging
from celery import shared_task

logger = logging.getLogger(__name__)


@shared_task(bind=True, max_retries=2, default_retry_delay=5)
def revalidate_ping_race_task(self, chain: list[str]):
    """
    Executa a corrida PingRace concorrente em background (Celery)
    para o padrão Stale-While-Revalidate sem bloquear requisições de usuários.
    """
    try:
        from app.ai.ping_race import PingRaceRouter
        logger.info("[Celery Worker] Executando revalidação do ranking PingRace...")
        ranking = PingRaceRouter._run_race_and_persist(chain)
        logger.info("[Celery Worker] Ranking PingRace revalidado com sucesso: %s", ranking)
        return {"status": "success", "ranking": ranking}
    except Exception as exc:
        logger.error("[Celery Worker] Falha ao revalidar PingRace: %s", exc)
        raise self.retry(exc=exc)


@shared_task(bind=True, max_retries=1, default_retry_delay=5)
def replenish_quiz_pool_task(self, variante_codigo: str, nivel_atual: int, target_count: int = 15):
    """
    Reabastece o Question Pool no Redis de forma assíncrona protegido por Distributed Lock.
    Se já houver outra task reabastecendo esta variante e nível, aborta silenciosamente
    para blindar as cotas e o rate limit de tokens da LLM.
    """
    from app.ai.ping_race import get_redis_client
    r = get_redis_client()
    lock_key = f"lock:replenish:{variante_codigo}:{nivel_atual}"
    lock_acquired = False

    if r:
        try:
            lock_acquired = bool(r.set(lock_key, "1", nx=True, ex=60))
        except Exception as lock_err:
            logger.warning("[Celery Worker] Falha ao verificar lock no Redis: %s", lock_err)
            lock_acquired = True

        if not lock_acquired:
            logger.info(
                "[Celery Worker] Reposição para %s nível %d abortada silenciosamente (lock ativo).",
                variante_codigo,
                nivel_atual,
            )
            return {
                "status": "skipped",
                "reason": "lock_active",
                "variante": variante_codigo,
                "nivel": nivel_atual,
            }

    try:
        from app.ai.rag_service import replenish_pool_for_variante
        logger.info(
            "[Celery Worker] Lock adquirido. Reabastecendo pool (%d pacotes) para variante=%s, nivel=%d...",
            target_count, variante_codigo, nivel_atual
        )
        replenish_pool_for_variante(variante_codigo=variante_codigo, nivel_atual=nivel_atual, count=target_count)
        logger.info("[Celery Worker] Pool reabastecido com sucesso (%d pacotes).", target_count)
        return {"status": "success", "variante": variante_codigo, "nivel": nivel_atual, "repostos": target_count}
    except Exception as exc:
        logger.error("[Celery Worker] Falha ao reabastecer pool de quiz: %s", exc)
        raise self.retry(exc=exc)
    finally:
        if r and lock_acquired:
            try:
                r.delete(lock_key)
            except Exception:
                pass


@shared_task(bind=True, max_retries=3)
def async_generate_question_pack(self, nivel_atual: int, supabase_uid: str):
    """
    Gera um pacote de questões em background para não bloquear o worker do Django.
    """
    logger.info(f"Iniciando geração async para nivel {nivel_atual} (Usuário: {supabase_uid})")
    try:
        from app.ai.rag_service import RAGService
        from app.ai.cache import prompt_cache
        rag = RAGService()
        questoes = rag.generate(nivel_atual)
        
        cache_key = f"pack_{supabase_uid}_{nivel_atual}"
        prompt_cache.set(cache_key, "worker", questoes)
        
        logger.info(f"Pacote gerado com sucesso para {supabase_uid}.")
        return {"status": "success", "uid": supabase_uid, "nivel": nivel_atual}
    except Exception as exc:
        logger.error(f"Falha na geração async para {supabase_uid}: {exc}")
        raise self.retry(exc=exc, countdown=10)
