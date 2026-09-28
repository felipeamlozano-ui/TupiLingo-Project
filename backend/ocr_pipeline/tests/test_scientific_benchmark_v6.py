"""
Testes unitários para o Scientific Benchmark Research Grade (Capítulo 22).
"""
import unittest
import tempfile
from pathlib import Path

from ocr_pipeline.benchmarking.scientific_benchmark import (
    ScientificBenchmarkEngine,
    BenchmarkMetricsResult,
)


class TestScientificBenchmarkV6(unittest.TestCase):
    def setUp(self):
        self.engine = ScientificBenchmarkEngine()
        self.temp_dir = tempfile.TemporaryDirectory()
        self.out_dir = Path(self.temp_dir.name)

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_precision_recall_and_categories(self):
        ref = "oka morubixaba tatu"
        hyp = "oka morubixaba tatu"
        prec, rec = self.engine.compute_token_precision_recall(ref, hyp)
        self.assertAlmostEqual(prec, 1.0)
        self.assertAlmostEqual(rec, 1.0)

        # Categorização
        self.assertEqual(self.engine.classify_category("Ayrosa_1943", 1, "Capa"), "capas")
        self.assertEqual(self.engine.classify_category("Dicionario_Tupi", 15, "verbete"), "dicionarios")

    def test_reports_generation_and_regression_gate(self):
        pages_data = [
            {"pdf_stem": "Ayrosa_1943", "page_num": 1, "final_text": "Capa", "fused_confidence": 52.0, "elapsed_seconds": 1.2},
            {"pdf_stem": "Ayrosa_1943", "page_num": 15, "final_text": "oka morubixaba", "fused_confidence": 88.0, "elapsed_seconds": 3.4},
        ]
        gt = {"Ayrosa_1943::15": "oka morubixaba"}

        metrics = self.engine.evaluate_batch(pages_data, ground_truth=gt)
        reports = self.engine.generate_reports(metrics, self.out_dir)

        self.assertTrue(reports["cer_report"].exists())
        self.assertTrue(reports["wer_report"].exists())
        self.assertTrue(reports["benchmark_history"].exists())

        # Teste de bloqueio de regressão
        self.engine.assert_no_regression(previous_cer=5.0, current_cer=5.2)  # Dentro da tolerância
        with self.assertRaises(ValueError):
            self.engine.assert_no_regression(previous_cer=5.0, current_cer=8.0)  # Regressão proibida


if __name__ == "__main__":
    unittest.main()
