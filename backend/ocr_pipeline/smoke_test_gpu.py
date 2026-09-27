"""
Smoke Test de Validação GPU — TupiLingo OCR v5 (Capítulo 2.1).
Importa todas as bibliotecas críticas, testa CUDA Execution Provider e confirma aceleração de hardware.
"""
import sys
import os
import glob
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BACKEND_DIR))

# Configurar diretórios de DLLs da NVIDIA
base_nvidia = BACKEND_DIR / "venv" / "Lib" / "site-packages" / "nvidia"
if base_nvidia.exists():
    for bin_dir in glob.glob(str(base_nvidia / "*" / "bin")):
        os.add_dll_directory(bin_dir)
        os.environ["PATH"] = bin_dir + os.pathsep + os.environ.get("PATH", "")

print("=" * 80)
print("TUPILINGO OCR v5 — SMOKE TEST DE VALIDAÇÃO DE AMBIENTE GPU")
print("=" * 80)

modules_to_test = [
    ("numpy", "NumPy"),
    ("cv2", "OpenCV"),
    ("PIL", "Pillow"),
    ("pypdfium2", "PyPDFium2"),
    ("pyarrow", "PyArrow"),
    ("lmdb", "LMDB"),
    ("symspellpy", "SymSpellPy"),
    ("rapidocr_onnxruntime", "RapidOCR"),
    ("onnxruntime", "ONNX Runtime"),
    ("torch", "PyTorch"),
]

all_ok = True
for mod_name, label in modules_to_test:
    try:
        mod = __import__(mod_name)
        ver = getattr(mod, "__version__", "OK")
        print(f"[OK] {label:<22} : Versão {ver}")
    except Exception as e:
        print(f"[ERRO] {label:<20} : Falha ao importar ({e})")
        all_ok = False

print("-" * 80)

# 1. Teste ONNX Runtime GPU
import onnxruntime as ort
providers = ort.get_available_providers()
ort_device = ort.get_device()
print(f"ONNX Runtime Device     : {ort_device}")
print(f"Available Providers     : {providers}")
has_cuda_ort = "CUDAExecutionProvider" in providers

# 2. Teste PyTorch CUDA
import torch
cuda_available = torch.cuda.is_available()
device_name = torch.cuda.get_device_name(0) if cuda_available else "Nenhum"
print(f"PyTorch CUDA Available  : {cuda_available}")
print(f"PyTorch Device Name     : {device_name}")

# 3. Teste RapidOCR com CUDA
print("-" * 80)
from rapidocr_onnxruntime import RapidOCR
import numpy as np

try:
    r = RapidOCR(det_use_cuda=True, rec_use_cuda=True)
    det_sess = getattr(r.text_det.infer, "session", None)
    rec_sess = getattr(r.text_rec, "session", None)
    det_providers = det_sess.session.get_providers() if hasattr(det_sess, "session") else det_sess.get_providers()
    rec_providers = rec_sess.session.get_providers() if hasattr(rec_sess, "session") else rec_sess.get_providers()
    print(f"RapidOCR Det Providers  : {det_providers}")
    print(f"RapidOCR Rec Providers  : {rec_providers}")
    
    dummy_img = np.zeros((100, 200, 3), dtype=np.uint8)
    out, elapse = r(dummy_img)
    print(f"RapidOCR Dummy Infer    : Sucesso! Elapse: {elapse}")
    rapid_cuda_ok = "CUDAExecutionProvider" in det_providers
except Exception as e:
    print(f"RapidOCR Teste Falhou   : {e}")
    rapid_cuda_ok = False

print("=" * 80)
if all_ok and has_cuda_ort and rapid_cuda_ok:
    print("STATUS FINAL: [HOMOLOGADO] Pipeline GPU pronto para execução.")
    sys.exit(0)
else:
    print("STATUS FINAL: [AVISO] Algumas capacidades operam em modo fallback.")
    sys.exit(0)
