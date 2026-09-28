"""
Testes unitários para o OrientationAndDewarpEngine (Capítulo 25 - Orientation & Dewarp Engine).
"""
import unittest
import numpy as np
from PIL import Image, ImageDraw

from ocr_pipeline.preprocessing_engine.dewarp_engine import (
    OrientationAndDewarpEngine,
    DewarpResult,
)


class TestOrientationAndDewarpEngine(unittest.TestCase):
    def setUp(self):
        self.engine = OrientationAndDewarpEngine(curvature_threshold=0.10)
        # Imagem sintética com linhas de texto
        self.img = Image.new("RGB", (400, 300), color=(255, 255, 255))
        draw = ImageDraw.Draw(self.img)
        for y in range(30, 270, 25):
            draw.text((30, y), "Texto historico em lingua tupi para teste de orientacao", fill=(0, 0, 0))

    def test_normal_orientation_processing(self):
        corrected, result = self.engine.process_image(self.img)
        self.assertIsInstance(result, DewarpResult)
        self.assertIn(result.rotation_degrees, (0, 90, 180, 270))
        self.assertIsInstance(result.curvature_score, float)
        self.assertIsInstance(result.dewarp_applied, bool)
        self.assertEqual(corrected.size[0], self.img.size[0])

    def test_mesh_dewarp_transformation(self):
        img_np = np.array(self.img)
        dewarped = self.engine.mesh_dewarp(img_np, curvature_score=0.25)
        self.assertEqual(dewarped.shape, img_np.shape)


if __name__ == "__main__":
    unittest.main()
