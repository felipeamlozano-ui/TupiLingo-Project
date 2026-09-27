"""
Sistema de Proveniência e Auditoria Rastreável — TupiLingo OCR Forense v3.0
Garante que cada caractere, palavra e região possua linhagem completa de transformações.
"""
import time
import uuid
from typing import Any

from pydantic import BaseModel, Field


class BoundingBox(BaseModel):
    x1: int
    y1: int
    x2: int
    y2: int

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
    token_id: str = Field(default_factory=lambda: str(uuid.uuid4())[:8])
    raw_text: str
    cleaned_text: str
    confidence_raw: float
    confidence_fused: float
    engine_origin: str
    bbox: BoundingBox
    dpi: int
    preprocessing_branch: str
    lexical_transformations: list[dict[str, Any]] = Field(default_factory=list)
    tupi_morphology: dict[str, Any] | None = None
    rag_verified: bool = False
    is_rollback: bool = False

class RegionProvenance(BaseModel):
    region_id: str
    region_type: str # title, column_left, column_right, dictionary_entry, footnote, header
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
    confidence_before: float | None = None
    confidence_after: float = 0.0
    delta_confidence: float = 0.0
    accepted_corrections: int = 0
    rejected_rollbacks: int = 0
    dictionary_entries_count: int = 0
    elapsed_seconds: float = 0.0
    memory_rss_mb: float = 0.0
    status: str = "concluido"
