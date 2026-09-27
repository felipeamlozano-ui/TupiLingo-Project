"""
Testes unitários para o ForensicEnsembleEngine.
"""
import unittest

from PIL import Image, ImageDraw

from ocr_pipeline.ensemble_engine import ForensicEnsembleEngine


class TestForensicEnsembleEngine(unittest.TestCase):
    def setUp(self):
        self.engine = ForensicEnsembleEngine(cpu_threads=4)

    def test_ensemble_runs_and_caches_candidates(self):
        img = Image.new("RGB", (300, 100), color=(255, 255, 255))
        draw = ImageDraw.Draw(img)
        draw.text((20, 30), "Tupinambá 1555", fill=(0, 0, 0))

        candidates = self.engine.run_ensemble(img, psms=[6])
        self.assertGreater(len(candidates), 0)

        # Verificar se candidatos possuem campos válidos
        first = candidates[0]
        self.assertTrue(len(first.text) > 0)
        self.assertGreater(first.confidence, 0.0)
        self.assertTrue("tesseract" in first.engine or "rapidocr" in first.engine)

        # Segunda chamada deve atingir o cache
        candidates_cached = self.engine.run_ensemble(img, psms=[6])
        self.assertEqual(len(candidates), len(candidates_cached))

if __name__ == "__main__":
    unittest.main()
