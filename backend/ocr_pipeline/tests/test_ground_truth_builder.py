"""
Testes para o GroundTruthManager (Capítulo 21 - Ground Truth Builder).
"""
import unittest
import tempfile
import sqlite3
from pathlib import Path
from PIL import Image

from ocr_pipeline.benchmarking.ground_truth_builder import GroundTruthManager


class TestGroundTruthManager(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.base_dir = Path(self.temp_dir.name)
        self.manager = GroundTruthManager(base_dir=self.base_dir)

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_save_and_retrieve_ground_truth(self):
        img = Image.new("RGB", (200, 200), color=(255, 255, 255))
        transcription = "oka morubixaba tatu"
        tokens = [
            {"token": "oka", "bbox": [10, 10, 40, 30]},
            {"token": "morubixaba", "bbox": [50, 10, 120, 30]},
            {"token": "tatu", "bbox": [130, 10, 160, 30]},
        ]

        page_dir = self.manager.save_page_ground_truth(
            page_id="page_015",
            pil_image=img,
            transcription=transcription,
            tokens=tokens,
            source_pdf="Ayrosa_1943.pdf",
            reviewer="filologia_humana",
        )

        self.assertTrue(page_dir.exists())
        self.assertTrue((page_dir / "image.png").exists())
        self.assertTrue((page_dir / "transcription.txt").exists())
        self.assertTrue((page_dir / "tokens.json").exists())
        self.assertTrue((page_dir / "metadata.json").exists())

        # Testar recuperação
        loaded = self.manager.get_ground_truth_for_page("page_015")
        self.assertIsNotNone(loaded)
        self.assertEqual(loaded["transcription"], transcription)
        self.assertEqual(len(loaded["tokens"]), 3)

        # Testar presença no banco SQLite
        conn = sqlite3.connect(self.manager.db_path)
        cursor = conn.cursor()
        cursor.execute("SELECT count(*) FROM ground_truth_tokens WHERE page_id = 'page_015'")
        count = cursor.fetchone()[0]
        conn.close()
        self.assertEqual(count, 3)

    def tearDown(self):
        import gc
        gc.collect()
        self.temp_dir.cleanup()
