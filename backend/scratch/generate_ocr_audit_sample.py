import os
import sys
import json
import cv2
import numpy as np
import pypdfium2 as pdfium
import pytesseract
from PIL import Image
from pathlib import Path

pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"
TUPI_WORDS_FILE = Path(r"C:\Users\Felipe\Desktop\TupiLingo\backend\tupi_user_words.txt")
PDFS_DIR = Path(r"C:\Users\Felipe\Desktop\TupiLingo\backend\pdfs")
SCRATCH_DIR = Path(r"C:\Users\Felipe\Desktop\TupiLingo\backend\scratch")

# Importa as funções exatas do pdf_worker refatorado
sys.path.insert(0, r"C:\Users\Felipe\Desktop\TupiLingo\backend")
from pdf_worker import preprocess_image_for_ocr, ocr_image_with_confidence, chunk_text_linguistic

audit_targets = [
    # Simpson 1955 (Scan 100% puro)
    {"pdf": "Simpson_1955_GramaticaLinguaBrasileira.pdf", "page": 6},
    {"pdf": "Simpson_1955_GramaticaLinguaBrasileira.pdf", "page": 16},
    {"pdf": "Simpson_1955_GramaticaLinguaBrasileira.pdf", "page": 26},
    {"pdf": "Simpson_1955_GramaticaLinguaBrasileira.pdf", "page": 36},
    {"pdf": "Simpson_1955_GramaticaLinguaBrasileira.pdf", "page": 46},
    # Barbosa 1956 (Páginas escaneadas processadas via OCR)
    {"pdf": "Barbosa_1956_CursoDeTupiAntigo_BDCN_CNic.pdf", "page": 18},
    {"pdf": "Barbosa_1956_CursoDeTupiAntigo_BDCN_CNic.pdf", "page": 26},
    {"pdf": "Barbosa_1956_CursoDeTupiAntigo_BDCN_CNic.pdf", "page": 31},
    {"pdf": "Barbosa_1956_CursoDeTupiAntigo_BDCN_CNic.pdf", "page": 38},
    {"pdf": "Barbosa_1956_CursoDeTupiAntigo_BDCN_CNic.pdf", "page": 61},
    {"pdf": "Barbosa_1956_CursoDeTupiAntigo_BDCN_CNic.pdf", "page": 63},
    {"pdf": "Barbosa_1956_CursoDeTupiAntigo_BDCN_CNic.pdf", "page": 220},
]

sample_results = []
chunk_counter = 1

for target in audit_targets:
    pdf_path = PDFS_DIR / target["pdf"]
    page_num = target["page"]
    page_idx = page_num - 1
    
    doc = pdfium.PdfDocument(str(pdf_path))
    pil_raw = doc[page_idx].render(scale=300.0/72.0).to_pil()
    
    # 1. OpenCV Preprocessing
    processed_img, angle, metrics = preprocess_image_for_ocr(pil_raw)
    
    # 2. OCR com Tesseract e captura de bounding boxes por palavra
    text, conf_mean, conf_min, words_data = ocr_image_with_confidence(processed_img, psm_mode=3)
    
    # 3. Chunking linguístico consciente
    chunks = chunk_text_linguistic(
        text=text,
        page_num=page_num,
        file_hash=f"hash_{target['pdf'][:8]}",
        filename=target["pdf"],
        ocr_conf_mean=conf_mean,
        ocr_conf_min=conf_min,
    )
    
    if not chunks:
        continue
        
    # Pega o primeiro chunk representativo da página
    chosen_chunk = chunks[0]
    chunk_text = chosen_chunk["document"]
    
    # Recorta a região correspondente na imagem original 300 DPI
    # Acha as coordenadas mínimas e máximas das palavras do chunk
    chunk_words = [w for w in chunk_text.split() if len(w) >= 3]
    matched_boxes = []
    for wb in words_data:
        if any(cw.lower() in wb["text"].lower() for cw in chunk_words[:8]):
            matched_boxes.append(wb)
            
    cv_orig = cv2.cvtColor(np.array(pil_raw), cv2.COLOR_RGB2BGR)
    h_orig, w_orig = cv_orig.shape[:2]
    
    if matched_boxes:
        min_y = max(0, min(b["top"] for b in matched_boxes) - 20)
        max_y = min(h_orig, max(b["top"] + b["height"] for b in matched_boxes) + 30)
        # Se for muito estreito, pega pelo menos 250px de altura
        if max_y - min_y < 250:
            max_y = min(h_orig, min_y + 350)
        crop_img = cv_orig[min_y:max_y, 0:w_orig]
    else:
        # Pega o terço superior/médio da página onde o chunk se encontra
        crop_img = cv_orig[int(h_orig*0.1):int(h_orig*0.45), 0:w_orig]
        
    crop_filename = f"chunk_crop_{chunk_counter}_{target['pdf'][:8]}_p{page_num}.png"
    crop_path = SCRATCH_DIR / crop_filename
    cv2.imwrite(str(crop_path), crop_img)
    
    sample_results.append({
        "sample_num": chunk_counter,
        "pdf": target["pdf"],
        "page": page_num,
        "crop_file": crop_filename,
        "chunk_text": chunk_text,
        "conf_mean": round(conf_mean, 2),
        "conf_min": round(conf_min, 2),
        "metodo": "ocr",
        "precisa_revisao": chosen_chunk["precisa_revisao"],
    })
    chunk_counter += 1

print(json.dumps(sample_results, indent=2, ensure_ascii=False))
