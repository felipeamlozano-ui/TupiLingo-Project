#!/usr/bin/env python3
"""
Auditoria Forense Expandida de OCR (25 chunks cobrindo múltiplos PDFs escaneados).
Extrai recortes de alta resolução a 300 DPI salvos no diretório de artefatos.
"""
import json
import sqlite3
import re
from pathlib import Path
import pypdfium2 as pdfium
from PIL import Image

ARTIFACTS_DIR = Path(r"C:\Users\Felipe\.gemini\antigravity-ide\brain\d30e78fd-d8c8-4d65-9608-a3303b7636a7")
PDFS_DIR = Path(r"C:\Users\Felipe\Desktop\TupiLingo\backend\pdfs")
DB_PATH = Path(r"C:\Users\Felipe\Desktop\TupiLingo\backend\vector_store.db")

def run_expanded_audit():
    conn = sqlite3.connect(str(DB_PATH))
    cursor = conn.cursor()

    cursor.execute("""
        SELECT id, document, metadata, confianca, precisa_revisao 
        FROM documents 
        WHERE json_extract(metadata, '$.metodo_extracao') IN ('ocr', 'ocr_low_conf')
        ORDER BY id
    """)
    rows = cursor.fetchall()
    conn.close()

    print(f"Total de chunks OCR encontrados no banco: {len(rows)}")

    by_pdf = {}
    for r in rows:
        meta = json.loads(r[2]) if r[2] else {}
        fname = meta.get("filename", "desconhecido")
        by_pdf.setdefault(fname, []).append((r, meta))

    print("Distribuição de chunks OCR por PDF:")
    for fname, clist in by_pdf.items():
        print(f"  - {fname}: {len(clist)} chunks")

    # Seleciona 25 chunks diversificados
    selected_targets = []
    # Alvos preferenciais por PDF
    quotas = {
        "survey-report-8.07-moore-etal.pdf": 5,
        "Simpson_1955_GramaticaLinguaBrasileira.pdf": 6,
        "Peret_1980_GuaranaElixirLongaVida.pdf": 1,
        "inclusartiz_apostila-de-tupi-guarani.pdf": 2,
        "Barbosa_1956_CursoDeTupiAntigo_BDCN_CNic.pdf": 5,
        "Dicionário Tupi.pdf": 6,
    }

    for fname, quota in quotas.items():
        if fname in by_pdf:
            items = by_pdf[fname]
            step = max(1, len(items) // quota)
            chosen = [items[i * step] for i in range(min(quota, len(items)))]
            selected_targets.extend(chosen)

    # Se faltar para 25, completa com os demais disponíveis
    if len(selected_targets) < 25:
        all_remaining = [item for clist in by_pdf.values() for item in clist if item not in selected_targets]
        selected_targets.extend(all_remaining[:25 - len(selected_targets)])

    print(f"\nAmostra final selecionada para auditoria: {len(selected_targets)} chunks\n")

    audit_records = []
    for idx, (r, meta) in enumerate(selected_targets, 1):
        chunk_id = r[0]
        doc_text = r[1]
        fname = meta.get("filename")
        page_num = meta.get("page", 1)
        ocr_conf = meta.get("ocr_conf_mean", r[3] * 100.0)
        pdf_path = PDFS_DIR / fname

        crop_filename = f"audit_crop_{idx:02d}_{fname[:12]}_p{page_num}.png"
        crop_path = ARTIFACTS_DIR / crop_filename

        # Renderiza página a 300 DPI e extrai recorte representativo
        try:
            if pdf_path.exists():
                import sys
                sys.path.insert(0, str(PDFS_DIR.parent))
                from pdf_worker import check_and_fix_orientation
                
                doc = pdfium.PdfDocument(str(pdf_path))
                pil_page = doc[page_num - 1].render(scale=300.0/72.0).to_pil()
                pil_page, _ = check_and_fix_orientation(pil_page)
                w, h = pil_page.size
                # Corta topo/meio onde os primeiros parágrafos se localizam
                crop_box = (int(w * 0.05), int(h * 0.08), int(w * 0.95), int(h * 0.45))
                cropped = pil_page.crop(crop_box)
                cropped.save(crop_path, optimize=True)
                doc.close()
        except Exception as exc:
            print(f"Erro ao gerar recorte para {fname} pág {page_num}: {exc}")

        audit_records.append({
            "idx": idx,
            "chunk_id": chunk_id,
            "filename": fname,
            "page": page_num,
            "crop_file": crop_filename,
            "crop_path": str(crop_path),
            "ocr_conf": round(ocr_conf, 1),
            "snippet": doc_text.strip()[:280].replace("\n", " "),
            "precisa_revisao": r[4],
        })

    out_json = ARTIFACTS_DIR / "expanded_ocr_audit.json"
    out_json.write_text(json.dumps(audit_records, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Auditoria expandida concluída e salva em: {out_json}")

if __name__ == "__main__":
    run_expanded_audit()
