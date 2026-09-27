import sqlite3
import json
from collections import Counter

conn = sqlite3.connect('backend/vector_store.db')
cursor = conn.cursor()

cursor.execute('SELECT COUNT(*) FROM documents')
total = cursor.fetchone()[0]
print(f"Total documents: {total}")

cursor.execute('SELECT metadata FROM documents')
filenames = Counter()
variantes = Counter()
categorias = Counter()

for (meta_str,) in cursor.fetchall():
    try:
        meta = json.loads(meta_str)
        fn = meta.get('filename', 'unknown')
        filenames[fn] += 1
        var = meta.get('variante', meta.get('variante_codigo', 'unknown'))
        variantes[var] += 1
        cat = meta.get('categoria', 'unknown')
        categorias[cat] += 1
    except Exception:
        pass

print("\nTop Filenames:")
for fn, count in filenames.most_common(20):
    print(f"  {fn}: {count}")

print("\nVariantes:")
for var, count in variantes.most_common():
    print(f"  {var}: {count}")

print("\nCategorias:")
for cat, count in categorias.most_common():
    print(f"  {cat}: {count}")

conn.close()
