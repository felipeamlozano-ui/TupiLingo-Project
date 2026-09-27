import sqlite3
import json
import re
from pathlib import Path
from collections import Counter

DB_PATH = Path(r"C:\Users\Felipe\Desktop\TupiLingo\backend\vector_store.db")

def eval_chunks(chunk_texts):
    total = len(chunk_texts)
    if total == 0:
        return {}
    lengths = [len(t) for t in chunk_texts]
    avg_len = sum(lengths) / total
    
    garbled_count = 0
    empty_or_tiny = 0
    for text in chunk_texts:
        t_len = len(text)
        if t_len < 40:
            empty_or_tiny += 1
            continue
        strange = len(re.findall(r"[^\w\s\.,;:!?\-\'\"()\[\]/«»–—\u00C0-\u017F\u1E00-\u1EFF]", text))
        repeated = len(re.findall(r"(\W)\1{4,}", text))
        if (strange / t_len) > 0.12 or repeated > 1:
            garbled_count += 1
            
    norm_hashes = Counter()
    for t in chunk_texts:
        norm = re.sub(r"\s+", " ", t.strip().lower())
        norm_hashes[norm] += 1
    exact_duplicates = sum(count - 1 for count in norm_hashes.values() if count > 1)
    
    # Near-duplicates: Jaccard 3-gram >= 0.82
    def get_shingles(txt):
        words = re.findall(r"\w+", txt.lower())
        if len(words) < 3:
            return set(words)
        return set(" ".join(words[i:i+3]) for i in range(len(words)-2))
    
    shingles = [get_shingles(t) for t in chunk_texts]
    near_dup_pairs = 0
    near_indices = set()
    for i in range(total):
        s1 = shingles[i]
        if not s1:
            continue
        for j in range(i+1, total):
            s2 = shingles[j]
            if not s2:
                continue
            inter = len(s1 & s2)
            union = len(s1 | s2)
            if union > 0 and (inter / union) >= 0.82:
                near_dup_pairs += 1
                near_indices.add(i)
                near_indices.add(j)
                
    return {
        "total_chunks": total,
        "comprimento_medio": round(avg_len, 1),
        "min_len": min(lengths),
        "max_len": max(lengths),
        "vazios_pequenos": empty_or_tiny,
        "garbled_count": garbled_count,
        "garbled_percent": round((garbled_count / total) * 100, 2),
        "exact_duplicates": exact_duplicates,
        "exact_duplicates_percent": round((exact_duplicates / total) * 100, 2),
        "near_duplicate_pairs": near_dup_pairs,
        "near_duplicate_chunks_affected": len(near_indices),
        "near_duplicate_percent": round((len(near_indices) / total) * 100, 2),
    }

conn = sqlite3.connect(str(DB_PATH))
c = conn.cursor()
c.execute("SELECT id, document, metadata FROM documents WHERE metadata IS NOT NULL")
rows = c.fetchall()
conn.close()

files_to_check = ["04_Wilmar+da+Rocha+D’Angelis.pdf", "05.pdf", "01.pdf"]
for fname in files_to_check:
    matched = []
    for doc_id, doc, meta in rows:
        try:
            m = json.loads(meta) if meta else {}
            if m.get("filename") == fname:
                matched.append(doc)
        except Exception:
            pass
    print(f"\nArquivo: {fname} ({len(matched)} chunks encontrados)")
    res = eval_chunks(matched)
    print(json.dumps(res, indent=2))
