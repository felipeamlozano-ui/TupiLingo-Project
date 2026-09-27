"""
Script de Download Seguro de Modelos com Verificação de Checksum SHA-256 (Capítulo 2.1).
Baixa modelos para models/ (DocLayout-YOLO, Real-ESRGAN).
"""
import hashlib
import json
import logging
import sys
import urllib.request
from pathlib import Path

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("model_downloader")

BACKEND_DIR = Path(__file__).resolve().parent.parent
MODELS_DIR = BACKEND_DIR / "models"
MODELS_DIR.mkdir(parents=True, exist_ok=True)

MODELS_REGISTRY = {
    "RealESRGAN_x2plus.pth": {
        "url": "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.1/RealESRGAN_x2plus.pth",
        "sha256": "49fafd45f8fd7aa8d31ab2a22d14d91b536c34494a5cfe31eb5d89c2fa266abb",
        "optional": True,
    },
    "DocLayout-YOLO.onnx": {
        "url": "https://huggingface.co/opendatalab/DocLayout-YOLO/resolve/main/doclayout_yolo.onnx",
        "sha256": None,
        "optional": True,
    }
}


def compute_sha256(filepath: Path) -> str:
    sha = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            sha.update(chunk)
    return sha.hexdigest()


def download_models():
    logger.info(f"Diretório de modelos: {MODELS_DIR}")
    for model_name, meta in MODELS_REGISTRY.items():
        target_path = MODELS_DIR / model_name
        if target_path.exists():
            current_hash = compute_sha256(target_path)
            logger.info(f"Modelo {model_name} já existe. SHA-256: {current_hash}")
            if meta.get("sha256") and current_hash != meta["sha256"]:
                logger.warning(f"Aviso: Checksum divergente para {model_name}. Re-download sugerido.")
            continue

        url = meta["url"]
        logger.info(f"Iniciando download de {model_name} de {url}...")
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "TupiLingo-Pipeline/5.0"})
            with urllib.request.urlopen(req, timeout=60) as resp, open(target_path, "wb") as out_f:
                total_bytes = 0
                while chunk := resp.read(1024 * 1024):
                    out_f.write(chunk)
                    total_bytes += len(chunk)
            
            calc_hash = compute_sha256(target_path)
            logger.info(f"Download concluído: {model_name} ({total_bytes / (1024**2):.1f} MB), SHA-256: {calc_hash}")
            if meta.get("sha256") and calc_hash != meta["sha256"]:
                raise ValueError(f"Checksum inválido para {model_name}! Esperado: {meta['sha256']}, obtido: {calc_hash}")
        except Exception as e:
            if meta.get("optional"):
                logger.warning(f"Download de {model_name} não pôde ser completado ({e}). Operando com fallback geométrico/Lanczos.")
                if target_path.exists():
                    target_path.unlink()
            else:
                logger.error(f"Falha crítica no download de {model_name}: {e}")
                sys.exit(1)


if __name__ == "__main__":
    download_models()
