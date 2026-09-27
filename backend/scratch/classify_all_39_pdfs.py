#!/usr/bin/env python3
import os
import sys
from pathlib import Path
import PyPDF2

PDFS_DIR = Path(r"C:\Users\Felipe\Desktop\TupiLingo\backend\pdfs")
pdfs = sorted(PDFS_DIR.glob("*.pdf"), key=lambda p: p.name.lower())

print(f"Analisando {len(pdfs)} PDFs do acervo...")
print("=" * 85)
print(f"{'PDF':<45} | {'Págs':<5} | {'<120 chars':<11} | {'Classificação'}")
print("=" * 85)

scan_puro = []
misto = []
digital = []

for pdf_path in pdfs:
    fname = pdf_path.name
    try:
        with open(pdf_path, "rb") as f:
            reader = PyPDF2.PdfReader(f)
            total = len(reader.pages)
            if total == 0:
                print(f"{fname[:45]:<45} | {0:<5} | {'N/A':<11} | CORROMPIDO (0 págs)")
                continue

            # Amostra uniforme de até 15 páginas distribuídas ao longo de todo o documento
            if total <= 15:
                sample_indices = list(range(total))
            else:
                step = total / 15
                sample_indices = [int(i * step) for i in range(15)]

            low_char_pages = 0
            for idx in sample_indices:
                try:
                    txt = (reader.pages[idx].extract_text() or "").strip()
                    if len(txt) < 120:
                        low_char_pages += 1
                except Exception:
                    low_char_pages += 1

            sample_size = len(sample_indices)
            pct_low = (low_char_pages / sample_size) * 100

            if pct_low >= 90.0:
                cat = "SCAN PURO"
                scan_puro.append(fname)
            elif pct_low >= 20.0:
                cat = "MISTO / OCR DEGRADADO"
                misto.append(fname)
            else:
                cat = "TEXTO DIGITAL LIMPO"
                digital.append(fname)

            ratio_str = f"{low_char_pages}/{sample_size} ({pct_low:.0f}%)"
            print(f"{fname[:45]:<45} | {total:<5} | {ratio_str:<11} | {cat}")

    except Exception as exc:
        print(f"{fname[:45]:<45} | {'ERR':<5} | {'N/A':<11} | ERRO AO ABRIR: {exc}")

print("\n" + "=" * 85)
print(f"RESUMO DO ACERVO:")
print(f"  - SCAN PURO (Necessita OCR total): {len(scan_puro)}")
print(f"  - MISTO / OCR DEGRADADO (Necessita OCR seletivo por pág): {len(misto)}")
print(f"  - TEXTO DIGITAL LIMPO (Extração nativa rápida): {len(digital)}")
print("=" * 85)
