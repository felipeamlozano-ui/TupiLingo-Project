"""
Módulo do Motor Léxico Forense com Salvaguarda Morfológica Tupi e Invariantes.
"""

from .forensic_lexicon import (
    ForensicLexicalEngine,
    ForensicLexicalResult,
    LexicalCorrection,
    MorphologicalDecomposition,
    TupiMorphologicalParser,
)

__all__ = [
    "ForensicLexicalEngine",
    "ForensicLexicalResult",
    "LexicalCorrection",
    "MorphologicalDecomposition",
    "TupiMorphologicalParser",
]
