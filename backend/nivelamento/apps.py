from django.apps import AppConfig

class NivelamentoConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'nivelamento'
    verbose_name = 'Nivelamento Adaptativo'

    def ready(self):
        import sys
        import os
        import threading
        
        # Só executa isso no processo principal (ignora durante 'manage.py migrate' etc.)
        if 'runserver' in sys.argv or 'gunicorn' in sys.argv[0]:
            # Usa thread para não travar o loop de eventos principal,
            # mas garante que ocorre no momento de boot.
            def initialize_kg():
                import logging
                logger = logging.getLogger("nivelamento.apps")
                
                logger.info("[AppConfig] Pré-carregando modelos de IA e montando Grafo na RAM...")
                try:
                    from app.ai.rag_service import get_db, get_embedder
                    from app.ai.knowledge_graph import get_graph
                    
                    get_db()
                    get_embedder()
                    get_graph(rebuild=False)
                    
                    logger.info("[AppConfig] Estrutura GraphRAG carregada e pronta para uso!")
                except Exception as e:
                    logger.error(f"[AppConfig] Falha ao pré-carregar GraphRAG: {e}")

            # Inicializamos na hora do boot do servidor (Eager Loading).
            threading.Thread(target=initialize_kg, daemon=True).start()
