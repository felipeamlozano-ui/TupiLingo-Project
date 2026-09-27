import PyPDF2
import pypdfium2 as pdfium
import pytesseract
from pathlib import Path
from PIL import Image

pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"
TUPI_WORDS_FILE = Path(r"C:\Users\Felipe\Desktop\TupiLingo\backend\tupi_user_words.txt")
PDF_PATH = Path(r"C:\Users\Felipe\Desktop\TupiLingo\backend\pdfs\Barbosa_1956_CursoDeTupiAntigo_BDCN_CNic.pdf")

reader = PyPDF2.PdfReader(str(PDF_PATH))
doc = pdfium.PdfDocument(str(PDF_PATH))

print("=" * 70)
print("INSPEÇÃO DE PÁGINAS DE BARBOSA 1956: TEXTO DIGITAL EMBUTIDO VS NOVO OCR 300 DPI")
print("=" * 70)

for p in [1, 2, 3, 10, 15, 17, 24, 30]:
    raw_digital = reader.pages[p].extract_text() or ""
    print(f"\n--- PÁGINA {p+1} ---")
    print(f"Comprimento texto digital embutido: {len(raw_digital)} caracteres")
    print(f"Primeiros 120 chars digital: {repr(raw_digital[:120])}")
    
    # Executa OCR a 300 DPI
    pil_img = doc[p].render(scale=300.0/72.0).to_pil()
    data = pytesseract.image_to_data(pil_img, lang="por+eng", config=f'--oem 1 --psm 3 --user-words "{TUPI_WORDS_FILE}"', output_type=pytesseract.Output.DICT)
    confs = [float(c) for c in data["conf"] if float(c) >= 0]
    m_conf = sum(confs)/len(confs) if confs else 0.0
    
    lines = pytesseract.image_to_string(pil_img, lang="por+eng", config=f'--oem 1 --psm 3 --user-words "{TUPI_WORDS_FILE}"')
    valid_lines = [l.strip() for l in lines.split("\n") if l.strip()]
    print(f"Novo OCR (300 DPI): {len(lines)} chars extraídos | Conf Média: {m_conf:.1f}%")
    print(f"Primeiras 3 linhas OCR: {valid_lines[:3]}")
