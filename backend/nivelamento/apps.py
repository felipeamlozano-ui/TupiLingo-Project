from django.apps import AppConfig

class NivelamentoConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'nivelamento'
    verbose_name = 'Nivelamento Adaptativo'

    def ready(self):
        from nivelamento.services.ingest_pdfs import ingest_new_pdfs
        import os
        import threading
        if os.environ.get('RUN_MAIN', None) != 'true':
            t = threading.Thread(target=ingest_new_pdfs, daemon=True)
            t.start()
