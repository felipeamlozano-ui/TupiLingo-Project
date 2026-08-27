import logging
from celery import shared_task
from app.ai.rag_service import RAGService
from app.ai.cache import prompt_cache

logger = logging.getLogger(__name__)

@shared_task(bind=True, max_retries=3)
def async_generate_question_pack(self, nivel_atual: int, supabase_uid: str):
    """
    Gera um pacote de questões em background para não bloquear o worker do Django.
    Ao finalizar, pode disparar um Webhook ou notificar o frontend via WebSocket/Redis PubSub.
    """
    logger.info(f"Iniciando geração async para nivel {nivel_atual} (Usuário: {supabase_uid})")
    try:
        rag = RAGService()
        questoes = rag.generate(nivel_atual)
        
        # Salva em cache para rápido acesso na próxima request do usuário
        cache_key = f"pack_{supabase_uid}_{nivel_atual}"
        prompt_cache.set(cache_key, "worker", questoes)
        
        logger.info(f"Pacote gerado com sucesso para {supabase_uid}.")
        return {"status": "success", "uid": supabase_uid, "nivel": nivel_atual}
        
    except Exception as exc:
        logger.error(f"Falha na geração async para {supabase_uid}: {exc}")
        raise self.retry(exc=exc, countdown=10)
