"""
Modelos de dados e schemas para o pipeline modular de OCR (Fase 0 e Fase 1).
"""
from dataclasses import dataclass, field
from enum import Enum
from typing import Any


class PageType(str, Enum):
    DIGITAL = "digital"
    SCAN = "scan"
    HYBRID = "hybrid"

class RoutingDecision(str, Enum):
    OCR_RAPIDO = "ocr_rapido"                    # 98-100: Fast/Existing
    OCR_PADRAO = "ocr_padrao"                    # 94-97: Standard/Existing
    FASE1_REFORCADO = "fase1_reforcado"          # 90-93: Phase 1 reinforced
    FASE1_ATENCAO = "fase1_completo_atencao"     # 85-89: Phase 1 complete + flag
    FASE1_REVISAO = "fase1_completo_revisao"     # < 85: Phase 1 complete + mandatory review

@dataclass
class PageProfile:
    filename: str
    page_num: int
    file_hash: str
    page_hash: str
    width: int
    height: int
    dpi_effective: int
    page_type: PageType
    num_columns: int
    column_valley_ratio: float
    has_bleed_through: bool
    bleed_through_ratio: float
    blur_laplacian: float
    contrast_rms: float
    entropy: float
    skew_angle: float
    iqa_score_raw: float
    iqa_score_calibrated: float
    historical_ocr_conf: float | None
    precisa_revisao_historico: bool
    quality_score: float
    routing_decision: RoutingDecision
    metadata: dict[str, Any] = field(default_factory=dict)

@dataclass
class OCRToken:
    text: str
    conf: float
    bbox: tuple[int, int, int, int] # x1, y1, x2, y2
    engine: str

@dataclass
class OCRPageResult:
    filename: str
    page_num: int
    text_raw: str
    text_cleaned: str
    text_before_lexicon: str
    text_after_lexicon: str
    mean_confidence: float
    min_confidence: float
    engine_primary: str
    engine_secondary: str | None
    agreement_rate: float
    corrections_applied: list[dict[str, Any]] = field(default_factory=list)
    reading_order_blocks: int = 1
    layout_type: str = "single_column"
    audit_trail: dict[str, Any] = field(default_factory=dict)

@dataclass
class DictionaryChunk:
    chunk_index: int
    text: str
    headword: str | None
    part_of_speech: str | None
    sub_sense: str | None
    source_filename: str
    page_num: int
    is_subdivided: bool
    char_count: int
    metadata: dict[str, Any] = field(default_factory=dict)

@dataclass
class PageAuditRecord:
    filename: str
    page_num: int
    quality_score: float
    routing_decision: str
    preprocessing_applied: list[str]
    engine_used: str
    confidence_before: float | None
    confidence_after: float
    agreement_rate: float
    lexical_corrections_count: int
    dictionary_entries_found: int
    chunks_generated: int
    needs_manual_review: bool
    sanity_status: str
    elapsed_seconds: float
