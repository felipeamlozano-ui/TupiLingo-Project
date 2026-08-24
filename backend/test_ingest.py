import os
import sys
import traceback

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

import django
django.setup()

from nivelamento.services.ingest_pdfs import ingest_new_pdfs
import logging

# Ensure logs go to stdout
logging.basicConfig(level=logging.INFO, stream=sys.stdout)

try:
    print("Starting ingestion test...")
    ingest_new_pdfs()
    print("Finished ingestion test.")
except Exception as e:
    print("Error during ingestion:")
    traceback.print_exc()
