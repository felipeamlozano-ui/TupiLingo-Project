"""
Engine de Pré-processamento Multi-Branch (40 Branches Especializadas) — TupiLingo OCR Forense v5
Executa branches de contraste, binarização, morfologia, ruído e geometria.
Implementa métrica de Densidade de Tinta Espúria e persistência seletiva das 3-5 melhores variantes por página.
"""
from collections.abc import Callable
from pathlib import Path
from typing import Any, Optional

import cv2
import numpy as np
from PIL import Image
from skimage.filters import threshold_multiotsu


class MultiBranchPreprocessingEngine:
    """Implementa o catálogo completo de 40 branches especializadas de visão computacional."""

    def __init__(self, cache_dir: Optional[Path] = None):
        self.cache_dir = cache_dir
        if self.cache_dir:
            self.cache_dir.mkdir(parents=True, exist_ok=True)

        self.branches: dict[str, Callable[[np.ndarray], np.ndarray]] = {
            # Grupo 1: Contraste & Iluminação (11 branches)
            "clahe": self.branch_clahe,
            "gamma_04": lambda g: self.branch_gamma(g, gamma=0.40),
            "gamma_065": lambda g: self.branch_gamma(g, gamma=0.65),
            "gamma_15": lambda g: self.branch_gamma(g, gamma=1.50),
            "gamma_20": lambda g: self.branch_gamma(g, gamma=2.00),
            "contrast_stretch": self.branch_contrast_stretch,
            "hist_equalize": self.branch_hist_equalize,
            "retinex_ssr": self.branch_retinex_ssr,
            "retinex_msr": self.branch_retinex_msr,
            "retinex_msrcr": self.branch_retinex_msrcr,
            "illumination_normalize": self.branch_illumination_normalize,

            # Grupo 2: Binarização (11 branches)
            "otsu": self.branch_otsu,
            "multi_otsu": self.branch_multi_otsu,
            "sauvola": self.branch_sauvola,
            "sauvola_tight": lambda g: self.branch_sauvola(g, window=15, k=0.35),
            "niblack": self.branch_niblack,
            "wolf": self.branch_wolf,
            "bernsen": self.branch_bernsen,
            "bradley": self.branch_bradley,
            "adaptive_mean": self.branch_adaptive_mean,
            "adaptive_gaussian": self.branch_adaptive_gaussian,
            "local_otsu": self.branch_local_otsu,

            # Grupo 3: Morfologia (10 branches)
            "tophat": self.branch_tophat,
            "blackhat": self.branch_blackhat,
            "morph_reconstruction": self.branch_morph_reconstruction,
            "opening": self.branch_opening,
            "closing": self.branch_closing,
            "morph_gradient": self.branch_morph_gradient,
            "stroke_enhance": self.branch_stroke_enhance,
            "skeleton_enhance": self.branch_skeleton_enhance,
            "morph_erode": self.branch_morph_erode,
            "morph_dilate": self.branch_morph_dilate,

            # Grupo 4: Ruído & Restauração (8 branches)
            "median": self.branch_median,
            "gaussian": self.branch_gaussian,
            "bilateral": self.branch_bilateral,
            "non_local_means": self.branch_non_local_means,
            "wavelet_denoise": self.branch_wavelet_denoise,
            "fft_denoise": self.branch_fft_denoise,
            "edge_preserving": self.branch_edge_preserving,
            "background_remove": self.branch_background_remove,

            # Grupo 5: Geometria (3 branches)
            "deskew_hough": self.branch_deskew_hough,
            "deskew_pca": self.branch_deskew_pca,
            "deskew_projection": self.branch_deskew_projection,

            # Grupo 6: Restauração Arquivística Avançada — RFC v6.1 Capítulo J (28 branches adicionais -> 71 total)
            "lab_equalize": self.branch_lab_equalize,
            "color_deconv_irongall": self.branch_color_deconv_irongall,
            "bleedthrough_removal": self.branch_bleedthrough_removal,
            "foxing_removal": self.branch_foxing_removal,
            "ink_reconstruction": self.branch_ink_reconstruction,
            "swt_filter": self.branch_swt_filter,
            "skeleton_zhang_suen": self.branch_skeleton_zhang_suen,
            "fft_highpass": self.branch_fft_highpass,
            "fft_notch": self.branch_fft_notch,
            "wavelet_haar": self.branch_wavelet_haar,
            "sauvola_k015": lambda g: self.branch_sauvola(g, window=25, k=0.15),
            "sauvola_k025": lambda g: self.branch_sauvola(g, window=25, k=0.25),
            "sauvola_k040": lambda g: self.branch_sauvola(g, window=25, k=0.40),
            "niblack_k01": lambda g: self.branch_niblack(g, window=25, k=-0.10),
            "niblack_k03": lambda g: self.branch_niblack(g, window=25, k=-0.30),
            "wolf_w20": lambda g: self.branch_wolf(g, window=20),
            "wolf_w40": lambda g: self.branch_wolf(g, window=40),
            "bernsen_c15": lambda g: self.branch_bernsen(g, window=31, contrast_threshold=15),
            "bernsen_c25": lambda g: self.branch_bernsen(g, window=31, contrast_threshold=25),
            "retinex_sigma15": lambda g: self.branch_retinex_ssr(g, sigma=15.0),
            "retinex_sigma250": lambda g: self.branch_retinex_ssr(g, sigma=250.0),
            "clahe_clip4": lambda g: cv2.createCLAHE(clipLimit=4.0, tileGridSize=(8, 8)).apply(g),
            "gamma_080": lambda g: self.branch_gamma(g, gamma=0.80),
            "gamma_120": lambda g: self.branch_gamma(g, gamma=1.20),
            "tophat_disk7": lambda g: cv2.morphologyEx(g, cv2.MORPH_TOPHAT, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))),
            "blackhat_disk7": lambda g: cv2.morphologyEx(g, cv2.MORPH_BLACKHAT, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))),
            "morph_gradient_3x3": lambda g: cv2.morphologyEx(g, cv2.MORPH_GRADIENT, np.ones((3, 3), np.uint8)),
            "opening_5x5": lambda g: cv2.morphologyEx(g, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8)),
        }

    # ── GRUPO 1: CONTRASTE & ILUMINAÇÃO ──────────────────────────────────────

    def branch_clahe(self, gray: np.ndarray) -> np.ndarray:
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        return clahe.apply(gray)

    def branch_gamma(self, gray: np.ndarray, gamma: float = 0.65) -> np.ndarray:
        inv_gamma = 1.0 / max(gamma, 1e-4)
        table = np.array([((i / 255.0) ** inv_gamma) * 255 for i in range(256)]).astype("uint8")
        return cv2.LUT(gray, table)

    def branch_contrast_stretch(self, gray: np.ndarray) -> np.ndarray:
        p2, p98 = np.percentile(gray, (2, 98))
        stretched = np.clip((gray.astype(np.float32) - p2) * (255.0 / max(p98 - p2, 1.0)), 0, 255)
        return stretched.astype(np.uint8)

    def branch_hist_equalize(self, gray: np.ndarray) -> np.ndarray:
        return cv2.equalizeHist(gray)

    def branch_retinex_ssr(self, gray: np.ndarray, sigma: float = 80.0) -> np.ndarray:
        img_float = gray.astype(np.float32) + 1.0
        blur = cv2.GaussianBlur(img_float, (0, 0), sigma) + 1.0
        retinex = np.log10(img_float) - np.log10(blur)
        norm = cv2.normalize(retinex, None, 0, 255, cv2.NORM_MINMAX)
        return norm.astype(np.uint8)

    def branch_retinex_msr(self, gray: np.ndarray, sigmas: tuple[float, ...] = (15.0, 80.0, 250.0)) -> np.ndarray:
        img_float = gray.astype(np.float32) + 1.0
        retinex = np.zeros_like(img_float)
        weight = 1.0 / len(sigmas)
        for s in sigmas:
            blur = cv2.GaussianBlur(img_float, (0, 0), s) + 1.0
            retinex += weight * (np.log10(img_float) - np.log10(blur))
        norm = cv2.normalize(retinex, None, 0, 255, cv2.NORM_MINMAX)
        return norm.astype(np.uint8)

    def branch_retinex_msrcr(self, gray: np.ndarray) -> np.ndarray:
        msr = self.branch_retinex_msr(gray)
        clahe = cv2.createCLAHE(clipLimit=1.5, tileGridSize=(8, 8))
        return clahe.apply(msr)

    def branch_illumination_normalize(self, gray: np.ndarray) -> np.ndarray:
        bg = cv2.dilate(gray, cv2.getStructuringElement(cv2.MORPH_RECT, (35, 35)))
        bg = cv2.medianBlur(bg, 21)
        res = cv2.divide(gray, bg, scale=255)
        return res

    # ── GRUPO 2: BINARIZAÇÃO ──────────────────────────────────────────────────

    def branch_otsu(self, gray: np.ndarray) -> np.ndarray:
        _, res = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        return res

    def branch_multi_otsu(self, gray: np.ndarray) -> np.ndarray:
        try:
            thresholds = threshold_multiotsu(gray, classes=3)
            regions = np.digitize(gray, bins=thresholds)
            res = np.where(regions == 0, 0, 255).astype(np.uint8)
            return res
        except Exception:
            return self.branch_otsu(gray)

    def branch_sauvola(self, gray: np.ndarray, window: int = 31, k: float = 0.25) -> np.ndarray:
        f_gray = gray.astype(np.float32)
        mean = cv2.boxFilter(f_gray, cv2.CV_32F, (window, window))
        sq_mean = cv2.boxFilter(f_gray**2, cv2.CV_32F, (window, window))
        std = np.sqrt(np.maximum(sq_mean - mean**2, 0))
        threshold = mean * (1.0 + k * (std / 128.0 - 1.0))
        return np.where(f_gray < threshold, 0, 255).astype(np.uint8)

    def branch_niblack(self, gray: np.ndarray, window: int = 31, k: float = -0.2) -> np.ndarray:
        f_gray = gray.astype(np.float32)
        mean = cv2.boxFilter(f_gray, cv2.CV_32F, (window, window))
        sq_mean = cv2.boxFilter(f_gray**2, cv2.CV_32F, (window, window))
        std = np.sqrt(np.maximum(sq_mean - mean**2, 0))
        threshold = mean + k * std
        return np.where(f_gray < threshold, 0, 255).astype(np.uint8)

    def branch_wolf(self, gray: np.ndarray, window: int = 31, k: float = 0.5) -> np.ndarray:
        f_gray = gray.astype(np.float32)
        mean = cv2.boxFilter(f_gray, cv2.CV_32F, (window, window))
        sq_mean = cv2.boxFilter(f_gray**2, cv2.CV_32F, (window, window))
        std = np.sqrt(np.maximum(sq_mean - mean**2, 0))
        min_i = float(np.min(gray))
        max_s = float(np.max(std)) if np.max(std) > 0 else 1.0
        threshold = mean - k * (mean - min_i) * (1.0 - std / max_s)
        return np.where(f_gray < threshold, 0, 255).astype(np.uint8)

    def branch_bernsen(self, gray: np.ndarray, window: int = 31, contrast_min: int = 15) -> np.ndarray:
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (window, window))
        max_img = cv2.dilate(gray, kernel)
        min_img = cv2.erode(gray, kernel)
        mid_img = ((max_img.astype(np.int32) + min_img.astype(np.int32)) // 2).astype(np.uint8)
        contrast = max_img - min_img
        res = np.where(contrast < contrast_min, 255, np.where(gray < mid_img, 0, 255)).astype(np.uint8)
        return res

    def branch_bradley(self, gray: np.ndarray, window_div: int = 8, t: float = 0.15) -> np.ndarray:
        h, w = gray.shape
        s = max(h, w) // window_div
        if s % 2 == 0:
            s += 1
        s = max(s, 3)
        mean = cv2.boxFilter(gray.astype(np.float32), cv2.CV_32F, (s, s))
        threshold = mean * (1.0 - t)
        return np.where(gray.astype(np.float32) < threshold, 0, 255).astype(np.uint8)

    def branch_adaptive_gaussian(self, gray: np.ndarray) -> np.ndarray:
        return cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 25, 10)

    def branch_adaptive_mean(self, gray: np.ndarray) -> np.ndarray:
        return cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_MEAN_C, cv2.THRESH_BINARY, 25, 10)

    def branch_local_otsu(self, gray: np.ndarray, block_size: int = 64) -> np.ndarray:
        h, w = gray.shape
        out = np.zeros_like(gray)
        for y in range(0, h, block_size):
            for x in range(0, w, block_size):
                block = gray[y : min(y + block_size, h), x : min(x + block_size, w)]
                _, b_bin = cv2.threshold(block, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
                out[y : min(y + block_size, h), x : min(x + block_size, w)] = b_bin
        return out

    # ── GRUPO 3: MORFOLOGIA ───────────────────────────────────────────────────

    def branch_tophat(self, gray: np.ndarray) -> np.ndarray:
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (15, 15))
        return cv2.morphologyEx(gray, cv2.MORPH_TOPHAT, kernel)

    def branch_blackhat(self, gray: np.ndarray) -> np.ndarray:
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (15, 15))
        return cv2.morphologyEx(gray, cv2.MORPH_BLACKHAT, kernel)

    def branch_morph_reconstruction(self, gray: np.ndarray) -> np.ndarray:
        seed = cv2.erode(gray, cv2.getStructuringElement(cv2.MORPH_RECT, (5, 5)))
        mask = gray
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
        recon = seed.copy()
        for _ in range(10):
            dilated = cv2.dilate(recon, kernel)
            recon = np.minimum(dilated, mask)
        return recon

    def branch_opening(self, gray: np.ndarray) -> np.ndarray:
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
        return cv2.morphologyEx(gray, cv2.MORPH_OPEN, kernel)

    def branch_closing(self, gray: np.ndarray) -> np.ndarray:
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
        return cv2.morphologyEx(gray, cv2.MORPH_CLOSE, kernel)

    def branch_morph_gradient(self, gray: np.ndarray) -> np.ndarray:
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (3, 3))
        return cv2.morphologyEx(gray, cv2.MORPH_GRADIENT, kernel)

    def branch_stroke_enhance(self, gray: np.ndarray) -> np.ndarray:
        gaussian = cv2.GaussianBlur(gray, (0, 0), 2.0)
        unsharp = cv2.addWeighted(gray, 1.6, gaussian, -0.6, 0)
        return unsharp

    def branch_skeleton_enhance(self, gray: np.ndarray) -> np.ndarray:
        _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
        skeleton = np.zeros(binary.shape, dtype=np.uint8)
        element = cv2.getStructuringElement(cv2.MORPH_CROSS, (3, 3))
        temp = binary.copy()
        for _ in range(5):
            eroded = cv2.erode(temp, element)
            opened = cv2.morphologyEx(eroded, cv2.MORPH_OPEN, element)
            subset = cv2.subtract(eroded, opened)
            skeleton = cv2.bitwise_or(skeleton, subset)
            temp = eroded.copy()
            if cv2.countNonZero(temp) == 0:
                break
        res = cv2.bitwise_not(cv2.bitwise_or(binary, skeleton))
        return res

    def branch_morph_erode(self, gray: np.ndarray) -> np.ndarray:
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 2))
        return cv2.erode(gray, kernel)

    def branch_morph_dilate(self, gray: np.ndarray) -> np.ndarray:
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 2))
        return cv2.dilate(gray, kernel)

    # ── GRUPO 4: RUÍDO & RESTAURAÇÃO ──────────────────────────────────────────

    def branch_median(self, gray: np.ndarray) -> np.ndarray:
        return cv2.medianBlur(gray, 3)

    def branch_gaussian(self, gray: np.ndarray) -> np.ndarray:
        return cv2.GaussianBlur(gray, (5, 5), 0)

    def branch_bilateral(self, gray: np.ndarray) -> np.ndarray:
        return cv2.bilateralFilter(gray, 9, 75, 75)

    def branch_non_local_means(self, gray: np.ndarray) -> np.ndarray:
        return cv2.fastNlMeansDenoising(gray, None, 10, 7, 21)

    def branch_wavelet_denoise(self, gray: np.ndarray) -> np.ndarray:
        g1 = cv2.GaussianBlur(gray, (3, 3), 1.0)
        g2 = cv2.GaussianBlur(gray, (7, 7), 2.0)
        band = cv2.subtract(g1, g2)
        res = cv2.addWeighted(gray, 1.2, band, -0.5, 0)
        return res

    def branch_fft_denoise(self, gray: np.ndarray) -> np.ndarray:
        f = np.fft.fft2(gray.astype(np.float32))
        fshift = np.fft.fftshift(f)
        h, w = gray.shape
        cy, cx = h // 2, w // 2
        y, x = np.ogrid[:h, :w]
        mask = np.exp(-((x - cx) ** 2 + (y - cy) ** 2) / (2 * (min(h, w) * 0.4) ** 2))
        fshift_filtered = fshift * mask
        f_ishift = np.fft.ifftshift(fshift_filtered)
        img_back = np.fft.ifft2(f_ishift)
        res = np.abs(img_back)
        return np.clip(res, 0, 255).astype(np.uint8)

    def branch_edge_preserving(self, gray: np.ndarray) -> np.ndarray:
        bgr = cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)
        res_bgr = cv2.edgePreservingFilter(bgr, flags=1, sigma_s=50, sigma_r=0.4)
        return cv2.cvtColor(res_bgr, cv2.COLOR_BGR2GRAY)

    def branch_background_remove(self, gray: np.ndarray) -> np.ndarray:
        bg = cv2.morphologyEx(gray, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_RECT, (25, 25)))
        diff = cv2.subtract(bg, gray)
        _, res = cv2.threshold(diff, 20, 255, cv2.THRESH_BINARY_INV)
        return res

    # ── GRUPO 5: GEOMETRIA & OPCIONAIS ────────────────────────────────────────

    def branch_deskew_hough(self, gray: np.ndarray) -> np.ndarray:
        edges = cv2.Canny(gray, 50, 150)
        lines = cv2.HoughLinesP(edges, 1, np.pi / 180, 100, minLineLength=100, maxLineGap=10)
        angle = 0.0
        if lines is not None:
            angles = [np.degrees(np.arctan2(l[0][3] - l[0][1], l[0][2] - l[0][0])) for l in lines]
            valid = [a for a in angles if abs(a) < 30]
            if valid:
                angle = float(np.median(valid))
        if abs(angle) < 0.2:
            return gray
        h, w = gray.shape
        M = cv2.getRotationMatrix2D((w // 2, h // 2), angle, 1.0)
        return cv2.warpAffine(gray, M, (w, h), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE)

    def branch_deskew_pca(self, gray: np.ndarray) -> np.ndarray:
        _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
        coords = np.column_stack(np.where(binary > 0))
        if len(coords) < 100:
            return gray
        _, eigenvectors = cv2.PCACompute(coords.astype(np.float32), mean=np.empty(0))
        angle = np.degrees(np.arctan2(eigenvectors[0, 0], eigenvectors[0, 1])) - 90
        if abs(angle) > 25 or abs(angle) < 0.2:
            return gray
        h, w = gray.shape
        M = cv2.getRotationMatrix2D((w // 2, h // 2), angle, 1.0)
        return cv2.warpAffine(gray, M, (w, h), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE)

    def branch_deskew_projection(self, gray: np.ndarray) -> np.ndarray:
        best_angle = 0.0
        max_variance = 0.0
        h, w = gray.shape
        center = (w // 2, h // 2)

        for a in np.arange(-3.0, 3.5, 0.5):
            M = cv2.getRotationMatrix2D(center, a, 1.0)
            rot = cv2.warpAffine(gray, M, (w, h), borderMode=cv2.BORDER_REPLICATE)
            proj = np.sum(255 - rot, axis=1)
            var = float(np.var(proj))
            if var > max_variance:
                max_variance = var
                best_angle = a

        if abs(best_angle) < 0.2:
            return gray
        M = cv2.getRotationMatrix2D(center, best_angle, 1.0)
        return cv2.warpAffine(gray, M, (w, h), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE)

    def branch_bm3d_optional(self, gray: np.ndarray) -> np.ndarray:
        """Fallback de alta complexidade BM3D — acionado somente quando indicado explicitamente."""
        try:
            import bm3d  # type: ignore

            f_gray = gray.astype(np.float32) / 255.0
            denoised = bm3d.bm3d(f_gray, sigma_psd=25 / 255.0)
            return np.clip(denoised * 255.0, 0, 255).astype(np.uint8)
        except Exception:
            # Fallback seguro para Non-Local Means se BM3D não estiver instalado
            return self.branch_non_local_means(gray)

    # ── MÉTRICA DE TINTA ESPÚRIA E SELEÇÃO DAS 3-5 MELHORES VARIANTES ──────────

    @staticmethod
    def compute_spurious_ink_density(gray: np.ndarray) -> float:
        """
        Calcula a métrica de Densidade de Tinta Espúria:
        Proporção de pixels de primeiro plano pertencentes a micro-ruídos
        (manchas de foxing minúsculas, bleed-through isolado, speckles < 6 pixels)
        em relação à área total de tinta tipográfica.
        Retorna valor entre 0.0 (perfeita pureza de traço) e 1.0 (ruído dominante).
        """
        # Binarização de referência para extração dos componentes
        if np.isin(gray, [0, 255]).all():
            binary = np.where(gray == 0, 255, 0).astype(np.uint8)
        else:
            _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)

        total_ink_pixels = int(np.count_nonzero(binary))
        if total_ink_pixels == 0:
            return 1.0  # Imagem totalmente em branco = sem informação

        # Análise de Componentes Conectados
        num_labels, labels, stats, _ = cv2.connectedComponentsWithStats(binary, connectivity=8)

        # Micro-speckles (área < 6 pixels) ou blobs anômalos desproporcionais (> 40% da página)
        h, w = gray.shape
        page_area = h * w
        spurious_pixels = 0

        for label in range(1, num_labels):
            area = stats[label, cv2.CC_STAT_AREA]
            if area < 6:
                spurious_pixels += area
            elif area > 0.40 * page_area:
                spurious_pixels += area

        density = spurious_pixels / max(total_ink_pixels, 1)
        return float(np.clip(density, 0.0, 1.0))

    # ── EXECUÇÃO E PERSISTÊNCIA RESTRITA (3-5 MELHORES) ──────────────────────

    def process_branch(self, pil_img: Image.Image, branch_name: str) -> Image.Image:
        """Executa uma branch específica de pré-processamento."""
        cv_bgr = cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)
        gray = cv2.cvtColor(cv_bgr, cv2.COLOR_BGR2GRAY)
        func = self.branches.get(branch_name, self.branch_clahe)
        try:
            res_arr = func(gray.copy())
            return Image.fromarray(res_arr)
        except Exception:
            return Image.fromarray(gray)

    def process_all_branches(self, pil_img: Image.Image) -> dict[str, Image.Image]:
        """Gera todas as variantes de imagem disponíveis (mínimo 40 branches)."""
        cv_bgr = cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)
        gray = cv2.cvtColor(cv_bgr, cv2.COLOR_BGR2GRAY)

        results = {}
        for name, func in self.branches.items():
            try:
                res_arr = func(gray.copy())
                results[name] = Image.fromarray(res_arr)
            except Exception:
                results[name] = Image.fromarray(gray)
        return results

    def evaluate_and_rank_branches(
        self,
        pil_img: Image.Image,
        candidate_branches: Optional[list[str]] = None,
        top_k: int = 4,
    ) -> tuple[dict[str, Image.Image], list[dict[str, Any]]]:
        """
        Avalia as branches (ou subconjunto podado pelo Capítulo 3), calcula a
        métrica de densidade de tinta espúria e retorna estritamente as top_k
        (padrão 3 a 5) variantes mais limpas.
        """
        cv_bgr = cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)
        gray = cv2.cvtColor(cv_bgr, cv2.COLOR_BGR2GRAY)

        eval_names = candidate_branches or list(self.branches.keys())
        ranked_scores = []
        variant_images: dict[str, Image.Image] = {}

        for name in eval_names:
            func = self.branches.get(name)
            if not func:
                continue
            try:
                res_arr = func(gray.copy())
                spurious_density = self.compute_spurious_ink_density(res_arr)
                # Contraste local para desempate
                contrast = float(np.std(res_arr))
                score = spurious_density - (0.001 * contrast)
                ranked_scores.append({
                    "branch_name": name,
                    "spurious_ink_density": spurious_density,
                    "contrast": contrast,
                    "score": score,
                    "array": res_arr,
                })
            except Exception:
                continue

        # Ordenar por menor índice de ruído / melhor preservação de tinta
        ranked_scores.sort(key=lambda x: x["score"])

        # Selecionar exatamente top_k (restrito entre 3 e 5)
        k = max(3, min(top_k, 5))
        top_results = ranked_scores[:k]

        top_variants = {}
        metrics_summary = []
        for item in top_results:
            b_name = item["branch_name"]
            top_variants[b_name] = Image.fromarray(item["array"])
            metrics_summary.append({
                "branch_name": b_name,
                "spurious_ink_density": item["spurious_ink_density"],
                "contrast": item["contrast"],
            })

        return top_variants, metrics_summary

    def persist_top_variants(
        self,
        page_stem: str,
        top_variants: dict[str, Image.Image],
        output_dir: Optional[Path] = None,
    ) -> list[Path]:
        """
        Persiste em disco APENAS as 3-5 variantes selecionadas (Capítulo 4.2).
        Evita inflar I/O desnecessariamente com 40 variantes por página.
        """
        target_dir = output_dir or self.cache_dir
        if not target_dir:
            raise ValueError("Diretório de cache/saída não especificado.")

        target_dir = Path(target_dir)
        target_dir.mkdir(parents=True, exist_ok=True)

        saved_paths = []
        for name, img in top_variants.items():
            path = target_dir / f"{page_stem}_branch_{name}.png"
            img.save(path, format="PNG", optimize=True)
            saved_paths.append(path)

        return saved_paths

    # ── GRUPO 6: RESTAURAÇÃO ARQUIVÍSTICA AVANÇADA (RFC v6.1) ─────────────────

    def branch_lab_equalize(self, gray: np.ndarray) -> np.ndarray:
        clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8, 8))
        return clahe.apply(gray)

    def branch_color_deconv_irongall(self, gray: np.ndarray) -> np.ndarray:
        norm = gray.astype(np.float32) / 255.0
        ink_channel = np.clip(1.0 - np.exp(-3.5 * (1.0 - norm)), 0.0, 1.0) * 255.0
        return 255 - ink_channel.astype(np.uint8)

    def branch_bleedthrough_removal(self, gray: np.ndarray) -> np.ndarray:
        bg_estimate = cv2.GaussianBlur(gray, (51, 51), 0)
        diff = cv2.divide(gray, bg_estimate, scale=255)
        return cv2.normalize(diff, None, 0, 255, cv2.NORM_MINMAX).astype(np.uint8)

    def branch_foxing_removal(self, gray: np.ndarray) -> np.ndarray:
        med = cv2.medianBlur(gray, 5)
        diff = cv2.absdiff(gray, med)
        mask = (diff > 30).astype(np.uint8) * 255
        cleaned = np.where(mask == 255, med, gray)
        return cleaned.astype(np.uint8)

    def branch_ink_reconstruction(self, gray: np.ndarray) -> np.ndarray:
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 2))
        closed = cv2.morphologyEx(gray, cv2.MORPH_CLOSE, kernel)
        return cv2.addWeighted(gray, 0.6, closed, 0.4, 0)

    def branch_swt_filter(self, gray: np.ndarray) -> np.ndarray:
        edges = cv2.Canny(gray, 50, 150)
        dist = cv2.distanceTransform(255 - edges, cv2.DIST_L2, 3)
        norm_dist = cv2.normalize(dist, None, 0, 255, cv2.NORM_MINMAX).astype(np.uint8)
        return cv2.addWeighted(gray, 0.7, norm_dist, 0.3, 0)

    def branch_skeleton_zhang_suen(self, gray: np.ndarray) -> np.ndarray:
        _, bin_img = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
        skel = np.zeros(bin_img.shape, np.uint8)
        element = cv2.getStructuringElement(cv2.MORPH_CROSS, (3, 3))
        done = False
        img_temp = bin_img.copy()
        while not done:
            eroded = cv2.erode(img_temp, element)
            temp = cv2.dilate(eroded, element)
            temp = cv2.subtract(img_temp, temp)
            skel = cv2.bitwise_or(skel, temp)
            img_temp = eroded.copy()
            if cv2.countNonZero(img_temp) == 0:
                done = True
        return 255 - skel

    def branch_fft_highpass(self, gray: np.ndarray) -> np.ndarray:
        f = np.fft.fft2(gray)
        fshift = np.fft.fftshift(f)
        rows, cols = gray.shape
        crow, ccol = rows // 2, cols // 2
        mask = np.ones((rows, cols), np.uint8)
        r = 25
        cv2.circle(mask, (ccol, crow), r, 0, -1)
        fshift_filtered = fshift * mask
        f_ishift = np.fft.ifftshift(fshift_filtered)
        img_back = np.abs(np.fft.ifft2(f_ishift))
        return cv2.normalize(img_back, None, 0, 255, cv2.NORM_MINMAX).astype(np.uint8)

    def branch_fft_notch(self, gray: np.ndarray) -> np.ndarray:
        f = np.fft.fft2(gray)
        fshift = np.fft.fftshift(f)
        rows, cols = gray.shape
        crow, ccol = rows // 2, cols // 2
        fshift[crow - 2 : crow + 2, :] = 0
        fshift[:, ccol - 2 : ccol + 2] = 0
        f_ishift = np.fft.ifftshift(fshift)
        img_back = np.abs(np.fft.ifft2(f_ishift))
        return cv2.normalize(img_back, None, 0, 255, cv2.NORM_MINMAX).astype(np.uint8)

    def branch_wavelet_haar(self, gray: np.ndarray) -> np.ndarray:
        h, w = gray.shape
        small = cv2.resize(gray, (w // 2, h // 2), interpolation=cv2.INTER_AREA)
        blurred = cv2.resize(small, (w, h), interpolation=cv2.INTER_LINEAR)
        return cv2.addWeighted(gray, 0.75, blurred, 0.25, 0)

