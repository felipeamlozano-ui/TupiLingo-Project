"""
Testes unitários e de integração para o SelfConsistencyOCREngine (Capítulo 20 - Self Consistency OCR Engine).
"""
import unittest
import numpy as np
from PIL import Image, ImageDraw

from ocr_pipeline.ensemble_engine.self_consistency import (
    SelfConsistencyOCREngine,
    HypothesisRecord,
    SelfConsistencyResult,
)


class TestSelfConsistencyOCREngine(unittest.TestCase):
    def setUp(self):
        self.engine = SelfConsistencyOCREngine()
        # Imagem sintética com texto Tupi nítido
        self.img = Image.new("RGB", (300, 100), color=(255, 255, 255))
        draw = ImageDraw.Draw(self.img)
        draw.text((20, 35), "Tupinambá 1555", fill=(0, 0, 0))

    def test_filter_generation(self):
        img_np = np.array(self.img)
        for flt in ["clahe", "sauvola", "wolf", "retinex", "morph_reconstruction"]:
            res = self.engine.apply_filter(img_np, flt)
            self.assertEqual(res.shape[:2], img_np.shape[:2])

    def test_hypothesis_generation_and_consensus(self):
        # Modo rápido com filtros selecionados
        res = self.engine.process_region(self.img, fast_mode=True)
        self.assertIsInstance(res, SelfConsistencyResult)
        self.assertGreater(res.total_hypotheses, 0)
        self.assertGreater(len(res.hypotheses), 0)
        self.assertGreater(res.consensus_confidence, 0.0)
        self.assertTrue(len(res.consensus_text) > 0)
        # Nenhuma hipótese descartada silenciosamente
        self.assertEqual(len(res.hypotheses), res.total_hypotheses)


if __name__ == "__main__":
    unittest.main()
