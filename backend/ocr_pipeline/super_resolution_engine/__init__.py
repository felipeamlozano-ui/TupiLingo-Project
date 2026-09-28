"""
Pacote Super Resolution Engine — TupiLingo OCR Forense v3.0
"""
from .tile_enhancer import ForensicSuperResolutionEngine, SuperResolutionResult
from .token_sr_engine import TokenSuperResolutionEngine, TokenSRAuditRecord

__all__ = [
    "ForensicSuperResolutionEngine",
    "SuperResolutionResult",
    "TokenSuperResolutionEngine",
    "TokenSRAuditRecord",
]

