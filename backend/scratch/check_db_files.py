import sqlite3
import json

conn = sqlite3.connect("file:vector_store.db?mode=ro", uri=True)
cur = conn.cursor()
cur.execute("SELECT DISTINCT metadata FROM documents")
rows = cur.fetchall()

filenames = set()
for r in rows:
    if r[0]:
        try:
            m = json.loads(r[0])
            fn = m.get("filename") or m.get("file_name") or m.get("pdf_name")
            if fn:
                filenames.add(fn)
        except Exception:
            pass

print(f"Total distinct filenames in vector_store.db: {len(filenames)}")
for fn in sorted(filenames):
    print(" -", fn)
