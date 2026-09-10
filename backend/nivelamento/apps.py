import logging
import os
import sys
import threading

from django.apps import AppConfig
from django.conf import settings

logger = logging.getLogger("nivelamento.apps")


class NivelamentoConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'nivelamento'
    verbose_name = 'Nivelamento Adaptativo'

    def ready(self):
        """
        Inicialização no boot do Django:
        - Protegido com os.environ.get('RUN_MAIN') para não duplicar no autoreload de desenvolvimento.
        - Em produção (Gunicorn), RUN_MAIN não é definido pelo runserver, então checamos !settings.DEBUG ou processo principal.
        - Não executa em comandos de migração, collectstatic ou shell.
        """
        # Ignora comandos administrativos de CLI
        ignored_commands = {'migrate', 'makemigrations', 'collectstatic', 'test', 'shell', 'createsuperuser', 'check', 'clean_test_users'}
        if any(cmd in sys.argv for cmd in ignored_commands):
            return

        # GANHO DE PERFORMANCE: Previne inicialização duplicada no processo pai do runserver
        is_runserver = 'runserver' in sys.argv
        if is_runserver and os.environ.get('RUN_MAIN') != 'true':
            return

        # Dispara o warm-up em thread não-bloqueante para não retardar a subida do servidor
        threading.Thread(target=self._initialize_services, daemon=True, name="Nivelamento-Warmup-Thread").start()

    @staticmethod
    def _initialize_services():
        """
        Warm-up assíncrono de boot:
          1. Pré-aquece o singleton do SupabaseService (connection pooling).
          2. Dispara a 1ª corrida global do PingRaceRouter e persiste o ranking no Redis.
        """
        use_supabase = getattr(settings, "USE_SUPABASE_QUIZ_ENGINE", True)

        if use_supabase:
            logger.info("[AppConfig] Aquecendo SupabaseService (connection pool)...")
            try:
                from app.services.supabase_service import (
                    supabase_service,
                )
                _ = supabase_service._rpc_url
                logger.info("[AppConfig] SupabaseService pronto com connection pool.")
            except Exception as exc:
                logger.warning("[AppConfig] SupabaseService não inicializou: %s", exc)
        else:
            logger.info("[AppConfig] Pré-carregando GraphRAG (legado)...")
            try:
                from app.ai.knowledge_graph import get_graph
                from app.ai.rag_service import get_db, get_embedder
                get_db()
                get_embedder()
                get_graph(rebuild=False)
                logger.info("[AppConfig] GraphRAG carregado.")
            except Exception as exc:
                logger.warning("[AppConfig] Falha ao carregar GraphRAG: %s", exc)

        # ── WARM-UP PINGRACE GLOBAL ──────────────────────────────────────────
        # GANHO DE PERFORMANCE: Popula o ranking no Redis ANTES do primeiro usuário clicar em "Fazer Nivelamento"
        try:
            logger.info("[AppConfig] Disparando warm-up da corrida PingRace Global no Redis...")
            from app.ai.ping_race import PingRaceRouter
            from app.ai.router import ModelRouter

            fast_chain = ModelRouter.get_chain_for_task(task_type="fast")
            PingRaceRouter.warm_up(fast_chain)
            logger.info("[AppConfig] 🏁 PingRace Global aquecido e compartilhado no Redis.")
        except Exception as exc:
            logger.warning("[AppConfig] Falha no warm-up do PingRace (não fatal): %s", exc)
