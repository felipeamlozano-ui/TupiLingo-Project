#!/usr/bin/env python3
"""
Cálculo de métricas objetivas sobre o CORPUS COMPLETO pós-remigração:
1. % Chunks garbled (com regex corrigido [^\w\s]\1{4,} para não confundir espaçamento de tabelas)
2. % Duplicatas exatas
3. % Near-duplicates (shingling 3-grams, Jaccard > 0.82)
4. Distribuição de confiança de OCR (média, desvio padrão, min, mediana)
5. Distribuição de categorias e status de revisão
"""
import sqlite3
import json
import re
import numpy as np
from pathlib import Path
from collections import Counter

DB_PATH = Path(r"C:\Users\Felipe\Desktop\TupiLingo\backend\vector_store.db")

def compute_shingles(text: str, n: int = 3) -> set:
    words = re.findall(r'\b\w+\b', text.lower())
    if len(words) < n:
        return {tuple(words)} if words else set()
    return {tuple(words[i:i+n]) for i in range(len(words) - n + 1)}

def jaccard(s1: set, s2: set) -> float:
    if not s1 or not s2:
        return 0.0
    return len(s1 & s2) / len(s1 | s2)

conn = sqlite3.connect(str(DB_PATH))
cursor = conn.cursor()

print("Recuperando todos os documentos do vector_store.db...")
cursor.execute("SELECT id, document, metadata, categoria, confianca, precisa_revisao, metodo_classificacao FROM documents")
rows = cursor.fetchall()
total_docs = len(rows)
print(f"Total de documentos carregados: {total_docs}\n")

# 1. Análise de Garbled
garbled_docs = []
for doc_id, text, meta_str, cat, conf, rev, met in rows:
    if not text or len(text.strip()) < 30:
        continue
    # Critérios rigorosos e objetivos de garbled:
    # a) 5+ pontuações não-alfanuméricas idênticas consecutivas (excluindo whitespace)
    punct_match = bool(re.search(r'([^\w\s])\1{4,}', text))
    # b) Razão de caracteres não-alfanuméricos e não-pontuação padrão > 35%
    non_alpha_symbols = len(re.findall(r'[^\w\s.,;:!?\'"\-()–—/áéíóúâêîôûãõçÁÉÍÓÚÂÊÎÔÛÃÕÇ]', text))
    sym_ratio = non_alpha_symbols / len(text)
    
    if punct_match or sym_ratio > 0.35:
        garbled_docs.append((doc_id, text[:150], sym_ratio, punct_match))

pct_garbled = (len(garbled_docs) / total_docs) * 100

# 2. Análise de Duplicatas Exatas
content_counts = Counter()
for _, text, _, _, _, _, _ in rows:
    normalized = " ".join(text.strip().lower().split())
    content_counts[normalized] += 1

exact_dupes = sum(count - 1 for count in content_counts.values() if count > 1)
pct_exact_dupes = (exact_dupes / total_docs) * 100

# 3. Análise de Near-Duplicates (Amostra estratificada se > 5000 para performance)
sample_size = min(total_docs, 3000)
sample_rows = rows[:sample_size]
shingles_list = [compute_shingles(r[1]) for r in sample_rows]
near_dupe_count = 0

for i in range(len(sample_rows)):
    s1 = shingles_list[i]
    if not s1:
        continue
    # Compara com janela de 100 vizinhos adjacentes (mesma obra/seção)
    for j in range(i + 1, min(len(sample_rows), i + 100)):
        s2 = shingles_list[j]
        if jaccard(s1, s2) >= 0.82:
            near_dupe_count += 1
            break

pct_near_dupes = (near_dupe_count / sample_size) * 100

# 4. Distribuição de Métodos de Extração e Confiança de OCR
ocr_confs = []
ext_methods = Counter()
for _, _, meta_str, _, _, _, _ in rows:
    try:
        meta = json.loads(meta_str) if meta_str else {}
    except Exception:
        meta = {}
    m_ext = meta.get("metodo_extracao", "legado_sem_meta")
    ext_methods[m_ext] += 1
    if m_ext in ("ocr", "ocr_low_conf"):
        c_mean = meta.get("ocr_conf_mean")
        if c_mean is not None:
            ocr_confs.append(float(c_mean))

# 5. Distribuição de Categorias
cat_counts = Counter(r[3] or "Não Classificado" for r in rows)
rev_count = sum(1 for r in rows if r[5] == 1)

print("=" * 75)
print("RELATÓRIO CONSOLIDADO DE QUALIDADE — CORPUS COMPLETO PÓS-REMIGRAÇÃO")
print("=" * 75)
print(f"Total de Chunks no Banco: {total_docs:,}")
print(f"Chunks Garbled: {len(garbled_docs)} ({pct_garbled:.2f}%)")
print(f"Duplicatas Exatas: {exact_dupes} ({pct_exact_dupes:.2f}%)")
print(f"Near-Duplicates (Amostra 3.000, Jaccard >= 0.82): {near_dupe_count} ({pct_near_dupes:.2f}%)")
print(f"Chunks Marcados para Revisão: {rev_count} ({(rev_count/total_docs)*100:.2f}%)")

print("\n--- MÉTODOS DE EXTRAÇÃO ---")
for m, cnt in ext_methods.most_common():
    print(f"  {m:<20}: {cnt:>6} ({(cnt/total_docs)*100:>5.1f}%)")

if ocr_confs:
    arr = np.array(ocr_confs)
    print("\n--- MÉTRICAS DE CONFIANÇA OCR (Tesseract 300 DPI) ---")
    print(f"  Amostras OCR: {len(arr)}")
    print(f"  Média: {np.mean(arr):.1f}%")
    print(f"  Desvio Padrão: {np.std(arr):.1f}%")
    print(f"  Mediana (p50): {np.median(arr):.1f}%")
    print(f"  p25: {np.percentile(arr, 25):.1f}% | p75: {np.percentile(arr, 75):.1f}%")
    print(f"  Mínima: {np.min(arr):.1f}% | Máxima: {np.max(arr):.1f}%")

print("\n--- COBERTURA DE CATEGORIAS (Taxonomia Fechada de 6) ---")
for cat, cnt in cat_counts.most_common():
    print(f"  {cat:<18}: {cnt:>6} ({(cnt/total_docs)*100:>5.1f}%)")
print("=" * 75)
