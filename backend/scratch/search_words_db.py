import sqlite3
import json

conn = sqlite3.connect("vector_store.db")
c = conn.cursor()

words = ["morubixaba", "morubxata", "oka", "tupinamba", "iande", "tuba"]
for w in words:
    c.execute(f"SELECT id, document, metadata FROM documents WHERE document LIKE ? LIMIT 3", (f"%{w}%",))
    rows = c.fetchall()
    print(f"\n--- Palavra: '{w}' ({len(rows)} resultados) ---")
    for doc_id, doc, meta in rows:
        m = json.loads(meta) if meta else {}
        print(f"ID: {doc_id} | Fonte: {m.get('filename')} | Pág: {m.get('page')}")
        print(f"Trecho: {doc[:140]}...")
