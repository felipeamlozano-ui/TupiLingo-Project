"""
Sistema de Proveniência e Auditoria Rastreável — Capítulo 14 (Provenance Engine)
Garante que cada caractere, token, bloco e página possua rastreabilidade e linhagem completa:
UUID, BBox, motor de origem, branch de pré-processamento, super-resolução, PSM/DPI,
confiança bruta/composta, candidatos considerados, correção aplicada com ID do chunk do RAG e status de rollback.
"""
import time
import uuid
from typing import Any, Optional

from pydantic import BaseModel, Field


class BoundingBox(BaseModel):
    x1: int
    y1: int
    x2: int
    y2: int
    page_num: Optional[int] = None

    @property
    def width(self) -> int:
        return max(0, self.x2 - self.x1)

    @property
    def height(self) -> int:
        return max(0, self.y2 - self.y1)

    @property
    def area(self) -> int:
        return self.width * self.height


class TokenProvenance(BaseModel):
    token_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    raw_text: str
    cleaned_text: str
    confidence_raw: float
    confidence_fused: float
    engine_origin: str  # rapidocr_gpu, tesseract_psm6, etc.
    bbox: BoundingBox
    preprocessing_branch: str = "default"
    super_resolution_model: Optional[str] = None
    psm: Optional[int] = None
    dpi: int = 300
    candidates_considered: list[dict[str, Any]] = Field(default_factory=list)
    correction_applied: Optional[str] = None
    rag_provenance_id: Optional[str] = None
    is_rollback: bool = False
    tupi_morphology: Optional[dict[str, Any]] = None
    rag_verified: bool = False
    # RFC v6.1 Capítulo I — Explainability Engine
    winning_filter: Optional[str] = None
    winning_ocr: Optional[str] = None
    competing_ocrs: list[dict[str, Any]] = Field(default_factory=list)
    layout_detector: Optional[str] = None
    score_ocr: Optional[float] = None
    score_layout: Optional[float] = None
    score_lexicon: Optional[float] = None
    score_rag: Optional[float] = None
    score_morphology: Optional[float] = None
    score_consensus: Optional[float] = None
    calibrated_confidence: Optional[float] = None
    rollback_applied: bool = False
    human_reviewed: bool = False
    crop_image_path: Optional[str] = None

    def explain_decision_tree(self) -> dict[str, Any]:
        """Gera a árvore de decisão explicável para o token (Capítulo I)."""
        return {
            "token_id": self.token_id,
            "surface_form": self.cleaned_text,
            "raw_hypothesis": self.raw_text,
            "bbox": [self.bbox.x1, self.bbox.y1, self.bbox.x2, self.bbox.y2],
            "visual_provenance": {
                "winning_filter": self.winning_filter or self.preprocessing_branch,
                "super_resolution": self.super_resolution_model or "none",
                "crop_ref": self.crop_image_path,
            },
            "ocr_consensus": {
                "winner": self.winning_ocr or self.engine_origin,
                "score_ocr": self.score_ocr or self.confidence_raw,
                "competitors": self.competing_ocrs or self.candidates_considered,
            },
            "linguistic_and_rag_scores": {
                "score_layout": self.score_layout or 0.90,
                "score_lexicon": self.score_lexicon or 0.85,
                "score_rag": self.score_rag or (1.0 if self.rag_verified else 0.5),
                "score_morphology": self.score_morphology or (1.0 if self.tupi_morphology else 0.5),
                "score_consensus": self.score_consensus or 0.5,
            },
            "governance": {
                "calibrated_confidence": self.calibrated_confidence or self.confidence_fused,
                "rollback_applied": self.rollback_applied or self.is_rollback,
                "human_reviewed": self.human_reviewed,
            },
        }


class RegionProvenance(BaseModel):
    region_id: str
    region_type: str  # title, header, footer, column_left, column_right, dictionary_entry, footnote
    bbox: BoundingBox
    tokens: list[TokenProvenance] = Field(default_factory=list)
    recovery_iterations: int = 0
    winner_branch: str = "default"
    mean_confidence: float = 0.0


class PageAuditTrail(BaseModel):
    audit_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    filename: str
    page_num: int
    dimensions: tuple[int, int]
    timestamp: str = Field(default_factory=lambda: time.strftime("%Y-%m-%d %H:%M:%S"))
    diagnostic_summary: dict[str, Any] = Field(default_factory=dict)
    branches_evaluated: list[str] = Field(default_factory=list)
    regions: list[RegionProvenance] = Field(default_factory=list)
    confidence_before: Optional[float] = None
    confidence_after: float = 0.0
    delta_confidence: float = 0.0
    accepted_corrections: int = 0
    rejected_rollbacks: int = 0
    dictionary_entries_count: int = 0
    elapsed_seconds: float = 0.0
    memory_rss_mb: float = 0.0
    vram_used_mb: Optional[float] = None
    status: str = "concluido"
