from pathlib import Path
import pypdfium2 as pdfium
import sqlite3
import json

# 1. Total de páginas nos PDFs do diretório pdfs/
total_pdf_pages = 0
pdf_details = []
for p in Path("pdfs").glob("*.pdf"):
    try:
        doc = pdfium.PdfDocument(str(p))
        n = len(doc)
        total_pdf_pages += n
        pdf_details.append((p.name, n))
    except Exception as e:
        pdf_details.append((p.name, f"Error: {e}"))

# 2. Total de páginas no vector_store.db
conn = sqlite3.connect("file:vector_store.db?mode=ro", uri=True)
cur = conn.cursor()
cur.execute("SELECT metadata FROM documents")
rows = cur.fetchall()
pages_indexed = set()
for r in rows:
    if r[0]:
        try:
            m = json.loads(r[0])
            fn = m.get("filename") or m.get("file_name") or m.get("pdf_name") or ""
            pg = m.get("page")
            if fn and pg is not None:
                pages_indexed.add((fn, pg))
        except Exception:
            pass

print(f"Total de PDFs no disco: {len(pdf_details)}")
print(f"Total de páginas físicas em todos os PDFs: {total_pdf_pages}")
print(f"Total de pares (PDF, página) indexados no vector_store.db: {len(pages_indexed)}")
print(f"Total de chunks no vector_store.db: {len(rows)}")
