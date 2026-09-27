"""
Worker de Reconhecimento Óptico de Caracteres Dual-Motor e Votação (Etapas 6 e 7 da Fase 1).
Combina:
  1. Tesseract OCR (LSTM --oem 1 + lang por+eng + --user-words tupi_user_words.txt).
  2. RapidOCR (ONNX Runtime PaddleOCR PP-OCRv4 em CPU responsável com threads controladas).
  3. Normalização Unicode NFC obrigatória.
  4. Votação ponderada e rastreamento completo de proveniência por token/linha.
"""
import os
import platform
import re
import unicodedata
from typing import Any

import numpy as np
from PIL import Image

# Configuração de Tesseract
if platform.system() == "Windows":
    DEFAULT_TESSERACT_CMD = r"C:\Program Files\Tesseract-OCR\tesseract.exe"
else:
    DEFAULT_TESSERACT_CMD = "tesseract"

class OCRWorker:
    def __init__(
        self,
        tupi_words_path: str | None = None,
        cpu_threads: int = 4,
        tesseract_cmd: str | None = None
    ):
        self.tesseract_cmd = tesseract_cmd or DEFAULT_TESSERACT_CMD
        self.tupi_words_path = tupi_words_path
        self.cpu_threads = cpu_threads
        
        # Inicialização do Tesseract
        self._init_tesseract()
        # Inicialização responsável do RapidOCR (PaddleOCR ONNX)
        self._init_rapidocr()

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
            # Execução responsável em CPU: limita threads e desabilita saturação
            os.environ["OMP_NUM_THREADS"] = str(self.cpu_threads)
            os.environ["MKL_NUM_THREADS"] = str(self.cpu_threads)
            self.rapidocr = RapidOCR()
            self.rapidocr_available = True
        except Exception:
            self.rapidocr = None
            self.rapidocr_available = False

    @staticmethod
    def normalize_nfc(text: str) -> str:
        """Aplica normalização Unicode NFC obrigatória (Etapa 7)."""
        if not text:
            return ""
        return unicodedata.normalize("NFC", text)

    def run_tesseract(self, pil_img: Image.Image, psm: int = 6) -> tuple[str, float, float, list[dict[str, Any]]]:
        """Executa Tesseract com captura de confiança por token e dicionário Tupi."""
        if not self.tesseract_available or self.pytesseract is None:
            return "", 0.0, 0.0, []

        config_parts = [f"--oem 1 --psm {psm}"]
        if self.tupi_words_path and os.path.exists(self.tupi_words_path):
            config_parts.append(f'--user-words "{self.tupi_words_path}"')
        tess_config = " ".join(config_parts)

        try:
            data = self.pytesseract.image_to_data(
                pil_img,
                lang="por+eng",
                config=tess_config,
                output_type=self.pytesseract.Output.DICT
            )
            words = []
            confs = []
            token_boxes = []

            for i in range(len(data["text"])):
                word = data["text"][i].strip()
                conf = float(data["conf"][i])
                if word and conf > 0:
                    words.append(word)
                    confs.append(conf)
                    token_boxes.append({
                        "text": word,
                        "conf": conf,
                        "bbox": (data["left"][i], data["top"][i], data["left"][i] + data["width"][i], data["top"][i] + data["height"][i]),
                        "engine": "tesseract"
                    })

            text = " ".join(words)
            mean_conf = float(np.mean(confs)) if confs else 0.0
            min_conf = float(np.min(confs)) if confs else 0.0
            return self.normalize_nfc(text), round(mean_conf, 2), round(min_conf, 2), token_boxes

        except Exception:
            return "", 0.0, 0.0, []

    def run_rapidocr(self, pil_img: Image.Image) -> tuple[str, float, float, list[dict[str, Any]]]:
        """Executa RapidOCR (PaddleOCR ONNX) com extração de confiança e bounding boxes."""
        if not self.rapidocr_available or self.rapidocr is None:
            return "", 0.0, 0.0, []

        try:
            img_np = np.array(pil_img)
            result, _ = self.rapidocr(img_np)
            if not result:
                return "", 0.0, 0.0, []

            lines = []
            confs = []
            token_boxes = []

            for item in result:
                bbox_raw, text, conf = item[0], item[1].strip(), float(item[2])
                if text:
                    lines.append(text)
                    confs.append(conf * 100.0) # Converte para escala 0-100
                    # bbox: [[x1, y1], [x2, y2], [x3, y3], [x4, y4]]
                    xs = [pt[0] for pt in bbox_raw]
                    ys = [pt[1] for pt in bbox_raw]
                    token_boxes.append({
                        "text": text,
                        "conf": conf * 100.0,
                        "bbox": (int(min(xs)), int(min(ys)), int(max(xs)), int(max(ys))),
                        "engine": "rapidocr"
                    })

            full_text = "\n".join(lines)
            mean_conf = float(np.mean(confs)) if confs else 0.0
            min_conf = float(np.min(confs)) if confs else 0.0
            return self.normalize_nfc(full_text), round(mean_conf, 2), round(min_conf, 2), token_boxes

        except Exception:
            return "", 0.0, 0.0, []

    def vote_and_reconcile(
        self,
        tess_text: str,
        tess_conf: float,
        rapid_text: str,
        rapid_conf: float
    ) -> tuple[str, float, float, str, dict[str, Any]]:
        """
        Votação e reconciliação entre Tesseract e RapidOCR.
        Calcula taxa de concordância léxica (Jaccard sobre tokens).
        Se divergirem, escolhe o motor com maior pontuação sintática e confiança,
        preservando diacríticos Tupi se presentes no Tesseract.
        """
        tess_words = set(re.findall(r"\w+", tess_text.lower()))
        rapid_words = set(re.findall(r"\w+", rapid_text.lower()))

        intersection = tess_words.intersection(rapid_words)
        union = tess_words.union(rapid_words)
        agreement_rate = (len(intersection) / len(union)) if union else 1.0

        provenance = {
            "tesseract_char_count": len(tess_text),
            "tesseract_mean_conf": tess_conf,
            "rapidocr_char_count": len(rapid_text),
            "rapidocr_mean_conf": rapid_conf,
            "lexical_agreement_rate": round(agreement_rate, 4),
            "winner_engine": "tesseract"
        }

        # Decisão de seleção
        # 1. Se RapidOCR tiver confiança significativamente maior e comprimento comparável
        if rapid_conf > (tess_conf + 12.0) and len(rapid_text) > 0.5 * len(tess_text):
            winner_text = rapid_text
            winner_conf = rapid_conf
            winner_engine = "rapidocr"
        # 2. Se Tesseract tiver capturado caracteres Tupi com diacrítico nasal (ex: ~ nas vogais ẽ, ĩ, ỹ)
        elif re.search(r"[ẽĩỹõãẽẼĨỸÕÃ]", tess_text) or tess_conf >= rapid_conf or len(tess_text) >= len(rapid_text):
            winner_text = tess_text
            winner_conf = tess_conf
            winner_engine = "tesseract"
        else:
            winner_text = rapid_text
            winner_conf = rapid_conf
            winner_engine = "rapidocr"

        provenance["winner_engine"] = winner_engine
        return winner_text, winner_conf, agreement_rate, winner_engine, provenance
