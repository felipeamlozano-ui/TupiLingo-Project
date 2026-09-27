import sqlite3
import json
import re
from collections import Counter

conn = sqlite3.connect('vector_store.db')
cursor = conn.cursor()

cursor.execute('SELECT COUNT(*) FROM documents')
total = cursor.fetchone()[0]
print(f"Total de chunks no vector_store.db: {total}")

cursor.execute('SELECT id, document, metadata FROM documents')
rows = cursor.fetchall()

lengths = []
text_hashes = Counter()
garbled_count = 0
empty_or_tiny = 0

sample_garbled = []

for doc_id, text, meta in rows:
    text = text or ""
    lengths.append(len(text))
    
    # Normalizacao para duplicatas
    norm_text = re.sub(r'\s+', ' ', text.strip().lower())
    text_hashes[norm_text] += 1
    
    total_chars = len(text)
    if total_chars < 40:
        empty_or_tiny += 1
    else:
        # Criterio objetivo: simbolos estranhos ou sequencias anomala de pontuacao/caracteres
        strange_chars = len(re.findall(r'[^\w\s\.,;:!?\-\'\"()\[\]/«»–—\u00C0-\u017F\u1E00-\u1EFF]', text))
        repeated_seqs = len(re.findall(r'(\W)\1{4,}', text))
        non_alpha_ratio = strange_chars / total_chars
        
        if non_alpha_ratio > 0.12 or repeated_seqs > 1:
            garbled_count += 1
            if len(sample_garbled) < 5:
                sample_garbled.append((doc_id, text[:150], non_alpha_ratio))

duplicates = sum(count - 1 for count in text_hashes.values() if count > 1)
dup_groups = sum(1 for count in text_hashes.values() if count > 1)

print(f"Comprimento médio: {sum(lengths)/len(lengths):.1f} caracteres (min={min(lengths)}, max={max(lengths)})")
print(f"Chunks vazios ou muito pequenos (<40 chars): {empty_or_tiny} ({empty_or_tiny/total*100:.2f}%)")
print(f"Chunks suspeitos / garbled (critério objetivo): {garbled_count} ({garbled_count/total*100:.2f}%)")
print(f"Chunks duplicados exatos: {duplicates} ({duplicates/total*100:.2f}%) em {dup_groups} grupos")

print("\n--- Exemplos de chunks suspeitos/garbled detectados ---")
for doc_id, snippet, ratio in sample_garbled:
    print(f"ID: {doc_id} | Ratio anômalo: {ratio:.2f}")
    print(f"Snippet: {repr(snippet)}\n")
