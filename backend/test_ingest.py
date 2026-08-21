import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()
from nivelamento.services.ingest_pdfs import ingest_new_pdfs
import traceback
try:
    ingest_new_pdfs()
except Exception:
    traceback.print_exc()
