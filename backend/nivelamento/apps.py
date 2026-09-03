import logging
import os
import sys
import threading

from django.apps import AppConfig

logger = logging.getLogger("nivelamento.apps")


class NivelamentoConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'nivelamento'
    verbose_name = 'Nivelamento Adaptativo'

    def ready(self):
        # Só executa no processo principal (ignora durante 'manage.py migrate' etc.)
        if 'runserver' not in sys.argv and 'gunicorn' not in sys.argv[0]:
            return

        threading.Thread(target=self._initialize_services, daemon=True).start()

    @staticmethod
    def _initialize_services():
        """
        Warm-up de boot: pré-inicializa os serviços de IA.

        RFC v3.0 — Engine Heurística:
          • USE_SUPABASE_QUIZ_ENGINE=true  → aquece o SupabaseService (singleton httpx)
          • USE_SUPABASE_QUIZ_ENGINE=false → aquece o GraphRAG legado (SQLiteVectorDB + KG)

        Qualquer falha aqui é logada como WARNING e não impede a subida do servidor.
        """
        use_supabase = os.environ.get("USE_SUPABASE_QUIZ_ENGINE", "true").lower() == "true"

        if use_supabase:
            # ── Nova arquitetura (RFC v3.0) ──────────────────────────────────
            logger.info("[AppConfig] Aquecendo SupabaseService (RFC v3.0)...")
            try:
                from app.services.supabase_service import supabase_service  # noqa: PLC0415
                # A instanciação já inicializa o httpx.Client com connection pooling.
                # Apenas acessa o atributo para forçar a criação do singleton.
                _ = supabase_service._rpc_url
                logger.info("[AppConfig] SupabaseService pronto. Engine Heurística ativa.")
            except Exception as exc:
                logger.warning(
                    "[AppConfig] SupabaseService não inicializou (SUPABASE_URL configurado?): %s",
                    exc,
                )
        else:
            # ── Pipeline legado (GraphRAG) ────────────────────────────────────
            logger.info("[AppConfig] Pré-carregando GraphRAG (pipeline legado)...")
            try:
                from app.ai.rag_service import get_db, get_embedder  # noqa: PLC0415
                from app.ai.knowledge_graph import get_graph          # noqa: PLC0415

                get_db()
                get_embedder()
                get_graph(rebuild=False)

                logger.info("[AppConfig] Estrutura GraphRAG carregada e pronta para uso!")
            except Exception as exc:
                logger.warning(
                    "[AppConfig] Falha ao pré-carregar GraphRAG (não fatal): %s", exc
                )
