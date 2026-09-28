"""
Pacote Ensemble Engine — TupiLingo OCR Forense v3.0
"""
from .multi_engine import ForensicEnsembleEngine, OCRCandidate
from .self_consistency import SelfConsistencyOCREngine, HypothesisRecord, SelfConsistencyResult

__all__ = [
    "ForensicEnsembleEngine",
    "OCRCandidate",
    "SelfConsistencyOCREngine",
    "HypothesisRecord",
    "SelfConsistencyResult",
]

