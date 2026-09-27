"""
Benchmark Científico do Motor de Recuperação Iterativa na GPU (Capítulo 0, Item 3)
Mede o tempo por passo individual em 3 crops reais diferentes (Ayrosa, Dicionário, Barbosa).
"""
import sys
import os
import glob
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_DIR))

# Add NVIDIA DLL directories for CUDAExecutionProvider
base_nvidia = BACKEND_DIR / "venv" / "Lib" / "site-packages" / "nvidia"
for bin_dir in glob.glob(str(base_nvidia / "*" / "bin")):
    os.add_dll_directory(bin_dir)
    os.environ["PATH"] = bin_dir + os.pathsep + os.environ.get("PATH", "")

import time
import json

import numpy as np
import cv2
from PIL import Image
import pypdfium2 as pdfium

# Import modules from ocr_pipeline
from ocr_pipeline.rollback_engine.rollback_manager import RollbackManager, IterativeRecoveryEngine
from ocr_pipeline.core.provenance import BoundingBox

crops_dir = BACKEND_DIR / "scratch" / "bench_crops"
crops_dir.mkdir(parents=True, exist_ok=True)

# 1. Carregar 3 crops reais
pdf_configs = [
    {
        "name": "Ayrosa_p1_Crop",
        "pdf": BACKEND_DIR / "pdfs" / "Ayrosa_1943_ApontBibliogrLingTupiGuarani1ed.pdf",
        "page": 0, # página 1
        "box": (400, 300, 1000, 1200), # y1, x1, y2, x2
    },
    {
        "name": "Dicionario_p11_Crop",
        "pdf": BACKEND_DIR / "pdfs" / "Dicionário Tupi.pdf",
        "page": 10, # página 11
        "box": (500, 200, 1100, 900),
    },
    {
        "name": "Barbosa_p2_Crop",
        "pdf": BACKEND_DIR / "pdfs" / "Barbosa_1956_CursoDeTupiAntigo_BDCN_CNic.pdf",
        "page": 1, # página 2
        "box": (400, 300, 1000, 1100),
    }
]

extracted_crops = []
for cfg in pdf_configs:
    doc = pdfium.PdfDocument(str(cfg["pdf"]))
    page_img = doc.get_page(cfg["page"]).render(scale=2.0).to_pil()
    img_np = np.array(page_img)
    y1, x1, y2, x2 = cfg["box"]
    crop = img_np[y1:y2, x1:x2]
    crop_path = crops_dir / f"{cfg['name']}.png"
    Image.fromarray(crop).save(crop_path)
    print(f"Crop salvo: {crop_path} ({crop.shape[1]}x{crop.shape[0]} px)")
    extracted_crops.append({
        "name": cfg["name"],
        "crop_np": crop,
        "crop_path": str(crop_path),
        "dimensions": f"{crop.shape[1]}x{crop.shape[0]}"
    })

# 2. Inicializar RapidOCR com CUDA
from rapidocr_onnxruntime import RapidOCR
rapid_engine = RapidOCR(det_use_cuda=True, rec_use_cuda=True)

# Verificar PyTorch e GPU
gpu_info = {"cuda_available": False, "device_name": "N/A", "vram_mb": 0}
try:
    import torch
    gpu_info["cuda_available"] = torch.cuda.is_available()
    if torch.cuda.is_available():
        gpu_info["device_name"] = torch.cuda.get_device_name(0)
        gpu_info["vram_mb"] = round(torch.cuda.get_device_properties(0).total_memory / (1024**2), 1)
except Exception as e:
    gpu_info["error"] = str(e)

print(f"\nGPU Status: {gpu_info}")

rollback_mgr = RollbackManager(audit_log_path=BACKEND_DIR / "ocr_cache" / "bench_audit.jsonl")
recovery_engine = IterativeRecoveryEngine(rollback_mgr, max_iterations=5)

benchmark_data = {
    "gpu_info": gpu_info,
    "crops_tested": []
}

for crop_item in extracted_crops:
    crop_np = crop_item["crop_np"]
    cname = crop_item["name"]
    print(f"\n{'='*75}\nExecutando Benchmark de Recuperação Iterativa para: {cname}\n{'='*75}")
    
    step_measurements = []
    
    def detailed_processor_fn(filter_name: str, engine_name: str, scale: float) -> tuple[str, float]:
        t_start = time.perf_counter()
        
        # 1. Filtro
        t_f0 = time.perf_counter()
        processed = crop_np.copy()
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
        t_filter = (time.perf_counter() - t_f0) * 1000.0
        
        # 2. Redimensionamento por escala
        t_s0 = time.perf_counter()
        if scale != 1.0:
            h, w = processed.shape[:2]
            processed = cv2.resize(processed, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_LANCZOS4)
        t_scale = (time.perf_counter() - t_s0) * 1000.0
        
        # 3. Inferência OCR
        t_o0 = time.perf_counter()
        ocr_result, _ = rapid_engine(processed)
        t_ocr = (time.perf_counter() - t_o0) * 1000.0
        
        t_total = (time.perf_counter() - t_start) * 1000.0
        
        text_lines = []
        confs = []
        if ocr_result:
            for item in ocr_result:
                text_lines.append(item[1])
                confs.append(float(item[2]))
        
        avg_conf = (sum(confs) / len(confs)) if confs else 0.0
        full_text = " ".join(text_lines)
        
        step_measurements.append({
            "filter": filter_name,
            "engine": engine_name,
            "scale": scale,
            "filter_ms": round(t_filter, 2),
            "scale_ms": round(t_scale, 2),
            "ocr_ms": round(t_ocr, 2),
            "total_ms": round(t_total, 2),
            "chars_detected": len(full_text),
            "conf_achieved": round(avg_conf, 4)
        })
        
        # Retorna conf simulada < 0.90 para medir os 5 passos completos (pior caso determinístico)
        return full_text, min(avg_conf, 0.85)

    t0_all = time.perf_counter()
    history = recovery_engine.recover_region(
        region_id=f"reg_{cname}",
        bbox=BoundingBox(x1=100, y1=100, x2=800, y2=800),
        initial_text="",
        initial_conf=0.30,
        region_processor_fn=detailed_processor_fn
    )
    total_5steps_s = time.perf_counter() - t0_all
    
    crop_res = {
        "crop_name": cname,
        "dimensions": crop_item["dimensions"],
        "steps": step_measurements,
        "total_5steps_ms": round(total_5steps_s * 1000.0, 2),
        "step_1_ms": step_measurements[0]["total_ms"] if step_measurements else 0,
        "ratio_5_vs_1": round(sum(s["total_ms"] for s in step_measurements) / max(step_measurements[0]["total_ms"], 0.001), 2)
    }
    benchmark_data["crops_tested"].append(crop_res)
    
    print(f"| Passo | Filtro               | Escala | Filtro (ms) | Escala (ms) | OCR (ms)  | Total Passo (ms) |")
    print(f"| :---: | :------------------- | :----: | :---------: | :---------: | :-------: | :--------------: |")
    for idx, s in enumerate(step_measurements, 1):
        print(f"|   {idx}   | {s['filter']:<20} | {s['scale']:<6.1f} | {s['filter_ms']:>11.2f} | {s['scale_ms']:>11.2f} | {s['ocr_ms']:>9.2f} | {s['total_ms']:>16.2f} |")
    
    print(f"-> Razão 5 Passos / Passo 1 para {cname}: {crop_res['ratio_5_vs_1']}x\n")

out_file = BACKEND_DIR / "scratch" / "real_gpu_benchmark_results.json"
with open(out_file, "w", encoding="utf-8") as f:
    json.dump(benchmark_data, f, indent=2, ensure_ascii=False)

print(f"\nResultados gravados em: {out_file}")
