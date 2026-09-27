"""
Engine de Fusão de Confiança e Geração de Heatmap — TupiLingo OCR Forense v3.0
Calcula a confiança multidimensional final e gera o mapa de calor visual da página.
"""
from typing import Any

from PIL import Image, ImageDraw

from ..core.provenance import BoundingBox


class ForensicConfidenceFusionEngine:
    def __init__(
        self,
        w_ocr: float = 0.45,
        w_vis: float = 0.20,
        w_lex: float = 0.20,
        w_rag: float = 0.15
    ):
        self.w_ocr = w_ocr
        self.w_vis = w_vis
        self.w_lex = w_lex
        self.w_rag = w_rag

    def fuse_confidence(
        self,
        ocr_conf: float,
        visual_conf: float,
        lexical_conf: float,
        rag_conf: float
    ) -> float:
        """Calcula o score de confiança composto ponderado (0 a 100)."""
        fused = (
            self.w_ocr * ocr_conf +
            self.w_vis * visual_conf +
            self.w_lex * lexical_conf +
            self.w_rag * rag_conf
        )
        return round(float(min(100.0, max(0.0, fused))), 2)

    def generate_confidence_heatmap(
        self,
        pil_img: Image.Image,
        tokens: list[dict[str, Any]]
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

            # Escolha da cor com transparência alpha
            if conf >= 88.0:
                color = (46, 204, 113, 90)   # Verde suave
            elif conf >= 70.0:
                color = (241, 196, 15, 100)  # Amarelo
            else:
                color = (231, 76, 60, 120)   # Vermelho

            draw.rectangle(box, fill=color, outline=(color[0], color[1], color[2], 200), width=2)

        combined = Image.alpha_composite(base, overlay)
        return combined.convert("RGB")
