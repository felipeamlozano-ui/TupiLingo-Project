"""
Testes unitários e validações sintéticas para o ForensicDiagnosticEngine.
"""
import unittest

import numpy as np
from PIL import Image, ImageDraw

from ocr_pipeline.diagnostic_engine import ForensicDiagnosticEngine


class TestForensicDiagnosticEngine(unittest.TestCase):
    def setUp(self):
        self.engine = ForensicDiagnosticEngine()

    def test_sharp_synthetic_image(self):
        # Imagem nítida com texto sintético
        img = Image.new("RGB", (400, 400), color=(255, 255, 255))
        draw = ImageDraw.Draw(img)
        for y in range(50, 350, 30):
            draw.text((50, y), "Tupinambá morubixaba oka peẽ iandé 123", fill=(0, 0, 0))

        report = self.engine.analyze_image(img, page_num=1)
        self.assertEqual(report.page, 1)
        self.assertGreater(report.laplacian_variance, 50.0)
        self.assertFalse(report.yellow_paper)
        self.assertIn(report.ink_loss, ["low", "medium", "high"])
        self.assertGreater(report.connected_components_count, 10)

    def test_yellow_paper_detection(self):
        # Papel envelhecido sintético (canal B* do LAB alto, cor amarelada/castanha)
        img = Image.new("RGB", (300, 300), color=(240, 220, 160))
        draw = ImageDraw.Draw(img)
        draw.text((50, 50), "Texto Antigo", fill=(40, 30, 10))

        report = self.engine.analyze_image(img, page_num=42)
        self.assertTrue(report.yellow_paper)
        self.assertGreater(report.paper_aging_index, 5.0)

    def test_blur_detection(self):
        # Imagem borrada
        arr = np.full((200, 200, 3), 200, dtype=np.uint8)
        img = Image.fromarray(arr)
        report = self.engine.analyze_image(img, page_num=2)
        self.assertLess(report.laplacian_variance, 5.0)
        self.assertLess(report.blur_score, 0.1)

if __name__ == "__main__":
    unittest.main()
