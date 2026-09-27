import pypdfium2 as pdfium
import pytesseract
import cv2
import numpy as np
from pathlib import Path

pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"
TUPI_WORDS_FILE = Path(r"C:\Users\Felipe\Desktop\TupiLingo\backend\tupi_user_words.txt")
PDF_PATH = Path(r"C:\Users\Felipe\Desktop\TupiLingo\backend\pdfs\Barbosa_1956_CursoDeTupiAntigo_BDCN_CNic.pdf")
SCRATCH_DIR = Path(r"C:\Users\Felipe\Desktop\TupiLingo\backend\scratch")

doc = pdfium.PdfDocument(str(PDF_PATH))

# Busca 'oka' ou 'oca' nas páginas 10, 20, 26, 38, 50
for p in [9, 19, 25, 37, 49]:
    page = doc[p]
    pil_img = page.render(scale=300.0/72.0).to_pil()
    data = pytesseract.image_to_data(pil_img, lang="por+eng", config="--oem 1 --psm 3", output_type=pytesseract.Output.DICT)
    
    for i in range(len(data["text"])):
        w = data["text"][i].strip()
        wl = w.lower()
        if wl in ("oka", "oca", "óka", "óca") or "oka" in wl or "oca" in wl:
            # Filtra palavras longas como 'época' ou 'troca'
            if wl in ("oka", "oca", "óka", "óca", "s-oka", "r-oka", "t-oka", "s-oca", "r-oca", "t-oca"):
                print(f"Pág {p+1}: palavra '{w}' (conf: {data['conf'][i]}) x={data['left'][i]} y={data['top'][i]} w={data['width'][i]} h={data['height'][i]}")
                cv_img = cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)
                h_img, w_img = cv_img.shape[:2]
                y1 = max(0, data["top"][i] - 15)
                y2 = min(h_img, data["top"][i] + data["height"][i] + 15)
                x1 = max(0, data["left"][i] - 40)
                x2 = min(w_img, data["left"][i] + data["width"][i] + 40)
                crop = cv_img[y1:y2, x1:x2]
                crop_name = f"crop_oka_p{p+1}_{i}.png"
                cv2.imwrite(str(SCRATCH_DIR / crop_name), crop)
                print(f"  Recorte salvo: {crop_name}")
                
                txt_no_dict = pytesseract.image_to_string(crop, lang="por", config="--oem 1 --psm 7")
                txt_dict = pytesseract.image_to_string(crop, lang="por", config=f'--oem 1 --psm 7 --user-words "{TUPI_WORDS_FILE}"')
                print(f"  > OCR Sem Dict: {repr(txt_no_dict.strip())}")
                print(f"  > OCR Com Dict: {repr(txt_dict.strip())}")
