"""
Testes unitários automatizados para o ForensicSuperResolutionEngine — Capítulo 6.
"""
import unittest

from PIL import Image, ImageDraw

from ocr_pipeline.super_resolution_engine import ForensicSuperResolutionEngine


class TestForensicSuperResolutionEngine(unittest.TestCase):
    def setUp(self):
        self.engine = ForensicSuperResolutionEngine()

    def test_vram_tile_scheduler_decision(self):
        tile_size, device = self.engine.determine_tile_and_device()
        self.assertIn(tile_size, [256, 512, 768, 1024])
        self.assertIsInstance(device, str)

    def test_super_resolution_scaling_and_gain(self):
        img = Image.new("L", (100, 100), color=255)
        draw = ImageDraw.Draw(img)
        draw.text((20, 30), "Tupi", fill=0)

        # 2x Super-Resolution
        enhanced_2x, meta_2x = self.engine.enhance_image(img, scale=2)
        self.assertEqual(enhanced_2x.size, (200, 200))
        self.assertEqual(meta_2x.scale, 2)
        self.assertGreater(meta_2x.laplacian_after, 0.0)
        self.assertGreaterEqual(meta_2x.tile_count, 1)

        # 3x Super-Resolution
        enhanced_3x, meta_3x = self.engine.enhance_image(img, scale=3)
        self.assertEqual(enhanced_3x.size, (300, 300))
        self.assertEqual(meta_3x.scale, 3)

    def test_forced_cpu_execution(self):
        img = Image.new("RGB", (64, 64), color=(200, 200, 200))
        enhanced, meta = self.engine.enhance_image(img, scale=2, force_cpu=True)
        self.assertEqual(enhanced.size, (128, 128))
        self.assertEqual(meta.device_used, "CPU:Forced")


if __name__ == "__main__":
    unittest.main()
