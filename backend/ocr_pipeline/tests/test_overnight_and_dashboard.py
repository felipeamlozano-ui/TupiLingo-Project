"""
Testes unitários automatizados para o Dashboard Arquivístico, Benchmark Científico e Scheduler Overnight — Capítulos 16, 17 e 18.
"""
import shutil
import tempfile
import unittest
from pathlib import Path

from ocr_pipeline.archival_dashboard import ArchivalDashboardGenerator
from ocr_pipeline.benchmarking.scientific_benchmark import ScientificBenchmarkEngine
from ocr_pipeline.overnight_scheduler import AutonomousOvernightScheduler


class TestOvernightAndDashboard(unittest.TestCase):
    def setUp(self):
        self.tmp_dir = Path(tempfile.mkdtemp())

    def tearDown(self):
        shutil.rmtree(self.tmp_dir, ignore_errors=True)

    def test_archival_dashboard_generation(self):
        out_html = self.tmp_dir / "dashboard.html"
        generator = ArchivalDashboardGenerator(output_path=out_html)

        records = [
            {
                "pdf_stem": "Ayrosa_1943",
                "page_num": 1,
                "fused_confidence": 42.5,
                "ocr_conf": 34.7,
                "needs_review": True,
                "review_reason": "ocr_conf < 50.0%",
                "elapsed_seconds": 1.25,
                "rss_mb": 150.0,
                "vram_mb": 512.0,
                "final_text": "eossad sono Waye",
                "decomposition": {
                    "ocr_conf": 34.7,
                    "visual_conf": 75.0,
                    "lexical_conf": 0.0,
                    "rag_conf": 0.0,
                    "consensus_conf": 70.0,
                    "floor_trap_triggered": True,
                },
            }
        ]

        result_path = generator.generate(records, title="Teste Dashboard", ground_truth_available=False)
        self.assertTrue(result_path.exists())
        content = result_path.read_text(encoding="utf-8")
        self.assertIn("Ayrosa_1943", content)
        self.assertIn("Trava de Piso Acionada", content)
        self.assertIn("Proxy Heurístico", content)

    def test_scientific_benchmark_cer_wer_and_proxy(self):
        bench = ScientificBenchmarkEngine()

        # 1. Teste CER (Character Error Rate)
        # "tupinamba" vs "tupinambá": 1 substituição / 9 caracteres = ~0.111
        cer = bench.compute_cer("tupinamba", "tupinambá")
        self.assertGreater(cer, 0.0)
        self.assertLess(cer, 0.25)

        # 2. Teste WER (Word Error Rate)
        # "o guerreiro tupi" vs "o guerreiro tupinamba": 1 erro / 3 palavras = 0.333
        wer = bench.compute_wer("o guerreiro tupi", "o guerreiro tupinamba")
        self.assertAlmostEqual(wer, 1 / 3, places=2)

        # 3. Teste em Lote sem Ground Truth (Proxy Heurístico)
        pages_data = [
            {
                "pdf_stem": "doc1",
                "page_num": 1,
                "fused_confidence": 88.0,
                "final_text": "palavra autentica tupi",
                "elapsed_seconds": 1.5,
            }
        ]
        res = bench.evaluate_batch(pages_data, ground_truth=None)
        self.assertEqual(res.metric_type, "proxy_heuristico")
        self.assertIsNone(res.ground_truth_cer)
        self.assertEqual(res.mean_confidence_proxy, 88.0)

        # 4. Teste em Lote com Ground Truth Homologado
        gt = {"doc1::1": "palavra autentica tupi"}
        res_gt = bench.evaluate_batch(pages_data, ground_truth=gt)
        self.assertEqual(res_gt.metric_type, "ground_truth_homologado")
        self.assertEqual(res_gt.ground_truth_cer, 0.0)
        self.assertEqual(res_gt.ground_truth_wer, 0.0)


if __name__ == "__main__":
    unittest.main()
