# -*- coding: utf-8 -*-
"""
Auditoria Forense e Extração Preliminar de Candidatos de Navarro (2013).
Examina os 2.412 chunks da obra no vector_store.db, quantificando:
- Páginas totais e distribuição.
- Padrões de formatação de verbetes do Dicionário de Navarro.
- Páginas com provável inversão/rotação.
- Verbetes candidatos identificáveis com classe gramatical e definição.
"""

import sqlite3
import re
import json
from collections import Counter

conn = sqlite3.connect("vector_store.db")
cursor = conn.cursor()

file_hash = "87c9662bc45de33bf5f5592c24f249d4ac86ed3fe568d99bcff11f96ad131671"

cursor.execute("""
    SELECT json_extract(metadata, '$.page') as page,
           document,
           json_extract(metadata, '$.ocr_conf_mean') as conf
    FROM documents
    WHERE json_extract(metadata, '$.file_hash') = ?
    ORDER BY page, json_extract(metadata, '$.chunk_index')
""", (file_hash,))

rows = cursor.fetchall()
print(f"Total de chunks de Navarro recuperados: {len(rows)}")

pages = sorted(list(set(r[0] for r in rows)))
print(f"Páginas digitais presentes: min={min(pages)}, max={max(pages)}, total={len(pages)}")

# Detectar padrão de verbetes no dicionário:
# Verbetes começam em geral com lema em minúsculas (ou negrito), seguido por classe abreviada entre parênteses:
# ex: (s.), (v. tr.), (adj.), (part.), (pron.), (interj.), (posp.), (s. d.), (adv.)
class_pattern = r"\((?:s\.|v\.|adj\.|part\.|pron\.|interj\.|posp\.|adv\.|conj\.|num\.|suf\.|pref\.|loc\.|prep\.)[^\)]*\)"
entry_regex = re.compile(
    r"(?m)^([a-zîŷáéíóúãẽĩõũ'¹²³⁴⁵\-]+(?:\s+(?:ou|e)\s+[a-zîŷáéíóúãẽĩõũ'¹²³⁴⁵\-]+)?)\s*(" + class_pattern + r")\s*-\s*([^\n\r]+)",
    re.IGNORECASE
)

candidates = []
page_entry_counts = Counter()

for r in rows:
    p, doc, conf = r
    matches = entry_regex.findall(doc)
    for m in matches:
        lema = m[0].strip()
        classe = m[1].strip()
        definicao = m[2].strip()
        # Filtra falsos positivos pequenos
        if len(lema) >= 1:
            candidates.append({
                "page": p,
                "lema": lema,
                "classe": classe,
                "definicao": definicao,
                "conf": conf
            })
            page_entry_counts[p] += 1

print(f"\nTotal de verbetes candidatos identificados pela regex estruturada: {len(candidates)}")

# Quantidade de lemas únicos
unique_lemas = set(c["lema"].lower() for c in candidates)
print(f"Lemas únicos candidatos: {len(unique_lemas)}")

# Exibir amostra de 20 verbetes candidatos distribuídos
print("\n--- AMOSTRA DE VERBETES CANDIDATOS EXTRAÍDOS ---")
sample_indices = [i for i in range(0, len(candidates), max(1, len(candidates)//15))][:15]
for idx in sample_indices:
    c = candidates[idx]
    def_snip = c["definicao"][:60] + ("..." if len(c["definicao"]) > 60 else "")
    print(f"Folha {c['page']:3} | Lema: {c['lema']:15} | Classe: {c['classe']:10} | Def: {def_snip}")

# Distribuição de verbetes por página
top_pages = page_entry_counts.most_common(5)
print("\nPáginas com maior densidade de verbetes candidatos:")
for p, cnt in top_pages:
    print(f"  Folha digital {p}: {cnt} verbetes")

# Páginas sem verbetes candidatos detectados (prováveis prefácios, mapas ou páginas invertidas)
empty_pages = [p for p in pages if page_entry_counts[p] == 0]
print(f"\nPáginas digitais sem verbetes candidatos detectados ({len(empty_pages)} páginas):")
print(f"  Primeiras 15: {empty_pages[:15]}")

conn.close()
