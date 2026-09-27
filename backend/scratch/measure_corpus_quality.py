import sqlite3
import json
from collections import defaultdict
import numpy as np

conn = sqlite3.connect('backend/vector_store.db')
cursor = conn.cursor()

# Query all chunks with metadata, precisa_revisao, confianca
cursor.execute("SELECT id, confianca, precisa_revisao, metadata FROM documents")
rows = cursor.fetchall()
total_chunks = len(rows)

pdf_stats = defaultdict(lambda: {
    "chunks": 0,
    "pages": set(),
    "metodos": defaultdict(int),
    "confiancas": [],
    "precisa_revisao_count": 0,
    "sanity_motivos": defaultdict(int),
    "chunks_by_score": {
        "98-100": 0,
        "94-97": 0,
        "90-93": 0,
        "85-89": 0,
        "<85": 0
    },
    "pages_by_score": defaultdict(lambda: {
        "scores": [],
        "metodos": set(),
        "precisa_revisao": 0
    })
})

total_pages = set()
chunks_by_score_global = {
    "98-100": 0,
    "94-97": 0,
    "90-93": 0,
    "85-89": 0,
    "<85": 0
}
metodos_global = defaultdict(int)
precisa_revisao_total = 0

for doc_id, conf, precisa_rev, meta_str in rows:
    try:
        meta = json.loads(meta_str) if meta_str else {}
    except Exception:
        meta = {}
    
    filename = meta.get("filename", "desconhecido.pdf")
    page = meta.get("page", 0)
    met_ext = meta.get("metodo_extracao", "desconhecido")
    ocr_conf = meta.get("ocr_conf_mean")
    
    # Se o método for digital_text, a confiança do OCR é considerada 100% (texto digital perfeito)
    # Se for OCR, usamos o ocr_conf_mean ou conf da linha
    if met_ext == "digital_text":
        score = 100.0
    elif ocr_conf is not None:
        score = float(ocr_conf)
    elif conf is not None:
        score = float(conf) * 100.0 if float(conf) <= 1.0 else float(conf)
    else:
        score = 0.0

    if precisa_rev == 1:
        precisa_revisao_total += 1
        pdf_stats[filename]["precisa_revisao_count"] += 1
        pdf_stats[filename]["pages_by_score"][page]["precisa_revisao"] += 1

    total_pages.add((filename, page))
    pdf_stats[filename]["chunks"] += 1
    pdf_stats[filename]["pages"].add(page)
    pdf_stats[filename]["metodos"][met_ext] += 1
    pdf_stats[filename]["confiancas"].append(score)
    metodos_global[met_ext] += 1
    
    s_reason = meta.get("sanity_reason", "valido")
    if s_reason and s_reason != "valido":
        pdf_stats[filename]["sanity_motivos"][s_reason] += 1

    # Tabela de roteamento da seção 2:
    # 98-100: OCR rápido (atual)
    # 94-97: OCR padrão (atual)
    # 90-93: Fase 1 (reforçado)
    # 85-89: Fase 1 completa + flag de atenção
    # <85: Fase 1 completa + fila de revisão obrigatória
    if score >= 98.0:
        bucket = "98-100"
    elif score >= 94.0:
        bucket = "94-97"
    elif score >= 90.0:
        bucket = "90-93"
    elif score >= 85.0:
        bucket = "85-89"
    else:
        bucket = "<85"
        
    chunks_by_score_global[bucket] += 1
    pdf_stats[filename]["chunks_by_score"][bucket] += 1
    pdf_stats[filename]["pages_by_score"][page]["scores"].append(score)
    pdf_stats[filename]["pages_by_score"][page]["metodos"].add(met_ext)

conn.close()

print(f"=== ESTATÍSTICAS GLOBAIS DO CORPUS ===")
print(f"Total de chunks: {total_chunks}")
print(f"Total de pares (PDF, Página) únicos: {len(total_pages)}")
print(f"Total de PDFs indexados: {len(pdf_stats)}")
print(f"Total de chunks com precisa_revisao=1: {precisa_revisao_total} ({precisa_revisao_total/total_chunks*100:.2f}%)")
print(f"Métodos de extração globais: {dict(metodos_global)}")

print("\n=== DISTRIBUIÇÃO GLOBAL POR FAIXA DE SCORE (CHUNKS) ===")
for b in ["98-100", "94-97", "90-93", "85-89", "<85"]:
    cnt = chunks_by_score_global[b]
    pct = cnt / total_chunks * 100
    print(f"  Faixa {b:7s}: {cnt:6d} chunks ({pct:6.2f}%)")

# Agora consolidando por PÁGINA (cada página tem seu score médio de OCR/texto)
page_buckets_global = {
    "98-100": 0,
    "94-97": 0,
    "90-93": 0,
    "85-89": 0,
    "<85": 0
}

pdf_page_summary = {}

for filename, pdata in sorted(pdf_stats.items()):
    p_buckets = {"98-100": 0, "94-97": 0, "90-93": 0, "85-89": 0, "<85": 0}
    for page, pinfo in pdata["pages_by_score"].items():
        # Score da página é a média dos scores dos chunks da página
        avg_p_score = np.mean(pinfo["scores"]) if pinfo["scores"] else 0.0
        if avg_p_score >= 98.0:
            b = "98-100"
        elif avg_p_score >= 94.0:
            b = "94-97"
        elif avg_p_score >= 90.0:
            b = "90-93"
        elif avg_p_score >= 85.0:
            b = "85-89"
        else:
            b = "<85"
        p_buckets[b] += 1
        page_buckets_global[b] += 1
    pdf_page_summary[filename] = p_buckets

print("\n=== DISTRIBUIÇÃO GLOBAL POR FAIXA DE SCORE (PÁGINAS) ===")
for b in ["98-100", "94-97", "90-93", "85-89", "<85"]:
    cnt = page_buckets_global[b]
    pct = cnt / len(total_pages) * 100
    print(f"  Faixa {b:7s}: {cnt:6d} páginas ({pct:6.2f}%)")

print("\n=== DETALHAMENTO POR PDF ===")
print(f"{'PDF':<45} | {'Págs':<5} | {'Chunks':<6} | {'OCR Chunks':<10} | {'Rev=1':<5} | {'<94 Chunks':<10} | {'<94 Págs':<8}")
print("-" * 105)
for filename, pdata in sorted(pdf_stats.items(), key=lambda x: x[1]["chunks"], reverse=True):
    ocr_c = pdata["metodos"].get("ocr", 0) + pdata["metodos"].get("ocr_low_conf", 0)
    below_94_c = sum(pdata["chunks_by_score"][b] for b in ["90-93", "85-89", "<85"])
    p_b = pdf_page_summary[filename]
    below_94_p = sum(p_b[b] for b in ["90-93", "85-89", "<85"])
    print(f"{filename:<45} | {len(pdata['pages']):<5} | {pdata['chunks']:<6} | {ocr_c:<10} | {pdata['precisa_revisao_count']:<5} | {below_94_c:<10} | {below_94_p:<8}")

print("\n=== PDFS COM CHUNKS/PÁGINAS ABAIXO DE 94 (CANDIDATOS À FASE 1) ===")
for filename, pdata in sorted(pdf_stats.items()):
    below_94_c = sum(pdata["chunks_by_score"][b] for b in ["90-93", "85-89", "<85"])
    if below_94_c > 0 or pdata["precisa_revisao_count"] > 0:
        p_b = pdf_page_summary[filename]
        print(f"\n[!] {filename}:")
        print(f"    Total Páginas: {len(pdata['pages'])}, Total Chunks: {pdata['chunks']}")
        print(f"    Métodos de Extração: {dict(pdata['metodos'])}")
        print(f"    Chunks com precisa_revisao=1: {pdata['precisa_revisao_count']}")
        print(f"    Distribuição Chunks por Faixa: {dict(pdata['chunks_by_score'])}")
        print(f"    Distribuição Páginas por Faixa: {dict(p_b)}")
        if pdata["sanity_motivos"]:
            print(f"    Motivos de Sanity: {dict(pdata['sanity_motivos'])}")
