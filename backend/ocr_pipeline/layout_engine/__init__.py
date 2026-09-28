"""
Pacote Layout Engine — TupiLingo OCR Forense v5
"""
from .doc_layout import ForensicLayoutEngine, LayoutRegion, ReadingOrderGraph
from .consensus_layout import ConsensusLayoutEngine, LayoutBlock, compute_iou

__all__ = [
    "ForensicLayoutEngine",
    "LayoutRegion",
    "ReadingOrderGraph",
    "ConsensusLayoutEngine",
    "LayoutBlock",
    "compute_iou",
]

