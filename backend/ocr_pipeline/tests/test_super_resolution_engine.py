"""
Testes unitários para o ForensicSuperResolutionEngine.
"""
import unittest

from PIL import Image, ImageDraw

from ocr_pipeline.super_resolution_engine import ForensicSuperResolutionEngine


class TestForensicSuperResolutionEngine(unittest.TestCase):
    def setUp(self):
        self.engine = ForensicSuperResolutionEngine()

    def test_super_resolution_scaling_and_gain(self):
        # Imagem sintética de 100x100
        img = Image.new("L", (100, 100), color=255)
        draw = ImageDraw.Draw(img)
        draw.text((20, 30), "Tupi", fill=0)

        # 2x Super-Resolution
        enhanced_2x, meta_2x = self.engine.enhance_image(img, scale=2)
        self.assertEqual(enhanced_2x.size, (200, 200))
        self.assertEqual(meta_2x.scale, 2)
        self.assertGreater(meta_2x.laplacian_after, 0.0)

        # 3x Super-Resolution
        enhanced_3x, meta_3x = self.engine.enhance_image(img, scale=3)
        self.assertEqual(enhanced_3x.size, (300, 300))
        self.assertEqual(meta_3x.scale, 3)

if __name__ == "__main__":
    unittest.main()
