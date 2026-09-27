import pypdfium2 as pdfium
import pytesseract
from pathlib import Path

pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"
TUPI_WORDS_FILE = Path(r"C:\Users\Felipe\Desktop\TupiLingo\backend\tupi_user_words.txt")

pdf_simp = Path(r"C:\Users\Felipe\Desktop\TupiLingo\backend\pdfs\Simpson_1955_GramaticaLinguaBrasileira.pdf")
doc = pdfium.PdfDocument(str(pdf_simp))
print(f"Simpson_1955: {len(doc)} páginas")

for p in [5, 10, 15, 20, 25]:
    page = doc[p]
    pil_img = page.render(scale=300.0/72.0).to_pil()
    data = pytesseract.image_to_data(pil_img, lang="por", config=f'--oem 1 --psm 3 --user-words "{TUPI_WORDS_FILE}"', output_type=pytesseract.Output.DICT)
    words = [w.strip() for w in data["text"] if w.strip()]
    confs = [float(c) for c in data["conf"] if float(c) >= 0]
    mean_conf = sum(confs)/len(confs) if confs else 0.0
    
    # Linhas
    txt = pytesseract.image_to_string(pil_img, lang="por", config=f'--oem 1 --psm 3 --user-words "{TUPI_WORDS_FILE}"')
    first_lines = [l.strip() for l in txt.split("\n") if l.strip()][:4]
    print(f"\n--- Pág {p+1} (Conf Média: {mean_conf:.1f}%) ---")
    for l in first_lines:
        print(f"  > {l}")
