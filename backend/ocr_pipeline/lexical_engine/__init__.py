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
from .hierarchical_lexicon import HierarchicalLexiconEngine, HierarchicalTokenScore
from .active_learning import ActiveLearningEngine, ReviewRecord
from .never_hallucinate_guard import NeverHallucinateGuard, TokenGuardDecision

__all__ = [
    "ForensicLexicalEngine",
    "ForensicLexicalResult",
    "LexicalCorrection",
    "MorphologicalDecomposition",
    "TupiMorphologicalParser",
    "HierarchicalLexiconEngine",
    "HierarchicalTokenScore",
    "ActiveLearningEngine",
    "ReviewRecord",
    "NeverHallucinateGuard",
    "TokenGuardDecision",
]


