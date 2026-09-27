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
    lexical_transformations: list[dict[str, Any]] = Field(default_factory=list)
    tupi_morphology: Optional[dict[str, Any]] = None
    rag_verified: bool = False


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
