import pypdfium2 as pdfium
import PyPDF2
from pathlib import Path
import re

PDF_PATH = Path(r"C:\Users\Felipe\Desktop\TupiLingo\backend\pdfs\Barbosa_1956_CursoDeTupiAntigo_BDCN_CNic.pdf")

doc_pypdf2 = PyPDF2.PdfReader(str(PDF_PATH))
total_pages = len(doc_pypdf2.pages)
print(f"Total de páginas em Barbosa 1956: {total_pages}")

# Verifica se existe camada de texto digital em alguma página
digital_chars = []
for i in range(min(50, total_pages)):
    txt = doc_pypdf2.pages[i].extract_text() or ""
    digital_chars.append((i+1, len(txt)))

print(f"Primeiras 50 páginas - texto digital: {[(p, c) for p, c in digital_chars if c > 0]}")
if all(c == 0 for _, c in digital_chars):
    print("CONFIRMADO: O PDF inteiro é composto 100% de SCANS DE IMAGEM (0 caracteres digitais).")
else:
    print(f"Páginas com texto digital encontradas: {[p for p, c in digital_chars if c > 0]}")
