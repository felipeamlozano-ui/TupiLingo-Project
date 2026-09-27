"""
Engine de Diagnóstico Forense de PDFs — TupiLingo OCR v5 (Capítulo 3).
Extrai métricas visuais, estruturais, cromáticas e geométricas de cada página,
produzindo o page_profile.json para podar as 40 branches do Capítulo 4.
"""
from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any

import cv2
import numpy as np
from PIL import Image
from pydantic import BaseModel, Field

logger = logging.getLogger("ocr_pipeline.diagnostic_engine")


class PageProfile(BaseModel):
    page: int
    dimensions: tuple[int, int]
    # Qualidade Visual
    laplacian_variance: float = Field(description="Variância bruta do operador Laplaciano")
    focus_score: float = Field(description="Score normalizado de foco (0 a 1)")
    contrast_rms: float = Field(description="Contraste RMS do canal de luminância")
    blur_score: float = Field(description="Score de nitidez normalizado")
    has_motion_blur: bool = Field(default=False)
    has_gaussian_blur: bool = Field(default=False)

    # Estrutura
    column_count_estimate: int = Field(default=1, description="Estimativa de colunas (1, 2 ou 3)")
    margins: dict[str, int] = Field(default_factory=dict, description="Margens estimadas em pixels")
    has_header: bool = Field(default=False)
    has_footer: bool = Field(default=False)
    has_illustrations_or_tables: bool = Field(default=False)

    # Papel & Crominância (Espaço LAB)
    yellow_paper: bool = Field(description="Presença de amarelamento acentuado")
    paper_aging_index: float = Field(description="Índice de envelhecimento no canal b* CIELAB")
    foxing_detected: bool = Field(default=False, description="Presença de manchas de oxidação/foxing")
    bleed_through_ratio: float = Field(description="Proporção diferencial de bleed-through")
    bleed: bool = Field(description="Presença de sangramento de tinta do verso")

    # Texto
    stroke_width_median: float = Field(description="Mediana da espessura dos traços em pixels")
    connected_components_count: int = Field(description="Quantidade de componentes conexos válidos")
    ink_loss: str = Field(description="Nível de desbotamento: low, medium, high")
    noise_level: str = Field(description="Nível de ruído espectral: low, medium, high")
    fft_high_freq_energy: float = Field(description="Proporção de energia de alta frequência")
    wavelet_energy: float = Field(description="Energia de sub-bandas de alta frequência")
    illumination_uniformity: float = Field(description="Índice de uniformidade de iluminação")

    # Geometria & Orientação (Resolve Dicionário p.11)
    skew_angle: float = Field(description="Ângulo de inclinação em graus (-45 a +45)")
    needs_dewarp: bool = Field(default=False, description="Indica distorção geométrica/encadernação")
    orientation_degrees: int = Field(default=0, description="Orientação cardinal detectada (0, 90, 180, 270)")
    needs_rotation_180: bool = Field(default=False, description="Página invertida de cabeça para baixo")

    # Poda de Branches do Capítulo 4
    recommended_branches: list[str] = Field(default_factory=list, description="Lista de branches elegíveis")

    def save_json(self, output_path: Path) -> None:
        """Salva o page_profile.json da página."""
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(self.model_dump(), f, indent=2, ensure_ascii=False)


# Alias de compatibilidade retroativa
ForensicDiagnosticReport = PageProfile


class ForensicDiagnosticEngine:
    """Motor forense de diagnóstico e poda de branches para o pipeline TupiLingo v5."""

    def __init__(self):
        pass

    def analyze_image(self, pil_img: Image.Image, page_num: int = 1) -> PageProfile:
        w, h = pil_img.size
        cv_bgr = cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)
        cv_gray = cv2.cvtColor(cv_bgr, cv2.COLOR_BGR2GRAY)

        # 1. Qualidade Visual (Blur, Foco, RMS)
        lap_var = float(cv2.Laplacian(cv_gray, cv2.CV_64F).var())
        focus_score = round(float(min(1.0, lap_var / 1000.0)), 3)
        blur_score = round(float(min(1.0, lap_var / 1200.0)), 3)
        contrast_rms = round(float(np.std(cv_gray)), 2)

        has_motion_blur = False
        has_gaussian_blur = False
        if lap_var < 50.0:
            if contrast_rms < 35.0:
                has_gaussian_blur = True
            else:
                has_motion_blur = True

        # 2. Geometria, Skew & Orientação (0, 90, 180, 270)
        skew_angle = self._detect_skew(cv_gray)
        orientation, is_180 = self._detect_orientation(cv_gray)
        needs_dewarp = abs(skew_angle) > 2.5 or self._detect_curvature(cv_gray)

        # 3. Papel & Crominância (LAB, Bleed, Foxing)
        yellow_paper, aging_idx, foxing = self._detect_paper_aging_and_foxing(cv_bgr)
        has_bleed, bleed_ratio = self._detect_bleed_through(cv_gray)
        illum_uniformity = self._calc_illumination_uniformity(cv_gray)

        # 4. Texto & Morfologia Tipográfica
        stroke_width = self._estimate_stroke_width(cv_gray)
        cc_count = self._count_connected_components(cv_gray)
        ink_loss = self._detect_ink_fading(cv_gray)
        fft_energy, noise_level = self._analyze_fft_noise(cv_gray)
        wavelet_energy = self._calc_wavelet_energy(cv_gray)

        # 5. Estrutura de Layout (Colunas, Margens, Cabeçalho/Rodapé)
        col_count, margins, has_header, has_footer, has_tables = self._analyze_structure(cv_gray)

        # 6. Poda inteligente das 40 branches do Capítulo 4
        recommended_branches = self._prune_branches(
            has_bleed=has_bleed,
            yellow_paper=yellow_paper,
            contrast_rms=contrast_rms,
            noise_level=noise_level,
            ink_loss=ink_loss,
            needs_dewarp=needs_dewarp,
            lap_var=lap_var,
        )

        return PageProfile(
            page=page_num,
            dimensions=(w, h),
            laplacian_variance=round(lap_var, 2),
            focus_score=focus_score,
            contrast_rms=contrast_rms,
            blur_score=blur_score,
            has_motion_blur=has_motion_blur,
            has_gaussian_blur=has_gaussian_blur,
            column_count_estimate=col_count,
            margins=margins,
            has_header=has_header,
            has_footer=has_footer,
            has_illustrations_or_tables=has_tables,
            yellow_paper=yellow_paper,
            paper_aging_index=round(aging_idx, 2),
            foxing_detected=foxing,
            bleed_through_ratio=round(bleed_ratio, 4),
            bleed=has_bleed,
            stroke_width_median=round(stroke_width, 2),
            connected_components_count=cc_count,
            ink_loss=ink_loss,
            noise_level=noise_level,
            fft_high_freq_energy=round(fft_energy, 4),
            wavelet_energy=round(wavelet_energy, 2),
            illumination_uniformity=round(illum_uniformity, 3),
            skew_angle=round(skew_angle, 2),
            needs_dewarp=needs_dewarp,
            orientation_degrees=orientation,
            needs_rotation_180=is_180,
            recommended_branches=recommended_branches,
        )

    def _detect_skew(self, gray: np.ndarray) -> float:
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
        return float(np.median(angles)) if angles else 0.0

    def _detect_orientation(self, gray: np.ndarray) -> tuple[int, bool]:
        """
        Detecta orientação cardinal (0°, 90°, 180°, 270°) por projeções horizontais/verticais
        e assimetria de traços ascendentes/descendentes.
        """
        _, bin_inv = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
        
        # Testar aspecto vertical vs horizontal
        h, w = gray.shape
        proj_h = np.sum(bin_inv, axis=1)
        proj_v = np.sum(bin_inv, axis=0)
        
        var_h = float(np.var(proj_h))
        var_v = float(np.var(proj_v))

        # Texto horizontal padrão tem variação de linhas muito maior no eixo horizontal
        if var_v > var_h * 1.8:
            return 90, False

        # Avaliar assimetria vertical dos componentes (ascendentes dominam topo de linhas de texto)
        top_half = bin_inv[:h//2, :]
        bottom_half = bin_inv[h//2:, :]
        ratio_top_bot = float(np.sum(top_half)) / max(float(np.sum(bottom_half)), 1.0)

        # Se houver cabeçalhos ou padrões de topo que estejam no rodapé invertido
        is_180 = False
        if ratio_top_bot < 0.40 and np.sum(bottom_half) > 1000:
            is_180 = True

        orientation = 180 if is_180 else 0
        return orientation, is_180

    def _detect_curvature(self, gray: np.ndarray) -> bool:
        """Detecta arqueamento de linhas característico de páginas encadernadas."""
        small = cv2.resize(gray, (400, 400), interpolation=cv2.INTER_AREA)
        edges = cv2.Canny(small, 50, 150)
        lines = cv2.HoughLinesP(edges, 1, np.pi/180, 50, minLineLength=40, maxLineGap=15)
        if lines is None:
            return False
        y_diffs = []
        for line in lines:
            pts = np.asarray(line).reshape(-1)
            if len(pts) >= 4:
                x1, y1, x2, y2 = pts[:4]
                y_diffs.append(abs(float(y2 - y1)))
        return bool(np.mean(y_diffs) > 15.0) if y_diffs else False

    def _detect_paper_aging_and_foxing(self, bgr: np.ndarray) -> tuple[bool, float, bool]:
        lab = cv2.cvtColor(bgr, cv2.COLOR_BGR2LAB)
        b_channel = lab[:, :, 2].astype(np.float32)
        mean_b = float(np.mean(b_channel))
        aging_index = max(0.0, mean_b - 128.0)
        is_yellow = aging_index > 8.0

        # Foxing: manchas locais avermelhadas/marrons isoladas (alta variação no canal a* e b*)
        a_channel = lab[:, :, 1].astype(np.float32)
        foxing = bool(np.std(b_channel) > 14.0 and np.mean(a_channel) > 132.0)
        return is_yellow, aging_index, foxing

    def _detect_bleed_through(self, gray: np.ndarray) -> tuple[bool, float]:
        _, otsu = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
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
        small = cv2.resize(gray, (32, 32), interpolation=cv2.INTER_AREA)
        std_val = float(np.std(small))
        mean_val = float(np.mean(small))
        coeff_var = std_val / max(mean_val, 1.0)
        return max(0.0, 1.0 - coeff_var)

    def _estimate_stroke_width(self, gray: np.ndarray) -> float:
        _, bin_inv = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
        dist = cv2.distanceTransform(bin_inv, cv2.DIST_L2, 5)
        foreground_dist = dist[bin_inv > 0]
        if len(foreground_dist) == 0:
            return 1.0
        return float(np.median(foreground_dist)) * 2.0

    def _count_connected_components(self, gray: np.ndarray) -> int:
        _, bin_inv = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
        num_labels, labels, stats, _ = cv2.connectedComponentsWithStats(bin_inv, connectivity=8)
        valid = 0
        for i in range(1, num_labels):
            area = stats[i, cv2.CC_STAT_AREA]
            if 8 < area < 5000:
                valid += 1
        return valid

    def _detect_ink_fading(self, gray: np.ndarray) -> str:
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
        return "high"

    def _analyze_fft_noise(self, gray: np.ndarray) -> tuple[float, str]:
        f = np.fft.fft2(gray.astype(np.float32))
        fshift = np.fft.fftshift(f)
        magnitude_spectrum = 20 * np.log(np.abs(fshift) + 1e-5)
        h, w = gray.shape
        cy, cx = h // 2, w // 2
        y, x = np.ogrid[:h, :w]
        r = np.sqrt((x - cx)**2 + (y - cy)**2)
        high_freq_mask = r > (0.6 * np.sqrt(cx**2 + cy**2))

        high_energy = float(np.sum(magnitude_spectrum[high_freq_mask]))
        total_energy = float(np.sum(magnitude_spectrum))
        ratio = high_energy / max(total_energy, 1.0)
        noise_str = "high" if ratio > 0.45 else ("medium" if ratio > 0.25 else "low")
        return ratio, noise_str

    def _calc_wavelet_energy(self, gray: np.ndarray) -> float:
        pyr_down = cv2.pyrDown(gray)
        pyr_up = cv2.pyrUp(pyr_down, dstsize=(gray.shape[1], gray.shape[0]))
        lap = cv2.subtract(gray, pyr_up)
        return float(np.mean(np.square(lap.astype(np.float32))))

    def _analyze_structure(self, gray: np.ndarray) -> tuple[int, dict[str, int], bool, bool, bool]:
        h, w = gray.shape
        _, bin_inv = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)

        # Margens
        proj_h = np.sum(bin_inv, axis=1)
        proj_v = np.sum(bin_inv, axis=0)

        non_zero_y = np.where(proj_h > 0.005 * np.max(proj_h))[0]
        non_zero_x = np.where(proj_v > 0.005 * np.max(proj_v))[0]

        top_margin = int(non_zero_y[0]) if len(non_zero_y) > 0 else 0
        bottom_margin = int(h - non_zero_y[-1]) if len(non_zero_y) > 0 else 0
        left_margin = int(non_zero_x[0]) if len(non_zero_x) > 0 else 0
        right_margin = int(w - non_zero_x[-1]) if len(non_zero_x) > 0 else 0

        # Cabeçalho / Rodapé
        has_header = top_margin < int(0.12 * h) and np.sum(bin_inv[:int(0.08 * h), :]) > 100
        has_footer = bottom_margin < int(0.12 * h) and np.sum(bin_inv[int(0.92 * h):, :]) > 100

        # Colunas (analisar vale central)
        center_band = proj_v[int(0.35 * w): int(0.65 * w)]
        col_count = 1
        if len(center_band) > 0:
            min_val = np.min(center_band)
            mean_val = np.mean(proj_v)
            if min_val < 0.15 * mean_val and np.max(center_band) > mean_val:
                col_count = 2

        # Ilustrações ou tabelas (componentes muito grandes)
        num_labels, _, stats, _ = cv2.connectedComponentsWithStats(bin_inv)
        has_tables = False
        for i in range(1, num_labels):
            if stats[i, cv2.CC_STAT_AREA] > 0.08 * gray.size:
                has_tables = True
                break

        margins = {
            "top": top_margin,
            "bottom": bottom_margin,
            "left": left_margin,
            "right": right_margin,
        }
        return col_count, margins, bool(has_header), bool(has_footer), bool(has_tables)

    def _prune_branches(
        self,
        has_bleed: bool,
        yellow_paper: bool,
        contrast_rms: float,
        noise_level: str,
        ink_loss: str,
        needs_dewarp: bool,
        lap_var: float,
    ) -> list[str]:
        """
        Poda inteligente das 40 branches para reter apenas as elegíveis
        segundo o perfil da página (Capítulo 3).
        """
        branches = ["clahe", "sauvola", "otsu"]

        if has_bleed:
            branches.extend(["sauvola_multiscale", "wolf", "niblack"])
        if yellow_paper or ink_loss == "high":
            branches.extend(["retinex_msrcr", "contrast_stretch", "gamma_0.7"])
        if contrast_rms < 40.0:
            branches.extend(["clahe_clip3", "histogram_equalization", "retinex_ssr"])
        if noise_level in ("medium", "high"):
            branches.extend(["bilateral_filter", "median_3x3", "wavelet_denoise"])
        if lap_var < 80.0:
            branches.extend(["unsharp_mask", "morph_gradient", "tophat"])
        if needs_dewarp:
            branches.extend(["dewarp_mesh", "hough_deskew"])

        # Evitar branches excessivas se a página for limpa
        return list(dict.fromkeys(branches))
