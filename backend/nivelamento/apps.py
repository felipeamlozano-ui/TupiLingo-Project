from django.apps import AppConfig

class NivelamentoConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'nivelamento'
    verbose_name = 'Nivelamento Adaptativo'

    def ready(self):
        # A ingestão automática foi removida daqui para evitar travamentos durante a inicialização do Django.
        # Agora o OCR e RAG devem ser chamados via: python manage.py ingest_pdfs
        pass
