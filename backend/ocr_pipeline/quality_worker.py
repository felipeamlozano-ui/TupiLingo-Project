"""
Fase 0 — Document Profiler (Etapa -1) & Quality Score Engine (Etapa 0).
Implementa extração leve de IQA calibrada com os percentis reais do acervo,
análise de colunas e bleed-through, e roteamento adaptativo.
"""
from typing import Any

import cv2
import numpy as np
from PIL import Image

from .cache_manager import DeterministicCacheManager
from .models import PageProfile, PageType, RoutingDecision

# Percentis empíricos calibrados sobre 120 páginas do acervo TupiLingo
DEFAULT_CALIBRATION = {
    "lap_var": {"p10": 281.05, "p50": 2482.03, "p90": 6783.10},
    "contrast_rms": {"p10": 16.84, "p50": 40.42, "p90": 57.07},
    "entropy": {"p10": 0.18, "p50": 0.93, "p90": 2.22},
    "skew_deg": {"p10": 0.00, "p50": 0.05, "p90": 5.31},
}

# Limiares de roteamento configuráveis
DEFAULT_ROUTING_THRESHOLDS = {
    "rapido": 98.0,
    "padrao": 94.0,
    "reforcado": 90.0,
    "atencao": 85.0
}

class QualityWorker:
    def __init__(
        self,
        calibration: dict[str, Any] | None = None,
        thresholds: dict[str, float] | None = None
    ):
        self.calib = calibration or DEFAULT_CALIBRATION
        self.thresholds = thresholds or DEFAULT_ROUTING_THRESHOLDS

    def compute_iqa_metrics(self, gray: np.ndarray) -> dict[str, float]:
        """Calcula métricas fundamentais de IQA de forma leve via OpenCV."""
        h, w = gray.shape[:2]
        
        # 1. Blur via Variância do Laplaciano
        lap_var = float(cv2.Laplacian(gray, cv2.CV_64F).var())
        
        # 2. Contraste RMS
        contrast_rms = float(np.std(gray))
        
        # 3. Entropia de Shannon da distribuição de intensidade
        hist, _ = np.histogram(gray, bins=256, range=(0, 256), density=True)
        hist = hist[hist > 0]
        entropy = float(-np.sum(hist * np.log2(hist)))
        
        # 4. Estimativa de Skew (inclinação)
        _, thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
        coords = np.column_stack(np.where(thresh > 0))
        angle = 0.0
        if len(coords) > 50:
            rect = cv2.minAreaRect(coords)
            angle = rect[-1]
            if angle < -45:
                angle = -(90 + angle)
            else:
                angle = -angle
        skew_angle = float(angle)
        
        return {
            "blur_laplacian": lap_var,
            "contrast_rms": contrast_rms,
            "entropy": entropy,
            "skew_angle": skew_angle
        }

    def detect_column_layout(self, gray: np.ndarray) -> tuple[int, float]:
        """
        Detecta número de colunas (1 vs 2) analisando o perfil de projeção vertical
        na região central (35% a 65% da largura da página).
        Retorna: (num_colunas, valley_ratio)
        """
        h, w = gray.shape[:2]
        _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
        v_proj = np.sum(binary, axis=0)
        
        mid_start, mid_end = int(w * 0.35), int(w * 0.65)
        if mid_end <= mid_start:
            return 1, 1.0
            
        mid_slice = v_proj[mid_start:mid_end]
        valley_val = float(np.min(mid_slice))
        peak_val = float(np.max(v_proj))
        
        if peak_val == 0:
            return 1, 1.0
            
        valley_ratio = valley_val / peak_val
        # Se a densidade de tinta no centro for menos de 20% do pico, temos 2 colunas nítidas
        num_cols = 2 if valley_ratio < 0.20 else 1
        return num_cols, round(valley_ratio, 4)

    def detect_bleed_through(self, gray: np.ndarray) -> tuple[bool, float]:
        """
        Detecta indícios de bleed-through comparando a densidade de tinta
        entre Otsu (que captura manchas reversas) e Sauvola (que as filtra).
        """
        _, otsu = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
        # Sauvola simplificado
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
        has_bleed = diff_ratio > 0.25 and otsu_ink > 0.05 * gray.size
        return has_bleed, round(diff_ratio, 4)

    def calculate_calibrated_iqa(self, metrics: dict[str, float]) -> float:
        """
        Normaliza os valores brutos usando os percentis p10 e p90 calibrados do acervo.
        Gera uma pontuação normalizada de 0 a 100 sem distorções arbitrárias.
        """
        lap = metrics["blur_laplacian"]
        lap_p10 = self.calib["lap_var"]["p10"]
        lap_p90 = self.calib["lap_var"]["p90"]
        if lap >= lap_p90:
            score_blur = 100.0
        elif lap <= lap_p10:
            score_blur = max(0.0, (lap / max(lap_p10, 1.0)) * 60.0)
        else:
            score_blur = 60.0 + ((lap - lap_p10) / (lap_p90 - lap_p10)) * 40.0

        rms = metrics["contrast_rms"]
        rms_p10 = self.calib["contrast_rms"]["p10"]
        rms_p90 = self.calib["contrast_rms"]["p90"]
        if rms >= rms_p90:
            score_contrast = 100.0
        elif rms <= rms_p10:
            score_contrast = max(0.0, (rms / max(rms_p10, 1.0)) * 60.0)
        else:
            score_contrast = 60.0 + ((rms - rms_p10) / (rms_p90 - rms_p10)) * 40.0

        skew = abs(metrics["skew_angle"])
        if skew <= 0.4:
            score_skew = 100.0
        elif skew <= 2.0:
            score_skew = 95.0 - (skew - 0.4) * 5.0
        elif skew <= 5.0:
            score_skew = 85.0 - (skew - 2.0) * 5.0
        else:
            score_skew = max(50.0, 70.0 - (skew - 5.0) * 3.0)

        # Média ponderada dos fatores IQA
        composite_iqa = 0.45 * score_blur + 0.35 * score_contrast + 0.20 * score_skew
        return round(float(composite_iqa), 2)

    def route_page(self, quality_score: float) -> RoutingDecision:
        """Aplica a tabela de decisão da Seção 1 com limiares configuráveis."""
        if quality_score >= self.thresholds["rapido"]:
            return RoutingDecision.OCR_RAPIDO
        elif quality_score >= self.thresholds["padrao"]:
            return RoutingDecision.OCR_PADRAO
        elif quality_score >= self.thresholds["reforcado"]:
            return RoutingDecision.FASE1_REFORCADO
        elif quality_score >= self.thresholds["atencao"]:
            return RoutingDecision.FASE1_ATENCAO
        else:
            return RoutingDecision.FASE1_REVISAO

    def profile_page(
        self,
        pil_image: Image.Image,
        filename: str,
        page_num: int,
        file_hash: str = "",
        historical_ocr_conf: float | None = None,
        precisa_revisao_hist: bool = False,
        page_type: PageType = PageType.SCAN,
        dpi_effective: int = 300,
        use_cache: bool = True
    ) -> PageProfile:
        """
        Perfilamento completo de uma página com persistência em cache determinístico.
        Combina o score IQA calibrado com a confiança histórica de OCR (média harmônica).
        """
        # Obter bytes brutos da imagem para cálculo instantâneo do hash (sem compressão PNG)
        page_hash = DeterministicCacheManager.compute_page_hash(
            pil_image.tobytes(),
            extra_params={"w": pil_image.width, "h": pil_image.height, "mode": pil_image.mode}
        )

        if use_cache:
            cached = DeterministicCacheManager.get_cached_profile(page_hash)
            if cached:
                cached["routing_decision"] = RoutingDecision(cached["routing_decision"])
                cached["page_type"] = PageType(cached["page_type"])
                return PageProfile(**cached)

        # Processamento OpenCV
        cv_img = cv2.cvtColor(np.array(pil_image), cv2.COLOR_RGB2BGR)
        gray = cv2.cvtColor(cv_img, cv2.COLOR_BGR2GRAY)
        h, w = gray.shape[:2]

        iqa_metrics = self.compute_iqa_metrics(gray)
        num_cols, valley_ratio = self.detect_column_layout(gray)
        has_bleed, bleed_ratio = self.detect_bleed_through(gray)

        iqa_calibrated = self.calculate_calibrated_iqa(iqa_metrics)

        # Combinação harmônica com histórico de OCR
        if page_type == PageType.DIGITAL and not precisa_revisao_hist:
            final_quality = 100.0
        elif historical_ocr_conf is not None and historical_ocr_conf > 0:
            # Média harmônica para não penalizar páginas amareladas com OCR historicamente excelente
            # H = 2 * (A * B) / (A + B)
            final_quality = (2.0 * iqa_calibrated * historical_ocr_conf) / (iqa_calibrated + historical_ocr_conf)
            if precisa_revisao_hist and final_quality >= 94.0:
                final_quality = 93.0 # Força roteamento para Fase 1 se houve anomalia
        else:
            final_quality = iqa_calibrated

        final_quality = round(float(min(100.0, max(0.0, final_quality))), 2)
        decision = self.route_page(final_quality)

        profile = PageProfile(
            filename=filename,
            page_num=page_num,
            file_hash=file_hash,
            page_hash=page_hash,
            width=w,
            height=h,
            dpi_effective=dpi_effective,
            page_type=page_type,
            num_columns=num_cols,
            column_valley_ratio=valley_ratio,
            has_bleed_through=has_bleed,
            bleed_through_ratio=bleed_ratio,
            blur_laplacian=iqa_metrics["blur_laplacian"],
            contrast_rms=iqa_metrics["contrast_rms"],
            entropy=iqa_metrics["entropy"],
            skew_angle=iqa_metrics["skew_angle"],
            iqa_score_raw=round(iqa_metrics["blur_laplacian"], 2),
            iqa_score_calibrated=iqa_calibrated,
            historical_ocr_conf=historical_ocr_conf,
            precisa_revisao_historico=precisa_revisao_hist,
            quality_score=final_quality,
            routing_decision=decision,
            metadata={
                "calibrated_against": "acervo_p10_p90",
                "harmonic_mean_used": historical_ocr_conf is not None
            }
        )

        # Salva em cache
        if use_cache:
            profile_dict = profile.__dict__.copy()
            profile_dict["routing_decision"] = decision.value
            profile_dict["page_type"] = page_type.value
            DeterministicCacheManager.set_cached_profile(page_hash, profile_dict)

        return profile
