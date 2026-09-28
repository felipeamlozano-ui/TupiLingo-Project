"""
Region Quality Engine — Capítulo 28
Avalia a qualidade granular por região documental da página:
  - Regiões: Cabeçalho, Rodapé, Coluna Esquerda, Coluna Direita, Margens, Notas, Ilustrações
  - Calcula CER/WER estimado por região e nitidez (Laplacian variance)
  - Decide de forma autônoma se a região necessita de recuperação iterativa (Capítulo 13)
  - Gera heatmap visual com overlay semi-transparente color-coded por região.
"""
from __future__ import annotations

import logging
import uuid
from typing import Any, Optional
import cv2
import numpy as np
from PIL import Image, ImageDraw
from pydantic import BaseModel, Field

from ..core.provenance import BoundingBox

logger = logging.getLogger("region_quality")


class RegionQualityAssessment(BaseModel):
    region_id: str
    region_type: str  # header, footer, column_left, column_right, margins, notes, illustrations
    bbox: list[int]
    sharpness_score: float
    estimated_cer: float
    estimated_wer: float
    quality_score: float  # 0.0 a 1.0
    needs_iterative_recovery: bool
    recovery_reason: str = ""


class PageRegionQualityReport(BaseModel):
    overall_page_quality: float
    regions_count: int
    regions_requiring_recovery: list[str] = Field(default_factory=list)
    assessments: list[RegionQualityAssessment] = Field(default_factory=list)


class RegionQualityEngine:
    """Motor de Diagnóstico e Qualidade Regional da Página."""

    def __init__(
        self,
        min_quality_threshold: float = 0.70,
        max_acceptable_cer: float = 0.15,
    ):
        self.min_quality = min_quality_threshold
        self.max_cer = max_acceptable_cer

    @staticmethod
    def measure_crop_sharpness(gray_crop: np.ndarray) -> float:
        """Mede a nitidez do recorte via variância do operador Laplaciano."""
        if gray_crop.size == 0:
            return 0.0
        lap = cv2.Laplacian(gray_crop, cv2.CV_64F)
        var = float(lap.var())
        # Normalização sigmoide simples
        norm = var / (var + 150.0)
        return float(min(1.0, max(0.0, norm)))

    def assess_region(
        self,
        pil_page: Image.Image,
        region_type: str,
        bbox: list[int],
        ocr_confidence: float = 85.0,
    ) -> RegionQualityAssessment:
        """Avalia uma região individual."""
        reg_id = f"reg_{region_type}_{uuid.uuid4().hex[:6]}"
        w_img, h_img = pil_page.size

        x1 = max(0, min(w_img - 1, bbox[0]))
        y1 = max(0, min(h_img - 1, bbox[1]))
        x2 = max(x1 + 1, min(w_img, bbox[2]))
        y2 = max(y1 + 1, min(h_img, bbox[3]))

        crop = pil_page.crop((x1, y1, x2, y2))
        gray_crop = np.array(crop.convert("L"))

        sharpness = self.measure_crop_sharpness(gray_crop)

        # CER/WER estimado: inversamente proporcional à confiança de OCR e nitidez
        est_cer = max(0.0, min(1.0, (100.0 - ocr_confidence) / 100.0 * 1.5))
        est_wer = max(0.0, min(1.0, est_cer * 1.8))

        # Qualidade composta da região
        if region_type == "illustrations":
            quality = 0.95  # Não requer OCR
            needs_recovery = False
            reason = "ilustracao_sem_ocr"
        else:
            quality = round(0.50 * sharpness + 0.50 * (ocr_confidence / 100.0), 3)
            needs_recovery = (quality < self.min_quality) or (est_cer > self.max_cer)
            reason = "baixa_nitidez_ou_cer_elevado" if needs_recovery else "aprovada"

        return RegionQualityAssessment(
            region_id=reg_id,
            region_type=region_type,
            bbox=[x1, y1, x2, y2],
            sharpness_score=round(sharpness, 3),
            estimated_cer=round(est_cer, 3),
            estimated_wer=round(est_wer, 3),
            quality_score=quality,
            needs_iterative_recovery=needs_recovery,
            recovery_reason=reason,
        )

    def evaluate_page_regions(
        self,
        pil_page: Image.Image,
        region_definitions: list[dict[str, Any]],
    ) -> tuple[PageRegionQualityReport, Image.Image]:
        """
        Avalia todas as regiões da página e gera o heatmap visual correspondente.
        """
        assessments: list[RegionQualityAssessment] = []
        requiring_recovery: list[str] = []

        for r_def in region_definitions:
            r_type = r_def.get("region_type", "body")
            bbox = r_def.get("bbox", [0, 0, 100, 100])
            conf = r_def.get("ocr_confidence", 85.0)

            asm = self.assess_region(pil_page, r_type, bbox, ocr_confidence=conf)
            assessments.append(asm)
            if asm.needs_iterative_recovery:
                requiring_recovery.append(asm.region_id)

        mean_q = float(np.mean([a.quality_score for a in assessments])) if assessments else 1.0

        report = PageRegionQualityReport(
            overall_page_quality=round(mean_q, 3),
            regions_count=len(assessments),
            regions_requiring_recovery=requiring_recovery,
            assessments=assessments,
        )

        heatmap = self.render_region_heatmap(pil_page, assessments)
        return report, heatmap

    @staticmethod
    def render_region_heatmap(
        pil_page: Image.Image,
        assessments: list[RegionQualityAssessment],
    ) -> Image.Image:
        """Gera imagem com overlay colorido translúcido indicando a qualidade por região."""
        base = pil_page.convert("RGBA")
        overlay = Image.new("RGBA", base.size, (255, 255, 255, 0))
        draw = ImageDraw.Draw(overlay)

        for a in assessments:
            x1, y1, x2, y2 = a.bbox
            if a.region_type == "illustrations":
                color = (56, 189, 248, 80)  # Azul claro
            elif a.quality_score >= 0.80:
                color = (34, 197, 94, 90)   # Verde nítido
            elif a.quality_score >= 0.65:
                color = (234, 179, 8, 90)   # Amarelo
            else:
                color = (239, 68, 68, 110)  # Vermelho (requer recuperação)

            draw.rectangle([x1, y1, x2, y2], fill=color, outline=(255, 255, 255, 180), width=2)

        return Image.alpha_composite(base, overlay)
