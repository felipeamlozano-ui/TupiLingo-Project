"""
Engine de Fusão de Confiança e Geração de Heatmap — Capítulo 9 (Confidence Fusion v5)
Implementa a trava de piso estrutural (structural floor trap):
  - Se o texto final for idêntico (ou >= 95% similar) ao texto bruto de entrada,
    c_lex e c_rag são zerados para aquele chunk (não pontuam conformidade sem correção real).
  - Impõe needs_review = True de forma independente para qualquer página com c_ocr < 50%,
    impedindo que componentes adicionais mascarem texto ilegível.
  - Decompõe explicitamente os componentes para persistência no confidence_components.parquet.
"""
from typing import Any, Optional

import numpy as np
from PIL import Image, ImageDraw
from pydantic import BaseModel

from ..core.provenance import BoundingBox


class ConfidenceDecomposition(BaseModel):
    ocr_conf: float
    visual_conf: float
    lexical_conf: float
    rag_conf: float
    consensus_conf: float
    fused_confidence: float
    needs_review: bool
    floor_trap_triggered: bool
    review_reason: str


class ForensicConfidenceFusionEngine:
    def __init__(
        self,
        w_ocr: float = 0.45,
        w_vis: float = 0.15,
        w_lex: float = 0.20,
        w_rag: float = 0.10,
        w_consensus: float = 0.10,
        min_ocr_threshold: float = 50.0,
        identity_floor_threshold: float = 0.95,
    ):
        self.w_ocr = w_ocr
        self.w_vis = w_vis
        self.w_lex = w_lex
        self.w_rag = w_rag
        self.w_consensus = w_consensus
        self.min_ocr_threshold = min_ocr_threshold
        self.identity_floor_threshold = identity_floor_threshold

    @staticmethod
    def _compute_text_similarity(s1: str, s2: str) -> float:
        """Calcula similaridade de caracteres normalizada entre 0.0 e 1.0."""
        s1 = s1.strip().lower()
        s2 = s2.strip().lower()
        if not s1 and not s2:
            return 1.0
        if not s1 or not s2:
            return 0.0
        if s1 == s2:
            return 1.0

        # Jaccard sobre bi-gramas de caracteres
        def get_bigrams(text: str) -> set[str]:
            return {text[i : i + 2] for i in range(len(text) - 1)} or {text}

        bg1 = get_bigrams(s1)
        bg2 = get_bigrams(s2)
        inter = len(bg1.intersection(bg2))
        union = len(bg1.union(bg2))
        return inter / max(union, 1)

    def decompose_and_fuse(
        self,
        ocr_conf: float,
        visual_conf: float,
        lexical_conf: float,
        rag_conf: float,
        consensus_conf: float = 100.0,
        raw_text: str = "",
        final_text: str = "",
        min_char_count: int = 40,
    ) -> ConfidenceDecomposition:
        """
        Calcula a fusão v5 aplicando a trava de piso estrutural e o gate de revisão humana.
        """
        # 1. Avaliar similaridade entre texto de entrada e saída
        similarity = self._compute_text_similarity(raw_text, final_text) if (raw_text and final_text) else 1.0
        zero_modifications = similarity >= self.identity_floor_threshold

        floor_trap_triggered = False
        effective_lex = lexical_conf
        effective_rag = rag_conf

        # 2. Trava de Piso Estrutural: se o OCR for ruidoso (< 85%) e nenhuma correção foi aplicada,
        # impede que c_lex e c_rag inflem artificialmente a nota
        if zero_modifications and ocr_conf < 85.0:
            floor_trap_triggered = True
            effective_lex = 0.0
            effective_rag = 0.0

        # 3. Cálculo da pontuação composta ponderada
        total_weight = self.w_ocr + self.w_vis + self.w_lex + self.w_rag + self.w_consensus
        fused = (
            self.w_ocr * ocr_conf +
            self.w_vis * visual_conf +
            self.w_lex * effective_lex +
            self.w_rag * effective_rag +
            self.w_consensus * consensus_conf
        ) / total_weight

        fused = round(float(min(100.0, max(0.0, fused))), 2)

        # 4. Gate Independente de Revisão Humana
        # Se c_ocr < 50.0, a página é SEMPRE marcada para revisão, mesmo que a pontuação composta seja alta.
        needs_review = False
        review_reasons = []

        if ocr_conf < self.min_ocr_threshold:
            needs_review = True
            review_reasons.append(f"ocr_conf ({ocr_conf:.1f}%) < {self.min_ocr_threshold:.1f}%")

        if len(final_text.strip()) < min_char_count:
            needs_review = True
            review_reasons.append(f"char_count ({len(final_text.strip())}) < {min_char_count}")

        if floor_trap_triggered and ocr_conf < 70.0:
            needs_review = True
            review_reasons.append("floor_trap_zero_corrections_on_noisy_text")

        review_reason = "; ".join(review_reasons) if review_reasons else "approved"

        return ConfidenceDecomposition(
            ocr_conf=round(ocr_conf, 2),
            visual_conf=round(visual_conf, 2),
            lexical_conf=round(effective_lex, 2),
            rag_conf=round(effective_rag, 2),
            consensus_conf=round(consensus_conf, 2),
            fused_confidence=fused,
            needs_review=needs_review,
            floor_trap_triggered=floor_trap_triggered,
            review_reason=review_reason,
        )

    def fuse_confidence(
        self,
        ocr_conf: float,
        visual_conf: float,
        lexical_conf: float,
        rag_conf: float,
        consensus_conf: float = 100.0,
    ) -> float:
        """Compatibilidade retroativa: retorna apenas o valor numérico ponderado."""
        total_w = self.w_ocr + self.w_vis + self.w_lex + self.w_rag + self.w_consensus
        fused = (
            self.w_ocr * ocr_conf +
            self.w_vis * visual_conf +
            self.w_lex * lexical_conf +
            self.w_rag * rag_conf +
            self.w_consensus * consensus_conf
        ) / total_w
        return round(float(min(100.0, max(0.0, fused))), 2)

    def generate_confidence_heatmap(
        self,
        pil_img: Image.Image,
        tokens: list[dict[str, Any]],
    ) -> Image.Image:
        """
        Gera imagem da página com overlay semi-transparente color-coded por nível de confiança:
          - Verde (>= 88%): Alta confiança
          - Amarelo (70% - 87%): Confiança moderada
          - Vermelho (< 70%): Baixa confiança / requer atenção
        """
        base = pil_img.copy().convert("RGBA")
        overlay = Image.new("RGBA", base.size, (255, 255, 255, 0))
        draw = ImageDraw.Draw(overlay)

        for tok in tokens:
            bbox = tok.get("bbox")
            conf = tok.get("confidence", 0.0)
            if not bbox:
                continue

            if isinstance(bbox, BoundingBox):
                box = (bbox.x1, bbox.y1, bbox.x2, bbox.y2)
            elif isinstance(bbox, (list, tuple)) and len(bbox) == 4:
                box = (bbox[0], bbox[1], bbox[2], bbox[3])
            else:
                continue

            if conf >= 88.0:
                color = (46, 204, 113, 90)   # Verde suave
            elif conf >= 70.0:
                color = (241, 196, 15, 100)  # Amarelo
            else:
                color = (231, 76, 60, 120)   # Vermelho

            draw.rectangle(box, fill=color, outline=(color[0], color[1], color[2], 200), width=2)

        combined = Image.alpha_composite(base, overlay)
        return combined.convert("RGB")
