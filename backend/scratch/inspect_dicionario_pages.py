import sqlite3
import json

conn = sqlite3.connect("file:vector_store.db?mode=ro", uri=True)
cur = conn.cursor()
pages = [6, 8, 11, 32, 35, 36, 39, 43, 47, 50, 52]

for p in pages:
    cur.execute(
        "SELECT document, confianca, metadata FROM documents WHERE metadata LIKE '%Dicion%Tupi.pdf%'"
    )
    rows = cur.fetchall()
    page_rows = []
    for doc, conf, meta_str in rows:
        try:
            m = json.loads(meta_str)
            if int(m.get("page", -1)) == p:
                page_rows.append((doc, conf))
        except Exception:
            pass

    txt = "\n".join([r[0] for r in page_rows if r[0]])
    confs = [r[1] for r in page_rows if r[1] is not None]
    avg_c = sum(confs) / len(confs) if confs else 0.0
    print(f"Page {p}: chunks={len(page_rows)}, text_len={len(txt)}, avg_conf={avg_c:.2f}")
    if txt:
        print("  Sample:", repr(txt[:100]))
