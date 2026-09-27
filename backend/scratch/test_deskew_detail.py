import cv2
import numpy as np
import pypdfium2 as pdfium
import pytesseract
from PIL import Image

pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"
PDF_PATH = r"C:\Users\Felipe\Desktop\TupiLingo\backend\pdfs\Barbosa_1956_CursoDeTupiAntigo_BDCN_CNic.pdf"

doc = pdfium.PdfDocument(PDF_PATH)
page = doc[17] # Pág 18
pil_img = page.render(scale=300.0/72.0).to_pil()
cv_img = cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)
h, w = cv_img.shape[:2]

# Vamos recortar um bloco de texto central da página (para evitar bordas da folha)
crop = cv_img[int(h*0.2):int(h*0.6), int(w*0.1):int(w*0.9)]
ch, cw = crop.shape[:2]

print("=" * 70)
print("TESTE APROFUNDADO DE DESKEW EM BLOCO DE TEXTO REAL")
print("=" * 70)

for angle_deg in [3.0, 8.0, 14.0, 20.0, 30.0]:
    # Rotaciona o bloco de texto
    center = (cw // 2, ch // 2)
    M = cv2.getRotationMatrix2D(center, angle_deg, 1.0)
    rotated = cv2.warpAffine(crop, M, (cw, ch), borderMode=cv2.BORDER_CONSTANT, borderValue=(255, 255, 255))
    
    # Binarização
    gray = cv2.cvtColor(rotated, cv2.COLOR_BGR2GRAY)
    blurred = cv2.GaussianBlur(gray, (3, 3), 0)
    _, binary = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
    
    # Detecção de contornos de palavras/linhas para deskew preciso
    coords = np.column_stack(np.where(binary > 0))
    rect = cv2.minAreaRect(coords)
    box_angle = rect[-1]
    
    # Conversão de convenção OpenCV
    if box_angle < -45:
        calc_angle = -(90 + box_angle)
    elif box_angle > 45:
        calc_angle = 90 - box_angle
    else:
        calc_angle = -box_angle
        
    print(f"\n[Rotacao Sintetica: +{angle_deg:.1f}°]")
    print(f"  Ângulo medido (box_angle): {box_angle:.2f}° | Correção estimada: {calc_angle:.2f}°")
    
    # Compara regra atual (< 15.0°) vs regra ampliada (< 45.0°)
    status_15 = "APLICA CORREÇÃO" if 0.4 < abs(calc_angle) < 15.0 else "DESCARTA (CLAMP 15°)"
    status_45 = "APLICA CORREÇÃO" if 0.4 < abs(calc_angle) < 45.0 else "DESCARTA (CLAMP 45°)"
    print(f"  Regra atual (<15°): {status_15}")
    print(f"  Regra ampliada (<45°): {status_45}")
    
    # Testa OCR na imagem rotacionada sem correção
    data_raw = pytesseract.image_to_data(Image.fromarray(gray), lang="por", config="--oem 1 --psm 3", output_type=pytesseract.Output.DICT)
    confs_raw = [float(c) for c in data_raw["conf"] if float(c) >= 0]
    m_conf_raw = sum(confs_raw)/len(confs_raw) if confs_raw else 0.0
    
    # Testa OCR na imagem corrigida pela estimativa
    M_corr = cv2.getRotationMatrix2D(center, -calc_angle, 1.0)
    deskewed = cv2.warpAffine(gray, M_corr, (cw, ch), borderMode=cv2.BORDER_CONSTANT, borderValue=255)
    data_corr = pytesseract.image_to_data(Image.fromarray(deskewed), lang="por", config="--oem 1 --psm 3", output_type=pytesseract.Output.DICT)
    confs_corr = [float(c) for c in data_corr["conf"] if float(c) >= 0]
    m_conf_corr = sum(confs_corr)/len(confs_corr) if confs_corr else 0.0
    
    print(f"  OCR SEM correcao: {m_conf_raw:.1f}% ({len(confs_raw)} palavras)")
    print(f"  OCR COM correcao: {m_conf_corr:.1f}% ({len(confs_corr)} palavras)")
