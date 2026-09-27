"""
Engine de OCR Ensemble Multi-Motor GPU — TupiLingo OCR Forense v5
Combina múltiplos motores de reconhecimento, múltiplos PSMs e múltiplos níveis de resolução:
  - RapidOCR GPU (CUDAExecutionProvider via ONNX Runtime com fallback para CPU)
  - Tesseract OCR (LSTM com user-words Tupi e múltiplos PSMs validados: 3, 6, 11, 4)
  - Multi-DPI scaling (300 e 450 DPI)
  - Cache determinístico por hash de imagem e parâmetros de motor
"""
import hashlib
import json
import os
import platform
import unicodedata
from pathlib import Path
from typing import Any, Optional

import numpy as np
from PIL import Image

from ..core.config import GLOBAL_CONFIG
from ..core.provenance import BoundingBox

if platform.system() == "Windows":
    DEFAULT_TESSERACT_CMD = r"C:\Program Files\Tesseract-OCR\tesseract.exe"
else:
    DEFAULT_TESSERACT_CMD = "tesseract"


class OCRCandidate:
    def __init__(
        self,
        text: str,
        confidence: float,
        engine: str,
        bbox: BoundingBox,
        psm: Optional[int] = None,
        dpi: int = 300,
        branch: str = "default",
    ):
        self.text = text
        self.confidence = confidence
        self.engine = engine
        self.bbox = bbox
        self.psm = psm
        self.dpi = dpi
        self.branch = branch

    def to_dict(self) -> dict[str, Any]:
        return {
            "text": self.text,
            "confidence": self.confidence,
            "engine": self.engine,
            "bbox": (self.bbox.x1, self.bbox.y1, self.bbox.x2, self.bbox.y2),
            "psm": self.psm,
            "dpi": self.dpi,
            "branch": self.branch,
        }


class ForensicEnsembleEngine:
    def __init__(
        self,
        tupi_words_path: Optional[str] = None,
        cpu_threads: int = 6,
        tesseract_cmd: Optional[str] = None,
        use_gpu: bool = True,
    ):
        self.tupi_words_path = tupi_words_path or str(GLOBAL_CONFIG.tupi_words_file)
        self.cpu_threads = cpu_threads
        self.tesseract_cmd = tesseract_cmd or DEFAULT_TESSERACT_CMD
        self.use_gpu = use_gpu
        self.cache_dir = GLOBAL_CONFIG.cache_dir / "ensemble_cache"
        self.cache_dir.mkdir(parents=True, exist_ok=True)

        self._init_cuda_environment()
        self._init_tesseract()
        self._init_rapidocr()

    def _init_cuda_environment(self):
        """Carrega DLLs CUDA/cuDNN do ambiente virtual."""
        if not self.use_gpu or platform.system() != "Windows":
            return
        venv_nvidia = Path(__file__).resolve().parent.parent.parent / "venv" / "Lib" / "site-packages" / "nvidia"
        if venv_nvidia.exists():
            for sub in venv_nvidia.iterdir():
                bin_dir = sub / "bin"
                if bin_dir.exists():
                    try:
                        os.add_dll_directory(str(bin_dir))
                    except Exception:
                        pass

    def _init_tesseract(self):
        try:
            import pytesseract
            pytesseract.pytesseract.tesseract_cmd = self.tesseract_cmd
            self.pytesseract = pytesseract
            self.tesseract_available = True
        except Exception:
            self.pytesseract = None
            self.tesseract_available = False

    def _init_rapidocr(self):
        try:
            from rapidocr_onnxruntime import RapidOCR
            os.environ["OMP_NUM_THREADS"] = str(self.cpu_threads)
            os.environ["MKL_NUM_THREADS"] = str(self.cpu_threads)
            # Inicializa RapidOCR (CUDAExecutionProvider selecionado automaticamente pelo onnxruntime-gpu)
            self.rapidocr = RapidOCR()
            self.rapidocr_available = True
        except Exception:
            self.rapidocr = None
            self.rapidocr_available = False

    @staticmethod
    def _compute_hash(pil_img: Image.Image, params: dict[str, Any]) -> str:
        h = hashlib.sha256(pil_img.tobytes())
        h.update(json.dumps(params, sort_keys=True).encode("utf-8"))
        return h.hexdigest()

    def run_ensemble(
        self,
        pil_img: Image.Image,
        psms: Optional[list[int]] = None,
        branch: str = "default",
        dpi: int = 300,
    ) -> list[OCRCandidate]:
        """
        Executa ensemble com RapidOCR GPU e múltiplos modos de Tesseract (PSMs 3, 6, 11).
        Utiliza cache determinístico para evitar reprocessamento desnecessário.
        """
        psms = psms or [6, 3, 11]  # Modos homologados no Capítulo 7.3
        candidates: list[OCRCandidate] = []

        # 1. Execução RapidOCR GPU
        rapid_cand = self._run_rapidocr_cached(pil_img, branch=branch, dpi=dpi)
        if rapid_cand:
            candidates.extend(rapid_cand)

        # 2. Execução Tesseract com múltiplos PSMs
        for psm in psms:
            tess_cand = self._run_tesseract_cached(pil_img, psm=psm, branch=branch, dpi=dpi)
            if tess_cand:
                candidates.extend(tess_cand)

        return candidates

    def _run_rapidocr_cached(self, pil_img: Image.Image, branch: str, dpi: int) -> list[OCRCandidate]:
        if not self.rapidocr_available or self.rapidocr is None:
            return []

        cache_key = self._compute_hash(pil_img, {"engine": "rapidocr_gpu", "branch": branch, "dpi": dpi})
        cache_path = self.cache_dir / f"{cache_key}.json"

        if cache_path.exists():
            try:
                with open(cache_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    return [OCRCandidate(
                        text=item["text"],
                        confidence=item["confidence"],
                        engine=item["engine"],
                        bbox=BoundingBox(x1=item["bbox"][0], y1=item["bbox"][1], x2=item["bbox"][2], y2=item["bbox"][3]),
                        psm=item.get("psm"),
                        dpi=item.get("dpi", dpi),
                        branch=item.get("branch", branch),
                    ) for item in data]
            except Exception:
                pass

        try:
            img_np = np.array(pil_img)
            result, _ = self.rapidocr(img_np)
            candidates = []
            if result:
                for item in result:
                    bbox_raw, text, conf = item[0], item[1].strip(), float(item[2])
                    if text:
                        xs = [pt[0] for pt in bbox_raw]
                        ys = [pt[1] for pt in bbox_raw]
                        bbox = BoundingBox(x1=int(min(xs)), y1=int(min(ys)), x2=int(max(xs)), y2=int(max(ys)))
                        cand = OCRCandidate(
                            text=unicodedata.normalize("NFC", text),
                            confidence=round(conf * 100.0, 2),
                            engine="rapidocr_gpu",
                            bbox=bbox,
                            dpi=dpi,
                            branch=branch,
                        )
                        candidates.append(cand)

            with open(cache_path, "w", encoding="utf-8") as f:
                json.dump([c.to_dict() for c in candidates], f, ensure_ascii=False)
            return candidates
        except Exception:
            return []

    def _run_tesseract_cached(self, pil_img: Image.Image, psm: int, branch: str, dpi: int) -> list[OCRCandidate]:
        if not self.tesseract_available or self.pytesseract is None:
            return []

        cache_key = self._compute_hash(pil_img, {"engine": "tesseract", "psm": psm, "branch": branch, "dpi": dpi})
        cache_path = self.cache_dir / f"{cache_key}.json"

        if cache_path.exists():
            try:
                with open(cache_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    return [OCRCandidate(
                        text=item["text"],
                        confidence=item["confidence"],
                        engine=item["engine"],
                        bbox=BoundingBox(x1=item["bbox"][0], y1=item["bbox"][1], x2=item["bbox"][2], y2=item["bbox"][3]),
                        psm=item.get("psm"),
                        dpi=item.get("dpi", dpi),
                        branch=item.get("branch", branch),
                    ) for item in data]
            except Exception:
                pass

        config_parts = [f"--oem 1 --psm {psm}"]
        if self.tupi_words_path and os.path.exists(self.tupi_words_path):
            config_parts.append(f'--user-words "{self.tupi_words_path}"')
        tess_config = " ".join(config_parts)

        try:
            data = self.pytesseract.image_to_data(
                pil_img,
                lang="por+eng",
                config=tess_config,
                output_type=self.pytesseract.Output.DICT,
            )
            candidates = []
            for i in range(len(data["text"])):
                word = data["text"][i].strip()
                conf = float(data["conf"][i])
                if word and conf > 0:
                    bbox = BoundingBox(
                        x1=data["left"][i],
                        y1=data["top"][i],
                        x2=data["left"][i] + data["width"][i],
                        y2=data["top"][i] + data["height"][i],
                    )
                    cand = OCRCandidate(
                        text=unicodedata.normalize("NFC", word),
                        confidence=round(conf, 2),
                        engine=f"tesseract_psm{psm}",
                        bbox=bbox,
                        psm=psm,
                        dpi=dpi,
                        branch=branch,
                    )
                    candidates.append(cand)

            with open(cache_path, "w", encoding="utf-8") as f:
                json.dump([c.to_dict() for c in candidates], f, ensure_ascii=False)
            return candidates
        except Exception:
            return []
