"""
Testes unitários automatizados para o DistributedCacheManager (LMDB + Checkpoints) — Capítulo 15.
"""
import shutil
import tempfile
import unittest
from pathlib import Path

from ocr_pipeline.cache_manager import DistributedCacheManager


class TestDistributedCacheManager(unittest.TestCase):
    def setUp(self):
        self.tmp_dir = Path(tempfile.mkdtemp())
        self.cache = DistributedCacheManager(cache_dir=self.tmp_dir)

    def tearDown(self):
        self.cache.close()
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

    def test_lmdb_ocr_cache(self):
        page_hash = "abc123hash"
        ocr_data = {
            "engine": "rapidocr_gpu",
            "text": "Tupinambá Morubixaba",
            "confidence": 94.5,
        }

        # Inicialmente nulo
        self.assertIsNone(self.cache.get_lmdb_ocr(page_hash))

        # Gravar no LMDB
        self.cache.set_lmdb_ocr(page_hash, ocr_data)

        # Recuperar do LMDB
        retrieved = self.cache.get_lmdb_ocr(page_hash)
        self.assertIsNotNone(retrieved)
        self.assertEqual(retrieved["text"], "Tupinambá Morubixaba")
        self.assertEqual(retrieved["confidence"], 94.5)

    def test_atomic_page_checkpoints(self):
        pdf_stem = "Ayrosa_1943"
        page_idx = 1
        checkpoint_data = {
            "pdf_stem": pdf_stem,
            "page_idx": page_idx,
            "status": "completed",
            "fused_confidence": 88.2,
            "needs_review": False,
        }

        self.assertFalse(self.cache.is_page_completed(pdf_stem, page_idx))

        # Gravar checkpoint
        self.cache.record_page_checkpoint(pdf_stem, page_idx, checkpoint_data)

        # Verificar se está marcado como concluído
        self.assertTrue(self.cache.is_page_completed(pdf_stem, page_idx))

        # Recuperar dados de checkpoint
        chk = self.cache.get_page_checkpoint(pdf_stem, page_idx)
        self.assertIsNotNone(chk)
        self.assertEqual(chk["status"], "completed")
        self.assertEqual(chk["fused_confidence"], 88.2)


if __name__ == "__main__":
    unittest.main()
