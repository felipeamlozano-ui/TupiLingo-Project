"""
Testes unitários para o AutoBenchmarkPipeline (Capítulo M - Pipeline de Regressão Automática).
"""
import unittest
import tempfile
from pathlib import Path

from ocr_pipeline.benchmarking.auto_benchmark import (
    AutoBenchmarkPipeline,
    VersionComparisonResult,
)


class TestAutoBenchmarkPipeline(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.pipeline = AutoBenchmarkPipeline(
            output_dir=Path(self.temp_dir.name),
            regression_tolerance_cer=0.5,
            regression_tolerance_wer=1.0,
            max_vram_mb=6144.0,
            max_latency_increase_ratio=0.20,
            max_ece_degradation=0.05,
        )

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_compare_runs_approval(self):
        v5_data = [
            {"pdf_stem": "Ayrosa", "page_num": 15, "final_text": "oka morubixaba", "fused_confidence": 75.0, "elapsed_seconds": 6.0}
        ]
        v6_data = [
            {"pdf_stem": "Ayrosa", "page_num": 15, "final_text": "oka morubixaba", "fused_confidence": 92.0, "elapsed_seconds": 4.5}
        ]
        gt = {"Ayrosa::15": "oka morubixaba"}

        comp = self.pipeline.compare_runs(
            v5_data,
            v6_data,
            ground_truth=gt,
            v6_vram_mb=1850.0,
            v5_ece=0.085,
            v6_ece=0.032,
        )
        self.assertIsInstance(comp, VersionComparisonResult)
        self.assertEqual(comp.status, "APROVADO")
        self.assertFalse(comp.regression_detected)
        self.assertTrue((self.pipeline.output_dir / "latest_comparison.json").exists())
        self.assertTrue((self.pipeline.output_dir / "comparison_chart.svg").exists())
        self.assertTrue((self.pipeline.output_dir / "REGRESSION_REPORT.md").exists())
        self.assertEqual(len(comp.blocking_reasons), 0)

    def test_compare_runs_blocks_on_cer_regression(self):
        # v6 CER pior que v5 + tolerância
        v5_data = [{"pdf_stem": "Ayrosa", "page_num": 15, "final_text": "oka morubixaba", "fused_confidence": 90.0, "elapsed_seconds": 5.0}]
        v6_data = [{"pdf_stem": "Ayrosa", "page_num": 15, "final_text": "err wrong words", "fused_confidence": 50.0, "elapsed_seconds": 5.0}]
        gt = {"Ayrosa::15": "oka morubixaba"}

        # Simulate worsening
        pipeline = AutoBenchmarkPipeline(
            output_dir=Path(self.temp_dir.name),
            regression_tolerance_cer=0.1,
        )
        comp = pipeline.compare_runs(
            v5_data,
            v6_data,
            ground_truth=gt,
            v6_vram_mb=7000.0,  # VRAM exceeded
            v5_ece=0.03,
            v6_ece=0.15,       # ECE degraded
        )
        self.assertEqual(comp.status, "REGRESSAO_BLOQUEADA")
        self.assertTrue(comp.regression_detected)
        self.assertGreater(len(comp.blocking_reasons), 0)


if __name__ == "__main__":
    unittest.main()

