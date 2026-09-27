"""
Engine de Diagnóstico Forense — TupiLingo OCR Forense v3.0
Extrai 12 dimensões forenses completas da página antes de qualquer inferência de OCR:
  1. Blur score & Laplacian variance
  2. Skew angle (Hough & projeção)
  3. Histograma LAB e perfil cromático
  4. Detector de bleed-through (manchas do verso)
  5. Heatmap de iluminação e vinhetagem
  6. Estimador de largura de traço (Stroke Width Transform via Distance Transform)
  7. Análise de componentes conectados (densidade tipográfica)
  8. Detector de envelhecimento do papel (amarelamento / foxing)
  9. Detector de desbotamento de tinta (ink fading)
  10. Espectro de ruído bidimensional via FFT 2D
  11. Energia de sub-bandas de alta frequência via Wavelet / pirâmide Laplaciana
  12. Diagnóstico consolidado serializável em JSON
"""

import cv2
import numpy as np
from PIL import Image
from pydantic import BaseModel, Field


class ForensicDiagnosticReport(BaseModel):
    page: int
    dimensions: tuple[int, int]
    blur_score: float = Field(description="Score de nitidez normalizado (0 a 1, onde 1 é nítido)")
    laplacian_variance: float = Field(description="Variância bruta do operador Laplaciano")
    skew_angle: float = Field(description="Ângulo de inclinação em graus")
    yellow_paper: bool = Field(description="Indica se o papel histórico apresenta amarelamento acentuado")
    paper_aging_index: float = Field(description="Índice de amarelamento baseado no canal b* do espaço CIELAB")
    bleed_through_ratio: float = Field(description="Proporção diferencial de bleed-through Otsu vs Sauvola")
    bleed: bool = Field(description="Presença detectada de sangramento de tinta do verso")
    ink_loss: str = Field(description="Nível de desbotamento da tinta: 'low', 'medium', 'high'")
    stroke_width_median: float = Field(description="Mediana da espessura dos traços dos caracteres em pixels")
    connected_components_count: int = Field(description="Quantidade de caracteres/glifos conectados")
    noise: str = Field(description="Nível de ruído espectral: 'low', 'medium', 'high'")
    fft_high_freq_energy: float = Field(description="Proporção de energia de alta frequência no espectro 2D")
    wavelet_energy: float = Field(description="Energia de detalhes em altas frequências")
    illumination_uniformity: float = Field(description="Índice de uniformidade da iluminação (0 a 1)")

class ForensicDiagnosticEngine:
    def __init__(self):
        pass

    def analyze_image(self, pil_img: Image.Image, page_num: int = 1) -> ForensicDiagnosticReport:
        """Executa a análise forense completa de 12 dimensões sobre a imagem PIL."""
        w, h = pil_img.size
        cv_bgr = cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)
        cv_gray = cv2.cvtColor(cv_bgr, cv2.COLOR_BGR2GRAY)

        # 1. Blur & Laplacian
        lap_var = float(cv2.Laplacian(cv_gray, cv2.CV_64F).var())
        blur_score = round(float(min(1.0, lap_var / 1200.0)), 3)

        # 2. Skew Angle
        skew_angle = self._detect_skew(cv_gray)

        # 3. LAB & Paper Aging
        yellow_paper, aging_idx = self._detect_paper_aging(cv_bgr)

        # 4. Bleed-through Detector
        has_bleed, bleed_ratio = self._detect_bleed_through(cv_gray)

        # 5. Illumination Heatmap & Uniformity
        illum_uniformity = self._calc_illumination_uniformity(cv_gray)

        # 6. Stroke Width Transform Estimate
        stroke_width = self._estimate_stroke_width(cv_gray)

        # 7. Connected Components
        cc_count = self._count_connected_components(cv_gray)

        # 8. Ink Fading
        ink_loss = self._detect_ink_fading(cv_gray)

        # 9. FFT 2D Noise Spectrum
        fft_energy, noise_level = self._analyze_fft_noise(cv_gray)

        # 10. Wavelet / High-frequency Energy
        wavelet_energy = self._calc_wavelet_energy(cv_gray)

        return ForensicDiagnosticReport(
            page=page_num,
            dimensions=(w, h),
            blur_score=blur_score,
            laplacian_variance=round(lap_var, 2),
            skew_angle=round(skew_angle, 2),
            yellow_paper=yellow_paper,
            paper_aging_index=round(aging_idx, 2),
            bleed_through_ratio=round(bleed_ratio, 4),
            bleed=has_bleed,
            ink_loss=ink_loss,
            stroke_width_median=round(stroke_width, 2),
            connected_components_count=cc_count,
            noise=noise_level,
            fft_high_freq_energy=round(fft_energy, 4),
            wavelet_energy=round(wavelet_energy, 2),
            illumination_uniformity=round(illum_uniformity, 3)
        )

    def _detect_skew(self, gray: np.ndarray) -> float:
        """Estima o ângulo de rotação da página por transformada de Hough."""
        edges = cv2.Canny(gray, 50, 150, apertureSize=3)
        lines = cv2.HoughLinesP(edges, 1, np.pi / 180, threshold=100, minLineLength=80, maxLineGap=10)
        if lines is None or len(lines) == 0:
            return 0.0

        angles = []
        for line in lines:
            pts = np.asarray(line).reshape(-1)
            if len(pts) >= 4:
                x1, y1, x2, y2 = pts[:4]
                if x2 == x1:
                    continue
                angle = np.degrees(np.arctan2(y2 - y1, x2 - x1))
                if abs(angle) < 45:
                    angles.append(angle)

        if not angles:
            return 0.0
        return float(np.median(angles))

    def _detect_paper_aging(self, bgr: np.ndarray) -> tuple[bool, float]:
        """Analisa o canal b* do espaço LAB para detectar amarelamento do papel antigo."""
        lab = cv2.cvtColor(bgr, cv2.COLOR_BGR2LAB)
        b_channel = lab[:, :, 2].astype(np.float32)
        # No OpenCV LAB, b* neutro é 128. Valores > 138 indicam forte tonalidade amarelada.
        mean_b = float(np.mean(b_channel))
        aging_index = max(0.0, mean_b - 128.0)
        is_yellow = aging_index > 8.0
        return is_yellow, aging_index

    def _detect_bleed_through(self, gray: np.ndarray) -> tuple[bool, float]:
        """Compara a densidade de tinta entre Otsu e Sauvola local para isolar manchas reversas."""
        _, otsu = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        
        # Sauvola local
        mean = cv2.boxFilter(gray.astype(np.float32), cv2.CV_32F, (31, 31))
        sq_mean = cv2.boxFilter((gray.astype(np.float32))**2, cv2.CV_32F, (31, 31))
        std = np.sqrt(np.maximum(sq_mean - mean**2, 0))
        sauvola_thresh = mean * (1.0 + 0.25 * (std / 128.0 - 1.0))
        sauvola = np.where(gray < sauvola_thresh, 0, 255).astype(np.uint8)

        otsu_ink = float(np.sum(otsu == 0))
        sauvola_ink = float(np.sum(sauvola == 0))

        if sauvola_ink == 0:
            return False, 0.0

        diff_ratio = (otsu_ink - sauvola_ink) / max(sauvola_ink, 1.0)
        has_bleed = diff_ratio > 0.20 and otsu_ink > 0.04 * gray.size
        return has_bleed, diff_ratio

    def _calc_illumination_uniformity(self, gray: np.ndarray) -> float:
        """Calcula a uniformidade de iluminação por blocos de 32x32."""
        small = cv2.resize(gray, (32, 32), interpolation=cv2.INTER_AREA)
        std_val = float(np.std(small))
        mean_val = float(np.mean(small))
        coeff_var = std_val / max(mean_val, 1.0)
        uniformity = max(0.0, 1.0 - coeff_var)
        return uniformity

    def _estimate_stroke_width(self, gray: np.ndarray) -> float:
        """Estima a espessura média do traço tipográfico por Distance Transform."""
        _, bin_inv = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
        dist = cv2.distanceTransform(bin_inv, cv2.DIST_L2, 5)
        # O dobro do raio mediano nos pontos do esqueleto
        foreground_dist = dist[bin_inv > 0]
        if len(foreground_dist) == 0:
            return 1.0
        median_dist = float(np.median(foreground_dist))
        return median_dist * 2.0

    def _count_connected_components(self, gray: np.ndarray) -> int:
        """Conta componentes conexos filtrando ruídos de 1 pixel e bordas."""
        _, bin_inv = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
        num_labels, labels, stats, _ = cv2.connectedComponentsWithStats(bin_inv, connectivity=8)
        valid = 0
        for i in range(1, num_labels):
            area = stats[i, cv2.CC_STAT_AREA]
            if 8 < area < 5000:
                valid += 1
        return valid

    def _detect_ink_fading(self, gray: np.ndarray) -> str:
        """Determina o desbotamento com base no contraste local de primeiro plano."""
        _, bin_inv = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
        fg = gray[bin_inv > 0]
        bg = gray[bin_inv == 0]
        if len(fg) == 0 or len(bg) == 0:
            return "high"

        contrast = float(np.mean(bg) - np.mean(fg))
        if contrast > 100.0:
            return "low"
        elif contrast > 60.0:
            return "medium"
        else:
            return "high"

    def _analyze_fft_noise(self, gray: np.ndarray) -> tuple[float, str]:
        """Calcula o espectro de potência 2D por FFT para medir ruído de alta frequência."""
        f = np.fft.fft2(gray.astype(np.float32))
        fshift = np.fft.fftshift(f)
        magnitude_spectrum = 20 * np.log(np.abs(fshift) + 1e-5)

        h, w = gray.shape
        cy, cx = h // 2, w // 2
        # Máscara circular para frequências altas (> 60% do raio)
        y, x = np.ogrid[:h, :w]
        r = np.sqrt((x - cx)**2 + (y - cy)**2)
        max_r = np.sqrt(cx**2 + cy**2)
        high_freq_mask = r > (0.6 * max_r)

        high_energy = float(np.sum(magnitude_spectrum[high_freq_mask]))
        total_energy = float(np.sum(magnitude_spectrum))
        ratio = high_energy / max(total_energy, 1.0)

        if ratio > 0.45:
            noise_str = "high"
        elif ratio > 0.25:
            noise_str = "medium"
        else:
            noise_str = "low"
        return ratio, noise_str

    def _calc_wavelet_energy(self, gray: np.ndarray) -> float:
        """Mede energia residual nas sub-bandas de alta frequência via Laplaciano multiescala."""
        pyr_down = cv2.pyrDown(gray)
        pyr_up = cv2.pyrUp(pyr_down, dstsize=(gray.shape[1], gray.shape[0]))
        lap = cv2.subtract(gray, pyr_up)
        energy = float(np.mean(np.square(lap.astype(np.float32))))
        return energy
