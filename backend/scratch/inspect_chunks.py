import sqlite3
import json

conn = sqlite3.connect('backend/vector_store.db')
cursor = conn.cursor()

# Check what each key PDF contains
target_files = [
    'sek00kamaiura.pdf',
    'Barbosa_1956_CursoDeTupiAntigo_BDCN_CNic.pdf',
    'Dicionrio Tupi.pdf',
    'Rodrigues_1958_Phonologie_der_Tupinamba.pdf',
    'tupi-potiguara-kuapa-2023_compress.pdf',
    'Cascudo_1988_DicionarioDoFolcloreBrasileiro_OCR.pdf'
]

for tf in target_files:
    cursor.execute("""
        SELECT id, document, metadata FROM documents 
        WHERE json_extract(metadata, '$.filename') LIKE ?
        LIMIT 3
    """, (f"%{tf[:15]}%",))
    rows = cursor.fetchall()
    print(f"=== File: {tf} ===")
    print(f"Found sample chunks: {len(rows)}")
    for r in rows:
        meta = json.loads(r[2])
        print(f"  Chunk ID: {r[0]}, Page: {meta.get('page')}")
        snippet = r[1].replace('\n', ' ')[:140]
        print(f"    Text: {snippet}...")
    print()

conn.close()
