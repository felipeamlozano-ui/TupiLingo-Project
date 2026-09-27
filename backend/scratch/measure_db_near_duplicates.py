import sqlite3
import json
import re
from collections import Counter

conn = sqlite3.connect("vector_store.db")
c = conn.cursor()
c.execute("SELECT id, document, metadata FROM documents WHERE metadata IS NOT NULL LIMIT 2000")
rows = c.fetchall()
conn.close()

def get_shingles(txt):
    words = re.findall(r"\w+", txt.lower())
    if len(words) < 3:
        return set(words)
    return set(" ".join(words[i:i+3]) for i in range(len(words)-2))

print("=" * 70)
print(f"ANÁLISE DE NEAR-DUPLICATES EM AMOSTRA DE 2.000 CHUNKS DO BANCO")
print("=" * 70)

# Agrupa por arquivo para comparar near-duplicates dentro do mesmo documento
chunks_by_file = {}
for doc_id, doc, meta in rows:
    try:
        m = json.loads(meta) if meta else {}
        fname = m.get("filename", "desconhecido")
        if fname not in chunks_by_file:
            chunks_by_file[fname] = []
        chunks_by_file[fname].append((doc_id, doc))
    except Exception:
        pass

total_analyzed = 0
total_exact_dups = 0
total_near_dup_pairs = 0
files_summary = []

for fname, doc_list in chunks_by_file.items():
    n = len(doc_list)
    if n < 5:
        continue
    total_analyzed += n
    
    # 1. Duplicatas exatas
    norm_hashes = Counter(re.sub(r"\s+", " ", d[1].strip().lower()) for d in doc_list)
    exact_dups = sum(cnt - 1 for cnt in norm_hashes.values() if cnt > 1)
    total_exact_dups += exact_dups
    
    # 2. Near-duplicates (Jaccard >= 0.82)
    shingles = [get_shingles(d[1]) for d in doc_list]
    near_pairs = 0
    near_affected = set()
    for i in range(n):
        s1 = shingles[i]
        if not s1:
            continue
        for j in range(i+1, n):
            s2 = shingles[j]
            if not s2:
                continue
            inter = len(s1 & s2)
            union = len(s1 | s2)
            if union > 0 and (inter / union) >= 0.82:
                near_pairs += 1
                near_affected.add(i)
                near_affected.add(j)
                
    total_near_dup_pairs += near_pairs
    files_summary.append({
        "file": fname,
        "chunks": n,
        "exact_dups": exact_dups,
        "near_dup_pairs": near_pairs,
        "near_dup_affected": len(near_affected),
        "near_dup_pct": round(len(near_affected) / n * 100, 2)
    })

print(f"Total de chunks analisados: {total_analyzed}")
print(f"Duplicatas EXATAS: {total_exact_dups} ({total_exact_dups/total_analyzed*100:.2f}%)")
print(f"Pares de NEAR-DUPLICATES: {total_near_dup_pairs}")
print("\nDetalhamento por arquivo:")
for f in files_summary[:10]:
    print(f"  - {f['file']:<45}: {f['chunks']} chunks | Exatas={f['exact_dups']} | Near-Dups={f['near_dup_affected']} ({f['near_dup_pct']}%)")
