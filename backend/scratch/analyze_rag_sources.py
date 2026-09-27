import sqlite3
import json

conn = sqlite3.connect('backend/vector_store.db')
cursor = conn.cursor()

# Check PDF sources associated with each variant
queries = {
    "Kamaiura": ["kamaiura", "seki", "sek00kamaiura.pdf", "kamaiurá"],
    "Tupinamba": ["tupinamba", "tupinambá", "rodriques", "1645", "carta 1645"],
    "Tupi Antigo": ["tupi antigo", "anchieta", "lemos barbosa", "dicionário tupi"],
    "Tupi Contemporaneo": ["contemporaneo", "potiguara", "kuapa", "nheengatu", "lingua geral"]
}

for var_name, terms in queries.items():
    print(f"=== Checking {var_name} ===")
    total_found = 0
    matched_files = set()
    for term in terms:
        cursor.execute("SELECT id, document, metadata FROM documents WHERE document LIKE ? LIMIT 3", (f"%{term}%",))
        rows = cursor.fetchall()
        for doc_id, doc, meta in rows:
            m = json.loads(meta)
            matched_files.add(m.get('filename', 'unknown'))
        cursor.execute("SELECT COUNT(*) FROM documents WHERE document LIKE ?", (f"%{term}%",))
        cnt = cursor.fetchone()[0]
        total_found += cnt
        print(f"  Term '{term}': {cnt} chunks")
    print(f"  Sample matched files: {list(matched_files)[:5]}")
    print()

conn.close()
