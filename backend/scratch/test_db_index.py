import sqlite3
import json
import time
from pathlib import Path

DB_PATH = Path("vector_store.db")

t0 = time.time()
conn = sqlite3.connect(DB_PATH)
cursor = conn.cursor()
cursor.execute("SELECT document, metadata, confianca, precisa_revisao FROM documents")
rows = cursor.fetchall()
conn.close()

db_index = {}
for doc, meta_str, conf, rev in rows:
    try:
        meta = json.loads(meta_str)
        fname = meta.get("file_name") or meta.get("filename") or meta.get("pdf_name")
        page = meta.get("page")
        if fname and page is not None:
            key = (fname, int(page))
            if key not in db_index:
                db_index[key] = {"chunks": [], "confs": [], "rev": False}
            db_index[key]["chunks"].append(doc)
            if conf is not None:
                db_index[key]["confs"].append(float(conf))
            if rev == 1:
                db_index[key]["rev"] = True
    except Exception:
        continue

elapsed = time.time() - t0
print(f"Indexed {len(rows)} documents into {len(db_index)} pages in {elapsed:.2f}s")

with open("ocr_pipeline/pages_559.json", "r", encoding="utf-8") as f:
    pages_559 = json.load(f)

db_pdfs = set(k[0] for k in db_index.keys())
matched = 0
for item in pages_559:
    pdf = item["pdf"]
    page = item["page"]
    if (pdf, page) in db_index:
        matched += 1
    else:
        # Check fuzzy / ascii match
        alt_match = [k for k in db_index if k[1] == page and (k[0] in pdf or pdf in k[0])]
        if alt_match:
            matched += 1

print(f"Matched {matched} of {len(pages_559)} pages with vector_store.db!")
