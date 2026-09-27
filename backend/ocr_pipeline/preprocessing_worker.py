"""
Worker de Pré-processamento e Restauração de Imagem (Etapas 1, 4 e 5 da Fase 1).
Implementa:
  - Nível 1 de restauração geométrica (deskew via minAreaRect / perspective).
  - Remoção robusta de bleed-through via Binarização Multiescala de Sauvola.
  - Super-resolução clássica via interpolação Lanczos + Máscara de Nitidez (Unsharp Mask).
"""
from typing import Any

import cv2
import numpy as np
from PIL import Image, ImageFilter


class PreprocessingWorker:
    def __init__(self, sauvola_window: int = 31, sauvola_k: float = 0.25):
        self.sauvola_window = sauvola_window if sauvola_window % 2 != 0 else sauvola_window + 1
        self.sauvola_k = sauvola_k

    def apply_super_resolution_lanczos(self, pil_img: Image.Image, min_width: int = 1500) -> tuple[Image.Image, bool]:
        """Aplica redimensionamento Lanczos e máscara de nitidez se a imagem for de baixa resolução."""
        w, h = pil_img.size
        applied = False
        if w < min_width:
            scale = min_width / w
            new_w = int(w * scale)
            new_h = int(h * scale)
            pil_img = pil_img.resize((new_w, new_h), resample=Image.Resampling.LANCZOS)
            # Unsharp mask para realçar bordas de caracteres tipográficos
            pil_img = pil_img.filter(ImageFilter.UnsharpMask(radius=1.5, percent=130, threshold=3))
            applied = True
        return pil_img, applied

    def apply_deskew(self, cv_img: np.ndarray) -> tuple[np.ndarray, float, bool]:
        """Detecta inclinação e aplica rotação afim corretiva."""
        gray = cv_img if len(cv_img.shape) == 2 else cv2.cvtColor(cv_img, cv2.COLOR_BGR2GRAY)
        _, thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
        coords = np.column_stack(np.where(thresh > 0))
        angle = 0.0
        applied = False
        h, w = gray.shape[:2]

        if len(coords) > 50:
            rect = cv2.minAreaRect(coords)
            angle = rect[-1]
            if angle < -45:
                angle = -(90 + angle)
            else:
                angle = -angle

            if 0.35 < abs(angle) < 15.0:
                center = (w // 2, h // 2)
                M = cv2.getRotationMatrix2D(center, angle, 1.0)
                cv_img = cv2.warpAffine(
                    cv_img, M, (w, h),
                    flags=cv2.INTER_CUBIC,
                    borderMode=cv2.BORDER_CONSTANT,
                    borderValue=255
                )
                applied = True

        return cv_img, round(angle, 3), applied

    def apply_sauvola_binarization(
        self,
        gray: np.ndarray,
        window_size: Optional[int] = None,
        k: Optional[float] = None,
        R: float = 128.0
    ) -> np.ndarray:
        """
        Binarização adaptativa de Sauvola & Pietikäinen (2000).
        Fórmula: T(x, y) = m(x, y) * (1 + k * (s(x, y) / R - 1))
        Remove eficientemente manchas de tinta do verso da folha (bleed-through).
        """
        w_size = window_size or self.sauvola_window
        if w_size % 2 == 0:
            w_size += 1
        k_val = k or self.sauvola_k

        # Cálculo vetorizado ultrarrápido com boxFilter
        img_f = gray.astype(np.float32)
        mean = cv2.boxFilter(img_f, cv2.CV_32F, (w_size, w_size))
        sq_mean = cv2.boxFilter(img_f**2, cv2.CV_32F, (w_size, w_size))
        variance = np.maximum(sq_mean - mean**2, 0)
        std = np.sqrt(variance)

        thresh = mean * (1.0 + k_val * (std / R - 1.0))
        # Pixels abaixo do limiar adaptativo OU com intensidade de tinta inequívoca (< 60) são primeiro plano (0)
        binary = np.where((gray < thresh) | (gray < 60), 0, 255).astype(np.uint8)
        return binary

    def process(
        self,
        pil_img: Image.Image,
        has_bleed_through: bool = False
    ) -> tuple[Image.Image, list[str], dict[str, Any]]:
        """Executa a cadeia completa de pré-processamento da Fase 1."""
        ops_applied = []
        metrics = {}

        # 1. Super-resolução Lanczos se necessário
        pil_img, sr_applied = self.apply_super_resolution_lanczos(pil_img)
        if sr_applied:
            ops_applied.append("super_resolution_lanczos")

        # 2. Conversão para OpenCV BGR e Escala de Cinza
        cv_img = cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)
        gray = cv2.cvtColor(cv_img, cv2.COLOR_BGR2GRAY)

        # 3. Deskew
        gray_deskewed, angle, deskew_applied = self.apply_deskew(gray)
        metrics["skew_corrected"] = angle
        if deskew_applied:
            ops_applied.append(f"deskew_{angle:.2f}deg")

        # 4. Remoção de Bleed-Through e Binarização
        if has_bleed_through:
            # Sauvola multiescala
            binary = self.apply_sauvola_binarization(gray_deskewed, window_size=31, k=0.25)
            ops_applied.append("sauvola_bleed_through_removal")
        else:
            # Otsu com denoise gaussiano suave
            blurred = cv2.GaussianBlur(gray_deskewed, (3, 3), 0)
            _, binary = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
            ops_applied.append("otsu_binarization")

        final_pil = Image.fromarray(binary)
        return final_pil, ops_applied, metrics
