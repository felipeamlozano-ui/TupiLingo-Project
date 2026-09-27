import sqlite3
import json
import re

conn = sqlite3.connect('backend/vector_store.db')
cursor = conn.cursor()

def find_term_chunks(term, filename_filter=None, max_results=2):
    query = "SELECT id, document, metadata FROM documents WHERE document LIKE ?"
    params = [f"%{term}%"]
    if filename_filter:
        query += " AND json_extract(metadata, '$.filename') LIKE ?"
        params.append(f"%{filename_filter}%")
    query += " LIMIT ?"
    params.append(max_results)
    
    cursor.execute(query, params)
    results = []
    for doc_id, doc, meta_str in cursor.fetchall():
        meta = json.loads(meta_str)
        results.append({
            'chunk_id': doc_id,
            'filename': meta.get('filename'),
            'page': meta.get('page'),
            'snippet': doc[:200].replace('\n', ' ')
        })
    return results

# Test searching for key terms across variants:
test_terms = [
    # Kamaiura
    ("ypawu", "sek00kamaiura"),
    ("oka", "sek00kamaiura"),
    ("kuarup", "sek00kamaiura"),
    ("iwyra", "sek00kamaiura"),
    # Tupinamba / Tupi Antigo
    ("tatu", "Dicionrio Tupi"),
    ("jaguar", "Dicionrio Tupi"),
    ("tuba", "Barbosa"),
    ("morubixaba", "Dicionrio Tupi"),
    ("pindorama", "Cascudo"),
    # Tupi Contemporaneo / Potiguara
    ("potiguara", "potiguara"),
    ("kuapa", "potiguara"),
    ("puranga", "potiguara")
]

for term, fn in test_terms:
    chunks = find_term_chunks(term, fn)
    print(f"Term '{term}' (file filter '{fn}'): {len(chunks)} chunks found")
    for c in chunks:
        print(f"  [{c['chunk_id']}] p.{c['page']} ({c['filename']}): {c['snippet'][:100]}...")

conn.close()
