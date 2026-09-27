"""
Engine de Pré-processamento Multi-Branch (30+ Branches Independentes) — TupiLingo OCR Forense v3.0
Gera e gerencia múltiplas variantes processadas por página com persistência determinística em cache.
"""
from collections.abc import Callable
from pathlib import Path

import cv2
import numpy as np
from PIL import Image
from skimage.filters import threshold_multiotsu


class MultiBranchPreprocessingEngine:
    """Implementa o catálogo completo de 30 branches independentes de visão computacional."""

    def __init__(self, cache_dir: Optional[Path] = None):
        self.cache_dir = cache_dir
        if self.cache_dir:
            self.cache_dir.mkdir(parents=True, exist_ok=True)

        self.branches: dict[str, Callable[[np.ndarray], np.ndarray]] = {
            "clahe": self.branch_clahe,
            "adaptive_gaussian": self.branch_adaptive_gaussian,
            "adaptive_mean": self.branch_adaptive_mean,
            "sauvola": self.branch_sauvola,
            "niblack": self.branch_niblack,
            "wolf": self.branch_wolf,
            "bernsen": self.branch_bernsen,
            "otsu": self.branch_otsu,
            "multi_otsu": self.branch_multi_otsu,
            "gamma": self.branch_gamma,
            "tophat": self.branch_tophat,
            "blackhat": self.branch_blackhat,
            "morph_reconstruction": self.branch_morph_reconstruction,
            "opening": self.branch_opening,
            "closing": self.branch_closing,
            "median": self.branch_median,
            "gaussian": self.branch_gaussian,
            "bilateral": self.branch_bilateral,
            "non_local_means": self.branch_non_local_means,
            "wavelet_denoise": self.branch_wavelet_denoise,
            "fft_denoise": self.branch_fft_denoise,
            "retinex": self.branch_retinex,
            "contrast_stretch": self.branch_contrast_stretch,
            "illumination_normalize": self.branch_illumination_normalize,
            "background_remove": self.branch_background_remove,
            "stroke_enhance": self.branch_stroke_enhance,
            "skeleton_enhance": self.branch_skeleton_enhance,
            "deskew_hough": self.branch_deskew_hough,
            "deskew_pca": self.branch_deskew_pca,
            "deskew_projection": self.branch_deskew_projection,
        }

    # ── BRANCHES INDIVIDUAIS ──────────────────────────────────────────────────

    def branch_clahe(self, gray: np.ndarray) -> np.ndarray:
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        return clahe.apply(gray)

    def branch_adaptive_gaussian(self, gray: np.ndarray) -> np.ndarray:
        return cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 25, 10)

    def branch_adaptive_mean(self, gray: np.ndarray) -> np.ndarray:
        return cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_MEAN_C, cv2.THRESH_BINARY, 25, 10)

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

    def branch_otsu(self, gray: np.ndarray) -> np.ndarray:
        _, res = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        return res

    def branch_multi_otsu(self, gray: np.ndarray) -> np.ndarray:
        try:
            thresholds = threshold_multiotsu(gray, classes=3)
            # Região com menor nível é texto
            regions = np.digitize(gray, bins=thresholds)
            res = np.where(regions == 0, 0, 255).astype(np.uint8)
            return res
        except Exception:
            return self.branch_otsu(gray)

    def branch_gamma(self, gray: np.ndarray, gamma: float = 0.65) -> np.ndarray:
        inv_gamma = 1.0 / gamma
        table = np.array([((i / 255.0) ** inv_gamma) * 255 for i in range(256)]).astype("uint8")
        return cv2.LUT(gray, table)

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

    def branch_median(self, gray: np.ndarray) -> np.ndarray:
        return cv2.medianBlur(gray, 3)

    def branch_gaussian(self, gray: np.ndarray) -> np.ndarray:
        return cv2.GaussianBlur(gray, (5, 5), 0)

    def branch_bilateral(self, gray: np.ndarray) -> np.ndarray:
        return cv2.bilateralFilter(gray, 9, 75, 75)

    def branch_non_local_means(self, gray: np.ndarray) -> np.ndarray:
        return cv2.fastNlMeansDenoising(gray, None, 10, 7, 21)

    def branch_wavelet_denoise(self, gray: np.ndarray) -> np.ndarray:
        # Denoising via multiscale difference of gaussians
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
        # Máscara passa-baixa gaussiana
        y, x = np.ogrid[:h, :w]
        mask = np.exp(-((x - cx)**2 + (y - cy)**2) / (2 * (min(h, w) * 0.4)**2))
        fshift_filtered = fshift * mask
        f_ishift = np.fft.ifftshift(fshift_filtered)
        img_back = np.fft.ifft2(f_ishift)
        res = np.abs(img_back)
        return np.clip(res, 0, 255).astype(np.uint8)

    def branch_retinex(self, gray: np.ndarray, sigma: float = 80.0) -> np.ndarray:
        img_float = gray.astype(np.float32) + 1.0
        blur = cv2.GaussianBlur(img_float, (0, 0), sigma) + 1.0
        retinex = np.log10(img_float) - np.log10(blur)
        norm = cv2.normalize(retinex, None, 0, 255, cv2.NORM_MINMAX)
        return norm.astype(np.uint8)

    def branch_contrast_stretch(self, gray: np.ndarray) -> np.ndarray:
        p2, p98 = np.percentile(gray, (2, 98))
        stretched = np.clip((gray - p2) * (255.0 / max(p98 - p2, 1.0)), 0, 255)
        return stretched.astype(np.uint8)

    def branch_illumination_normalize(self, gray: np.ndarray) -> np.ndarray:
        bg = cv2.dilate(gray, cv2.getStructuringElement(cv2.MORPH_RECT, (35, 35)))
        bg = cv2.medianBlur(bg, 21)
        res = cv2.divide(gray, bg, scale=255)
        return res

    def branch_background_remove(self, gray: np.ndarray) -> np.ndarray:
        bg = cv2.morphologyEx(gray, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_RECT, (25, 25)))
        diff = cv2.subtract(bg, gray)
        _, res = cv2.threshold(diff, 20, 255, cv2.THRESH_BINARY_INV)
        return res

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
        mean, eigenvectors = cv2.PCACompute(coords.astype(np.float32), mean=np.empty(0))
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

    # ── PROCESSAMENTO EM LOTE DE BRANCHES ─────────────────────────────────────

    def process_all_branches(self, pil_img: Image.Image) -> dict[str, Image.Image]:
        """Gera todas as 30 variantes pré-processadas da página."""
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
