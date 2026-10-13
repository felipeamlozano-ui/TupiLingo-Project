"""
TupiLingo — Módulo de Autoridade Filológica, Integridade Lexical e RAG Baseado em Evidências.
Fundamentado na obra canônica:
Eduardo de Almeida Navarro, Dicionário de Tupi Antigo: a língua indígena clássica do Brasil,
1ª Edição, Global Editora, São Paulo, 2013.
"""

from .models import (
    BibliographicSource,
    InformationTier,
    LexicalEntry,
    OCREvidence,
    PhilologicalStatus,
    RAGResponseContract,
)
from .lexicon_repository import PhilologicalRepository, get_philological_repository
from .rag_engine import EvidenceGroundedRAG, get_evidence_grounded_rag
from .benchmark_rag import RAGBenchmarkSuite

__all__ = [
    "BibliographicSource",
    "InformationTier",
    "LexicalEntry",
    "OCREvidence",
    "PhilologicalStatus",
    "RAGResponseContract",
    "PhilologicalRepository",
    "get_philological_repository",
    "EvidenceGroundedRAG",
    "get_evidence_grounded_rag",
    "RAGBenchmarkSuite",
]
