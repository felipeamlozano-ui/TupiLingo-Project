"""
Testes unitários para o TokenSuperResolutionEngine (Capítulo 26 - Token Super Resolution Engine).
"""
import unittest
from PIL import Image, ImageDraw

from ocr_pipeline.super_resolution_engine.token_sr_engine import (
    TokenSuperResolutionEngine,
    TokenSRAuditRecord,
)


class TestTokenSuperResolutionEngine(unittest.TestCase):
    def setUp(self):
        self.engine = TokenSuperResolutionEngine(confidence_threshold=75.0, min_gain_to_substitute=5.0)
        self.img = Image.new("RGB", (400, 200), color=(255, 255, 255))
        draw = ImageDraw.Draw(self.img)
        draw.text((30, 40), "morubixaba", fill=(0, 0, 0))

    def test_enhance_crop_models(self):
        crop = self.img.crop((20, 30, 150, 70))
        for m in ["real_esrgan", "swinir", "bsrgan"]:
            enhanced = self.engine.enhance_crop(crop, model_name=m, scale=2)
            self.assertEqual(enhanced.size[0], crop.size[0] * 2)
            self.assertEqual(enhanced.size[1], crop.size[1] * 2)

    def test_process_page_tokens_selective(self):
        tokens = [
            {"token_id": "tok_1", "text": "oka", "confidence": 92.0, "bbox": [10, 10, 50, 30]},
            {"token_id": "tok_2", "text": "morubixba", "confidence": 58.0, "bbox": [30, 40, 140, 70]},  # Abaixo do limiar
        ]

        updated_tokens, audits = self.engine.process_page_tokens(self.img, tokens)
        self.assertEqual(len(updated_tokens), 2)
        self.assertEqual(len(audits), 1)  # Apenas 1 token precisou de SR

        audit = audits[0]
        self.assertIsInstance(audit, TokenSRAuditRecord)
        self.assertEqual(audit.confidence_before, 58.0)
        self.assertTrue(audit.approved)
        self.assertGreater(audit.confidence_after, audit.confidence_before)


if __name__ == "__main__":
    unittest.main()
