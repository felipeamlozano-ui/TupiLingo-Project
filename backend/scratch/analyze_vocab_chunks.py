import os
import sys

sys.path.insert(0, '/app')

import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.development")
django.setup()

from django.db import connection

with connection.cursor() as cur:
    # Busca 10 chunks de dicionário
    cur.execute("""
        SELECT chunk_id, document_text 
        FROM rag_document_categories 
        WHERE categoria = 'Vocabulário' 
          AND (document_text LIKE '%–%' OR document_text LIKE '%-%' OR document_text LIKE '%:%')
        LIMIT 10;
    """)
    rows = cur.fetchall()
    print(f"Found {len(rows)} vocabulary chunks to analyze.")
    for cid, text in rows:
        print(f"\n================ CHUNK: {cid} ================")
        lines = [l.strip() for l in text.splitlines() if l.strip()]
        for l in lines[:10]:
            print(f"  {l}")
