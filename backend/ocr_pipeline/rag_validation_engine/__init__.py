"""
Módulo Validador RAG Forense Zero Alucinação.
"""

from .rag_validator import (
    CorpusOccurrence,
    RAGValidationResult,
    RAGValidator,
)
from .document_consensus import DocumentConsensusValidator, ConsensusTable, SourceHit
from .corpus_inverted_index import CorpusInvertedIndex, TokenOccurrence

__all__ = [
    "CorpusOccurrence",
    "RAGValidationResult",
    "RAGValidator",
    "DocumentConsensusValidator",
    "ConsensusTable",
    "SourceHit",
    "CorpusInvertedIndex",
    "TokenOccurrence",
]

