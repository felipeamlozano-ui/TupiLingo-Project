import os
import sys
import io
import time
import numpy as np
import cv2
import pypdfium2 as pdfium
import pytesseract
from PIL import Image

pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"
PDF_PATH = r"C:\Users\Felipe\Desktop\TupiLingo\backend\pdfs\Barbosa_1956_CursoDeTupiAntigo_BDCN_CNic.pdf"
TUPI_WORDS_FILE = r"C:\Users\Felipe\Desktop\TupiLingo\backend\tupi_user_words.txt"

def render_page(pdf_path, page_idx, dpi=300):
    doc = pdfium.PdfDocument(pdf_path)
    page = doc[page_idx]
    return page.render(scale=dpi / 72.0).to_pil()

def run_psm_benchmark():
    print("=" * 70)
    print("TESTE 1: BENCHMARK DE PSM (PSM 3 vs PSM 4 vs PSM 6)")
    print("=" * 70)
    
    # Amostra de páginas de Barbosa 1956:
    # Pág 18 (index 17): Texto corrido de gramática (Lição I)
    # Pág 220 (index 219): Vocabulário / colunas no final do livro
    sample_pages = [
        {"name": "Texto corrido (Licao I, Pág 18)", "idx": 17},
        {"name": "Vocabulário / Duas Colunas (Pág 220)", "idx": 219}
    ]
    
    psm_modes = [3, 4, 6]
    psm_desc = {
        3: "PSM 3 (Totalmente automático / Segmentação de página padrão)",
        4: "PSM 4 (Coluna única de texto de tamanho variável)",
        6: "PSM 6 (Bloco uniforme único de texto)"
    }
    
    results = []
    
    for sample in sample_pages:
        page_idx = sample["idx"]
        page_name = sample["name"]
        print(f"\n--- Avaliando: {page_name} ---")
        
        pil_img = render_page(PDF_PATH, page_idx, dpi=300)
        
        # Pré-processamento OpenCV idêntico para todos os testes de PSM
        cv_img = cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)
        gray = cv2.cvtColor(cv_img, cv2.COLOR_BGR2GRAY)
        blurred = cv2.GaussianBlur(gray, (3, 3), 0)
        _, binary = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        preprocessed_pil = Image.fromarray(binary)
        
        for psm in psm_modes:
            config = f'--oem 1 --psm {psm} --user-words "{TUPI_WORDS_FILE}"'
            t0 = time.time()
            data = pytesseract.image_to_data(
                preprocessed_pil,
                lang="por+eng",
                config=config,
                output_type=pytesseract.Output.DICT
            )
            elapsed = time.time() - t0
            
            confs = [float(c) for c in data["conf"] if float(c) >= 0]
            words = [w.strip() for w in data["text"] if w.strip()]
            
            mean_conf = sum(confs) / len(confs) if confs else 0.0
            min_conf = min(confs) if confs else 0.0
            
            # Reconstrói linhas de texto
            lines = {}
            for i in range(len(data["text"])):
                w = data["text"][i].strip()
                if not w:
                    continue
                k = (data["block_num"][i], data["par_num"][i], data["line_num"][i])
                if k not in lines:
                    lines[k] = []
                lines[k].append(w)
            
            text_lines = [" ".join(l) for l in lines.values()]
            full_text = "\n".join(text_lines)
            
            print(f"\n[{psm_desc[psm]}]")
            print(f"  Tempo: {elapsed:.2f}s | Palavras detectadas: {len(words)} | Conf Média: {mean_conf:.2f}% | Conf Mín: {min_conf:.2f}%")
            print(f"  Primeiras 3 linhas extraídas:")
            for l in text_lines[:3]:
                print(f"    > {l}")
                
            results.append({
                "page": page_name,
                "psm": psm,
                "elapsed": elapsed,
                "words": len(words),
                "conf_mean": mean_conf,
                "snippet": text_lines[:3]
            })

def test_deskew_threshold():
    print("\n" + "=" * 70)
    print("TESTE 2: TETO DE DESKEW (INCLINAÇÃO > 15°: TESTE COM 20° E 25°)")
    print("=" * 70)
    
    # Pega página 18
    pil_img = render_page(PDF_PATH, 17, dpi=300)
    cv_img = cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)
    h, w = cv_img.shape[:2]
    
    test_angles = [5.0, 12.0, 20.0, 28.0]
    
    for test_angle in test_angles:
        print(f"\n--- Aplicando rotação sintética de +{test_angle}° na imagem original ---")
        center = (w // 2, h // 2)
        rot_mat = cv2.getRotationMatrix2D(center, test_angle, 1.0)
        rotated_cv = cv2.warpAffine(cv_img, rot_mat, (w, h), borderMode=cv2.BORDER_CONSTANT, borderValue=(255, 255, 255))
        
        # Binarização Otsu
        gray = cv2.cvtColor(rotated_cv, cv2.COLOR_BGR2GRAY)
        blurred = cv2.GaussianBlur(gray, (3, 3), 0)
        _, binary = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        
        coords = np.column_stack(np.where(binary == 0))
        rect = cv2.minAreaRect(coords)
        detected_angle = rect[-1]
        if detected_angle < -45:
            corrected_calc = -(90 + detected_angle)
        else:
            corrected_calc = -detected_angle
            
        print(f"  Ângulo medido por cv2.minAreaRect: {detected_angle:.2f}° -> Ângulo de correção calculado: {corrected_calc:.2f}°")
        
        # 1. Pipeline com clamp atual (< 15.0)
        passed_current_threshold = (0.4 < abs(corrected_calc) < 15.0)
        print(f"  Pipeline com teto atual (< 15.0°): {'CORRIGE' if passed_current_threshold else 'DESCARTA / SEM CORREÇÃO'}")
        
        # 2. Pipeline com teto ampliado (< 45.0)
        passed_expanded_threshold = (0.4 < abs(corrected_calc) < 45.0)
        print(f"  Pipeline com teto ampliado (< 45.0°): {'CORRIGE' if passed_expanded_threshold else 'DESCARTA / SEM CORREÇÃO'}")
        
        # Se corrigir com teto ampliado, mede OCR resultante
        if passed_expanded_threshold:
            M = cv2.getRotationMatrix2D(center, corrected_calc, 1.0)
            corrected_img = cv2.warpAffine(binary, M, (w, h), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_CONSTANT, borderValue=255)
            # Testa OCR rápido sobre 1/3 da página
            sub_img = Image.fromarray(corrected_img[int(h*0.1):int(h*0.4), :])
            data = pytesseract.image_to_data(sub_img, lang="por+eng", config="--oem 1 --psm 3", output_type=pytesseract.Output.DICT)
            confs = [float(c) for c in data["conf"] if float(c) >= 0]
            m_conf = sum(confs)/len(confs) if confs else 0.0
            print(f"  -> Confiança OCR com correção aplicada: {m_conf:.2f}% ({len(confs)} palavras reconhecidas)")
        
        # Se ficar sem correção
        sub_uncorrected = Image.fromarray(binary[int(h*0.1):int(h*0.4), :])
        data_uncorr = pytesseract.image_to_data(sub_uncorrected, lang="por+eng", config="--oem 1 --psm 3", output_type=pytesseract.Output.DICT)
        confs_uncorr = [float(c) for c in data_uncorr["conf"] if float(c) >= 0]
        m_conf_uncorr = sum(confs_uncorr)/len(confs_uncorr) if confs_uncorr else 0.0
        print(f"  -> Confiança OCR SEM correção: {m_conf_uncorr:.2f}% ({len(confs_uncorr)} palavras reconhecidas)")

if __name__ == "__main__":
    run_psm_benchmark()
    test_deskew_threshold()
