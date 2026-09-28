"""
Testes unitários para o ActiveLearningEngine (Capítulo 29 - Active Learning Engine).
"""
import unittest
import tempfile
import gc
from pathlib import Path

from ocr_pipeline.lexical_engine.active_learning import (
    ActiveLearningEngine,
    ReviewRecord,
)


class TestActiveLearningEngine(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.engine = ActiveLearningEngine(
            storage_dir=Path(self.temp_dir.name),
            min_confirmations_for_whitelist=2,
        )

    def tearDown(self):
        gc.collect()
        self.temp_dir.cleanup()

    def test_review_submission_and_whitelist_promotion(self):
        # 1ª confirmação: ainda não atinge o mínimo (2)
        rec1 = self.engine.submit_human_review(
            token_before="morubixba",
            token_after="morubixaba",
            reviewer="curador_1",
            source_pdf="Ayrosa.pdf",
        )
        self.assertIsInstance(rec1, ReviewRecord)
        self.assertNotIn("morubixaba", self.engine.get_whitelist())

        # 2ª confirmação: deve ser promovida para a whitelist ativa
        rec2 = self.engine.submit_human_review(
            token_before="morubixba",
            token_after="morubixaba",
            reviewer="curador_2",
            source_pdf="Barbosa.pdf",
        )
        self.assertIn("morubixaba", self.engine.get_whitelist())

    def test_blacklist_registration(self):
        self.engine.add_to_blacklist("ruido123", reason="mancha_de_tinta", reviewer="curador_1")
        self.assertIn("ruido123", self.engine.get_blacklist())

    def test_verify_against_benchmark(self):
        # Ganho ou manutenção de CER: aprovado
        self.assertTrue(self.engine.verify_against_benchmark(previous_cer=5.0, new_cer=4.8))
        # Piora de CER: rejeitado
        self.assertFalse(self.engine.verify_against_benchmark(previous_cer=5.0, new_cer=6.2))


if __name__ == "__main__":
    unittest.main()
