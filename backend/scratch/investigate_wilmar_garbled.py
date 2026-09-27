import sqlite3
import json
import re

conn = sqlite3.connect("vector_store.db")
c = conn.cursor()
c.execute("SELECT id, document, metadata FROM documents WHERE metadata IS NOT NULL")
rows = c.fetchall()
conn.close()

target_file = "04_Wilmar+da+Rocha+D’Angelis.pdf"

legacy_garbled = []
new_garbled = []

for doc_id, text, meta in rows:
    try:
        m = json.loads(meta) if meta else {}
        if m.get("filename") == target_file:
            t_len = len(text)
            strange = len(re.findall(r"[^\w\s\.,;:!?\-\'\"()\[\]/«»–—\u00C0-\u017F\u1E00-\u1EFF]", text))
            repeated = len(re.findall(r"(\W)\1{4,}", text))
            ratio = strange / t_len if t_len else 0
            is_garbled = (ratio > 0.12 or repeated > 1) or (t_len < 40)
            
            item = {
                "id": doc_id,
                "text": text,
                "len": t_len,
                "strange": strange,
                "ratio": ratio,
                "repeated": repeated,
                "page": m.get("page")
            }
            if "_p" in doc_id and "_c" in doc_id:
                if is_garbled:
                    new_garbled.append(item)
            else:
                if is_garbled:
                    legacy_garbled.append(item)
    except Exception:
        pass

print("=" * 70)
print(f"INVESTIGAÇÃO DE CHUNKS GARBLED EM {target_file}")
print("=" * 70)
print(f"Legado garbled: {len(legacy_garbled)}")
for i, g in enumerate(legacy_garbled):
    print(f"\n[LEGADO #{i+1}] ID: {g['id']} | Pág: {g['page']} | Len: {g['len']} | Ratio: {g['ratio']:.3f} | Repeated: {g['repeated']}")
    print(f"Texto:\n{g['text'].encode('ascii', 'backslashreplace').decode('ascii')[:300]}...")

print("\n" + "-" * 70)
print(f"Novo Worker garbled: {len(new_garbled)}")
for i, g in enumerate(new_garbled):
    print(f"\n[NOVO #{i+1}] ID: {g['id']} | Pág: {g['page']} | Len: {g['len']} | Ratio: {g['ratio']:.3f} | Repeated: {g['repeated']}")
    print(f"Texto:\n{g['text'].encode('ascii', 'backslashreplace').decode('ascii')[:300]}...")
