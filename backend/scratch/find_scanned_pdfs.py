import os
from pathlib import Path
import PyPDF2

PDF_DIR = Path(r"C:\Users\Felipe\Desktop\TupiLingo\backend\pdfs")
pdf_files = list(PDF_DIR.glob("*.pdf"))

print(f"Total de PDFs encontrados em pdfs/: {len(pdf_files)}\n")

scan_candidates = []

for pdf_path in sorted(pdf_files):
    try:
        with open(pdf_path, "rb") as f:
            reader = PyPDF2.PdfReader(f)
            total = len(reader.pages)
            # Amostra até 10 páginas
            sample_pages = min(total, 10)
            chars_per_page = []
            for p in range(sample_pages):
                txt = reader.pages[p].extract_text() or ""
                chars_per_page.append(len(txt.strip()))
            
            zero_or_low_pages = sum(1 for c in chars_per_page if c < 120)
            avg_chars = sum(chars_per_page) / len(chars_per_page) if chars_per_page else 0
            
            is_scan = (zero_or_low_pages / sample_pages) >= 0.5
            status = "SCAN PURO / MAJORITÁRIO" if is_scan else "TEXTO DIGITAL"
            
            print(f"[{status}] {pdf_path.name}")
            print(f"  Páginas: {total} | Média chars (amostra 10): {avg_chars:.1f} | Páginas <120 chars: {zero_or_low_pages}/{sample_pages}")
            
            if is_scan:
                scan_candidates.append((pdf_path.name, total, avg_chars, zero_or_low_pages, sample_pages))
    except Exception as e:
        print(f"[ERRO AO ABRIR] {pdf_path.name}: {e}")

print("\n" + "="*70)
print("RESUMO DOS CANDIDATOS A SCAN PURO (SEM TEXTO DIGITAL):")
print("="*70)
for name, total, avg_chars, z, s in scan_candidates:
    print(f" - {name} ({total} págs, {z}/{s} págs sem texto digital na amostra)")
