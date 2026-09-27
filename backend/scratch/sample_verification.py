import sqlite3
import json

conn = sqlite3.connect('vector_store.db')
cursor = conn.cursor()

# Busca os 20 chunks mais recentes gerados pelo novo pipeline
cursor.execute('''
    SELECT id, document, metadata, precisa_revisao, confianca, metodo_classificacao
    FROM documents
    WHERE id LIKE '%_p%_c%'
    ORDER BY created_at DESC
    LIMIT 20
''')
rows = cursor.fetchall()
print(f"Total de chunks recuperados para validação amostral: {len(rows)}\n")

samples = []
for idx, (doc_id, text, meta_json, precisa_rev, conf, metodo) in enumerate(rows, 1):
    meta = json.loads(meta_json) if meta_json else {}
    sample = {
        "index": idx,
        "chunk_id": doc_id,
        "filename": meta.get("filename", "N/A"),
        "page": meta.get("page", "N/A"),
        "ocr_conf_mean": meta.get("ocr_conf_mean", 100.0),
        "ocr_conf_min": meta.get("ocr_conf_min", 100.0),
        "metodo_extracao": meta.get("metodo_extracao", "digital_text"),
        "precisa_revisao": precisa_rev,
        "char_len": len(text),
        "snippet": text.replace("\n", " ")[:200]
    }
    samples.append(sample)
    print(f"[{idx:02d}] ID: {doc_id} | PDF: {sample['filename']} (Pág {sample['page']})")
    print(f"     Extração: {sample['metodo_extracao']} | Conf OCR: {sample['ocr_conf_mean']}% | Revisão: {sample['precisa_revisao']}")
    print(f"     Texto ({sample['char_len']} chars): {sample['snippet']}...\n")

with open('scratch_samples.json', 'w', encoding='utf-8') as f:
    json.dump(samples, f, indent=2, ensure_ascii=False)
