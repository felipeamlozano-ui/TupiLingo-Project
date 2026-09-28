"""
Testes unitários e de integração para o ConsensusLayoutEngine (Capítulo 19 - Document AI Ensemble).
"""
import unittest
import numpy as np
from PIL import Image

from ocr_pipeline.layout_engine.consensus_layout import (
    ConsensusLayoutEngine,
    DocLayoutYOLODetector,
    LayoutLMv3Detector,
    Detectron2Detector,
    compute_iou,
)
from ocr_pipeline.core.provenance import BoundingBox


class TestConsensusLayoutEngine(unittest.TestCase):
    def setUp(self):
        self.engine = ConsensusLayoutEngine(iou_threshold=0.50)
        # Imagem sintética simulando página de livro com cabeçalho, 2 colunas e rodapé
        self.img = Image.new("RGB", (800, 1000), color=(255, 255, 255))

    def test_compute_iou(self):
        b1 = BoundingBox(x1=10, y1=10, x2=50, y2=50)
        b2 = BoundingBox(x1=10, y1=10, x2=50, y2=50)
        self.assertAlmostEqual(compute_iou(b1, b2), 1.0)

        b3 = BoundingBox(x1=60, y1=60, x2=100, y2=100)
        self.assertEqual(compute_iou(b1, b3), 0.0)

        b4 = BoundingBox(x1=30, y1=10, x2=70, y2=50)
        iou = compute_iou(b1, b4)
        self.assertGreater(iou, 0.0)
        self.assertLess(iou, 1.0)

    def test_consensus_layout_execution(self):
        blocks = self.engine.execute_ensemble(self.img)
        self.assertGreater(len(blocks), 0)

        for blk in blocks:
            self.assertFalse(blk.is_rejected)
            self.assertGreater(blk.layout_confidence, 0.0)
            self.assertGreater(blk.structural_score, 0.0)
            self.assertGreater(len(blk.detectors_used), 0)
            self.assertGreater(blk.reading_order_index, 0)

        # Verificar se identificou cabeçalho e rodapé
        labels = [b.label for b in blocks]
        self.assertIn("header", labels)
        self.assertIn("footer", labels)


if __name__ == "__main__":
    unittest.main()
