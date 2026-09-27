import pypdfium2 as pdfium
import pytesseract
import cv2
import numpy as np
from pathlib import Path
from PIL import Image

pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"
TUPI_WORDS_FILE = Path(r"C:\Users\Felipe\Desktop\TupiLingo\backend\tupi_user_words.txt")

pdf_dic = Path(r"C:\Users\Felipe\Desktop\TupiLingo\backend\pdfs\Dicionário Tupi.pdf")
doc = pdfium.PdfDocument(str(pdf_dic))
print(f"Dicionário Tupi.pdf: {len(doc)} páginas")

# Amostra página 15, 20, 50, 100
for p in [10, 15, 20, 50, 100]:
    page = doc[p]
    pil_img = page.render(scale=300.0/72.0).to_pil()
    # OCR rápido
    txt = pytesseract.image_to_string(pil_img, lang="por", config=f'--oem 1 --psm 3 --user-words "{TUPI_WORDS_FILE}"')
    first_lines = [l.strip() for l in txt.split("\n") if l.strip()][:5]
    print(f"\n--- Pág {p+1} ---")
    for l in first_lines:
        print(f"  > {l}")
