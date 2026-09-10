from django.core.management.base import BaseCommand
from nivelamento.services.ingest_pdfs import ingest_new_pdfs
import logging

class Command(BaseCommand):
    help = 'Executa a ingestao e OCR de PDFs para o banco vetorial'

    def handle(self, *args, **options):
        self.stdout.write("Procurando novos PDFs e enfileirando tarefas...")
        try:
            ingest_new_pdfs()
            self.stdout.write(self.style.SUCCESS("Tarefas de OCR enviadas para o Cluster Django Q2 com sucesso!"))
        except Exception as e:
            self.stdout.write(self.style.ERROR(f"Erro durante ingestao: {e}"))
            import traceback
            traceback.print_exc()
