import sqlite3
import json
import re
from collections import Counter

conn = sqlite3.connect("vector_store.db")
c = conn.cursor()
c.execute("SELECT document, metadata FROM documents WHERE metadata IS NOT NULL")
rows = c.fetchall()
conn.close()

garbled_by_file = Counter()
total_by_file = Counter()

for doc, m in rows:
    try:
        meta = json.loads(m) if m else {}
        fname = meta.get("filename", "desconhecido")
        total_by_file[fname] += 1
        
        doc_len = len(doc)
        if doc_len < 40:
            garbled_by_file[fname] += 1
            continue
        strange = len(re.findall(r"[^\w\s\.,;:!?\-\'\"()\[\]/«»–—\u00C0-\u017F\u1E00-\u1EFF]", doc))
        repeated = len(re.findall(r"(\W)\1{4,}", doc))
        if (strange / doc_len) > 0.12 or repeated > 1:
            garbled_by_file[fname] += 1
    except Exception:
        pass

print("=" * 70)
print("RANKING DE PDFs MAIS PROBLEMÁTICOS (POR QUANTIDADE E % DE GARBLED):")
print("=" * 70)
for fname, count in total_by_file.most_common(20):
    garb = garbled_by_file[fname]
    pct = (garb / count) * 100
    print(f"{fname:<50} | Total: {count:>5} | Garbled: {garb:>4} ({pct:>5.1f}%)")
