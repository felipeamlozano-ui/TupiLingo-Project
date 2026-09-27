import cv2
import numpy as np
import pypdfium2 as pdfium
import pytesseract
from PIL import Image
from pathlib import Path

pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"
PDF_PATH = Path(r"C:\Users\Felipe\Desktop\TupiLingo\backend\pdfs\Barbosa_1956_CursoDeTupiAntigo_BDCN_CNic.pdf")
TUPI_WORDS_FILE = Path(r"C:\Users\Felipe\Desktop\TupiLingo\backend\tupi_user_words.txt")
SCRATCH_DIR = Path(r"C:\Users\Felipe\Desktop\TupiLingo\backend\scratch")

doc = pdfium.PdfDocument(str(PDF_PATH))

print("=" * 70)
print("TESTE DIRECIONADO: 'morubixaba' E 'oka' (DICIONÁRIO TUPI VS PADRÃO)")
print("=" * 70)

# 1. Página 31 (índice 30): lição com 'morubixaba'
page_31 = doc[30]
pil_31 = page_31.render(scale=300.0/72.0).to_pil()
cv_31 = cv2.cvtColor(np.array(pil_31), cv2.COLOR_RGB2BGR)
h, w = cv_31.shape[:2]

# Procura a ocorrência de 'morubixaba' via OCR data para pegar coordenadas exatas
data_words = pytesseract.image_to_data(pil_31, lang="por+eng", config="--oem 1 --psm 3", output_type=pytesseract.Output.DICT)

moru_boxes = []
for i in range(len(data_words["text"])):
    t = data_words["text"][i].lower()
    if "moru" in t or "bixab" in t or "morub" in t:
        moru_boxes.append({
            "text": data_words["text"][i],
            "conf": data_words["conf"][i],
            "x": data_words["left"][i],
            "y": data_words["top"][i],
            "w": data_words["width"][i],
            "h": data_words["height"][i]
        })

print(f"Ocorrências detectadas em Pág 31: {len(moru_boxes)}")
for idx, b in enumerate(moru_boxes):
    print(f" Box {idx+1}: {b}")
    # Faz crop da linha inteira (estendendo largura)
    pad_y = 15
    pad_x = 40
    y1 = max(0, b["y"] - pad_y)
    y2 = min(h, b["y"] + b["h"] + pad_y)
    x1 = max(0, b["x"] - pad_x)
    x2 = min(w, b["x"] + b["w"] + pad_x)
    
    crop_img = cv_31[y1:y2, x1:x2]
    crop_path = SCRATCH_DIR / f"crop_morubixaba_p31_{idx+1}.png"
    cv2.imwrite(str(crop_path), crop_img)
    print(f"  Recorte salvo em: {crop_path.name}")
    
    # Testa OCR SEM dicionario
    res_no_dict = pytesseract.image_to_string(Image.fromarray(crop_img), lang="por", config="--oem 1 --psm 7")
    # Testa OCR COM tupi_user_words.txt
    res_with_dict = pytesseract.image_to_string(Image.fromarray(crop_img), lang="por", config=f'--oem 1 --psm 7 --user-words "{TUPI_WORDS_FILE}"')
    
    print(f"  > OCR SEM dicionário: {repr(res_no_dict.strip())}")
    print(f"  > OCR COM tupi_user_words.txt: {repr(res_with_dict.strip())}")

# 2. Página 18 (índice 17): lição com 'oka' / 'oca'
page_18 = doc[17]
pil_18 = page_18.render(scale=300.0/72.0).to_pil()
cv_18 = cv2.cvtColor(np.array(pil_18), cv2.COLOR_RGB2BGR)
h18, w18 = cv_18.shape[:2]

data_18 = pytesseract.image_to_data(pil_18, lang="por+eng", config="--oem 1 --psm 3", output_type=pytesseract.Output.DICT)
oka_boxes = []
for i in range(len(data_18["text"])):
    t = data_18["text"][i].lower()
    if t in ("oka", "oca", "o-ka", "o-ca"):
        oka_boxes.append({
            "text": data_18["text"][i],
            "conf": data_18["conf"][i],
            "x": data_18["left"][i],
            "y": data_18["top"][i],
            "w": data_18["width"][i],
            "h": data_18["height"][i]
        })

print(f"\nOcorrências de 'oka'/'oca' em Pág 18: {len(oka_boxes)}")
for idx, b in enumerate(oka_boxes):
    print(f" Box {idx+1}: {b}")
    pad_y = 15
    pad_x = 40
    y1 = max(0, b["y"] - pad_y)
    y2 = min(h18, b["y"] + b["h"] + pad_y)
    x1 = max(0, b["x"] - pad_x)
    x2 = min(w18, b["x"] + b["w"] + pad_x)
    
    crop_img = cv_18[y1:y2, x1:x2]
    crop_path = SCRATCH_DIR / f"crop_oka_p18_{idx+1}.png"
    cv2.imwrite(str(crop_path), crop_img)
    print(f"  Recorte salvo em: {crop_path.name}")
    
    res_no_dict = pytesseract.image_to_string(Image.fromarray(crop_img), lang="por", config="--oem 1 --psm 7")
    res_with_dict = pytesseract.image_to_string(Image.fromarray(crop_img), lang="por", config=f'--oem 1 --psm 7 --user-words "{TUPI_WORDS_FILE}"')
    
    print(f"  > OCR SEM dicionário: {repr(res_no_dict.strip())}")
    print(f"  > OCR COM tupi_user_words.txt: {repr(res_with_dict.strip())}")
