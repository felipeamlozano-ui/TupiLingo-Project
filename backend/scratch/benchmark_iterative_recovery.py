import time
import sys
from pathlib import Path
BACKEND_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_DIR))

import pypdfium2 as pdfium
import numpy as np
import cv2
from PIL import Image

from ocr_pipeline.rollback_engine.rollback_manager import RollbackManager, IterativeRecoveryEngine
from ocr_pipeline.core.provenance import BoundingBox
from ocr_pipeline.ensemble_engine.multi_engine import ForensicEnsembleEngine

# 1. Carregar uma região de imagem real de Dicionário Tupi
pdf_path = next(Path("pdfs").glob("*Dicion*Tupi*.pdf"))
doc = pdfium.PdfDocument(str(pdf_path))
page_img = doc.get_page(10).render(scale=2.0).to_pil() # página 11
img_np = np.array(page_img)

# Crop de uma região de verbete (ex: 400x300 pixels)
crop = img_np[500:900, 200:800]
crop_pil = Image.fromarray(crop)

rollback_mgr = RollbackManager(audit_log_path=Path("ocr_cache/test_benchmark_audit.jsonl"))
recovery_engine = IterativeRecoveryEngine(rollback_mgr, max_iterations=5)

ensemble = ForensicEnsembleEngine()

def region_processor_fn(filter_name: str, engine_name: str, scale: float) -> tuple[str, float]:
    processed = crop.copy()
    if filter_name == "clahe":
        gray = cv2.cvtColor(processed, cv2.COLOR_RGB2GRAY)
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        processed = clahe.apply(gray)
    elif filter_name == "sauvola":
        gray = cv2.cvtColor(processed, cv2.COLOR_RGB2GRAY)
        processed = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 25, 10)
    elif filter_name == "retinex":
        gray = cv2.cvtColor(processed, cv2.COLOR_RGB2GRAY)
        processed = cv2.equalizeHist(gray)

    pil_crop = Image.fromarray(processed)
    cands = ensemble._run_rapidocr_cached(pil_crop, branch=filter_name, dpi=int(300 * scale))
    if cands:
        return cands[0].text, cands[0].confidence
    return "", 0.0

# Medição 1: Região que resolve em 1 passo (confiança >= 0.90)
t0 = time.time()
hist_1step = recovery_engine.recover_region(
    region_id="reg_clean",
    bbox=BoundingBox(x1=200, y1=500, x2=800, y2=900),
    initial_text="Texto limpo já com alta confiança",
    initial_conf=0.92,
    region_processor_fn=region_processor_fn,
)
t_1step = time.time() - t0

# Medição 2: Região de baixa confiança que passa por 1 passo real de OCR
t0 = time.time()
res_text, res_conf = region_processor_fn("clahe", "rapidocr", 1.0)
t_single_pass = time.time() - t0

# Medição 3: Região degradada passando pelas 5 iterações completas (forçando loop completo sem early exit)
t0 = time.time()
# Para medir o pior caso de 5 passos completos, simulamos uma função que não atinge 0.90 de imediato
def region_processor_worst_case(filter_name: str, engine_name: str, scale: float) -> tuple[str, float]:
    processed = crop.copy()
    if filter_name == "clahe":
        gray = cv2.cvtColor(processed, cv2.COLOR_RGB2GRAY)
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        processed = clahe.apply(gray)
    elif filter_name == "sauvola":
        gray = cv2.cvtColor(processed, cv2.COLOR_RGB2GRAY)
        processed = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 25, 10)
    elif filter_name == "retinex":
        gray = cv2.cvtColor(processed, cv2.COLOR_RGB2GRAY)
        processed = cv2.equalizeHist(gray)
    elif filter_name == "morph_reconstruction":
        gray = cv2.cvtColor(processed, cv2.COLOR_RGB2GRAY)
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
        processed = cv2.morphologyEx(gray, cv2.MORPH_OPEN, kernel)
    elif filter_name == "niblack":
        gray = cv2.cvtColor(processed, cv2.COLOR_RGB2GRAY)
        processed = cv2.GaussianBlur(gray, (5, 5), 0)

    pil_crop = Image.fromarray(processed)
    # Não-cached para medir tempo real de inferência
    cands = ensemble._run_rapidocr_cached(pil_crop, branch=f"bench_{filter_name}_{time.time()}", dpi=int(300 * scale))
    conf = 0.72 # Mantém abaixo de 0.90 para forçar as 5 iterações
    text = cands[0].text if cands else "recon"
    return text, conf

t0 = time.time()
hist_5steps_full = recovery_engine.recover_region(
    region_id="reg_degraded_full",
    bbox=BoundingBox(x1=200, y1=500, x2=800, y2=900),
    initial_text="Texto degradado",
    initial_conf=0.45,
    region_processor_fn=region_processor_worst_case,
)
t_5steps_full = time.time() - t0

print("\n" + "="*80)
print("BENCHMARK DE LATÊNCIA — ITERATIVE RECOVERY ENGINE (CPU RYZEN 5 5500U)")
print("="*80)
print(f"1. Passo 0 (Bypass imediato quando conf >= 0.90)       : {t_1step*1000:>8.2f} ms")
print(f"2. Passo 1 (Região que resolve com early exit no passo 1): {t_single_pass:>8.3f} s")
print(f"3. Passos 1 a 5 (Pior caso: 5 passos completos sem 0.90): {t_5steps_full:>8.3f} s")
print(f"-> Tempo médio por passo na recuperação                : {t_5steps_full / 5.0:>8.3f} s")
print(f"-> Razão Pior Caso (5 Passos) vs 1 Passo               : {t_5steps_full / max(t_single_pass, 0.001):>8.2f}x")
print("="*80)

