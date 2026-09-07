import sqlite3
import psycopg2
from decouple import config

# Supabase connection
db_name = config('DB_NAME', default='postgres')
db_user = config('DB_USER')
db_password = config('DB_PASSWORD')
db_host = config('DB_HOST')
db_port = config('DB_PORT', default=6543)

print(f"Connecting to Supabase at {db_host}...")
pg_conn = psycopg2.connect(
    dbname=db_name,
    user=db_user,
    password=db_password,
    host=db_host,
    port=db_port
)
pg_cursor = pg_conn.cursor()

# Get all valid chunk_ids currently in Supabase
pg_cursor.execute("SELECT chunk_id, categoria FROM rag_document_categories")
supabase_chunks = {row[0]: row[1] for row in pg_cursor.fetchall()}
print(f"Total valid chunks in Supabase: {len(supabase_chunks)}")

# Breakdown of valid categories in Supabase
cat_counts = {}
for cat in supabase_chunks.values():
    cat_counts[cat] = cat_counts.get(cat, 0) + 1
for cat, cnt in sorted(cat_counts.items(), key=lambda x: x[1], reverse=True):
    print(f"  - {cat}: {cnt}")

pg_cursor.close()
pg_conn.close()

# Connect to local SQLite
print("Connecting to local SQLite vector_store.db...")
sqlite_conn = sqlite3.connect('vector_store.db', timeout=60.0)
sqlite_cursor = sqlite_conn.cursor()
sqlite_cursor.execute("PRAGMA busy_timeout = 60000")

# Fetch all chunks from SQLite
sqlite_cursor.execute("SELECT id, category_extracted FROM documents")
rows = sqlite_cursor.fetchall()
total_docs = len(rows)

to_reset = []
for chunk_id, extracted in rows:
    # If it was marked as extracted (1), but is NOT in Supabase, reset to 0!
    if extracted == 1 and chunk_id not in supabase_chunks:
        to_reset.append((chunk_id,))

print(f"Total documents in SQLite: {total_docs}")
print(f"Found {len(to_reset)} chunks marked as extracted in SQLite that are missing from Supabase (corrupted/deleted).")

if to_reset:
    print(f"Resetting {len(to_reset)} chunks to category_extracted = 0...")
    batch_size = 500
    for i in range(0, len(to_reset), batch_size):
        batch = to_reset[i:i + batch_size]
        sqlite_cursor.executemany("UPDATE documents SET category_extracted = 0 WHERE id = ?", batch)
        sqlite_conn.commit()
    print("[OK] Reset completed successfully in SQLite!")

# Verify final counts
sqlite_cursor.execute("SELECT count(*) FROM documents WHERE category_extracted = 0")
pending = sqlite_cursor.fetchone()[0]
sqlite_cursor.execute("SELECT count(*) FROM documents WHERE category_extracted = 1")
extracted = sqlite_cursor.fetchone()[0]
print(f"Estado final do SQLite: Total={total_docs}, Pendentes={pending}, Extraidos={extracted}")

sqlite_cursor.close()
sqlite_conn.close()
print("Sincronizacao e reset concluidos com sucesso!")

