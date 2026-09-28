"""
Testes unitários para AcademicPaperGenerator (Capítulo P da RFC v6.1).
"""
import unittest
import tempfile
from pathlib import Path
import pyarrow.parquet as pq

from ocr_pipeline.export_engine.academic_paper_generator import AcademicPaperGenerator


class TestAcademicPaperGenerator(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.target_dir = Path(self.temp_dir.name)
        self.generator = AcademicPaperGenerator(base_dir=self.target_dir)

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_generate_all_academic_deliverables(self):
        results = self.generator.generate_all()

        # Checar que as 5 chaves obrigatórias foram geradas
        expected_keys = [
            "RELATORIO_TCC.md",
            "ARTIGO_SBC.tex",
            "ARTIGO_IEEE.tex",
            "RESULTADOS_EXPERIMENTAIS.md",
            "METRICAS_COMPLETAS.parquet",
        ]
        for key in expected_keys:
            self.assertIn(key, results)
            files = results[key]
            self.assertGreater(len(files), 0)
            for f in files:
                self.assertTrue(f.exists(), f"Arquivo {f} não existe")
                self.assertGreater(f.stat().st_size, 0)

        # Checar conteúdo do Relatório TCC
        tcc_file = self.target_dir / "RELATORIO_TCC.md"
        tcc_text = tcc_file.read_text(encoding="utf-8")
        self.assertIn("RELATÓRIO TÉCNICO / TCC", tcc_text)
        self.assertIn("CER (Character Error Rate)", tcc_text)
        self.assertIn("Never Hallucinate", tcc_text)
        self.assertIn("Ground Truth", tcc_text)

        # Checar conteúdo do Artigo SBC
        sbc_file = self.target_dir / "ARTIGO_SBC.tex"
        sbc_text = sbc_file.read_text(encoding="utf-8")
        self.assertIn(r"\documentclass[12pt]{article}", sbc_text)
        self.assertIn("sbc-template", sbc_text)
        self.assertIn("Tupi Antigo", sbc_text)

        # Checar conteúdo do Artigo IEEE
        ieee_file = self.target_dir / "ARTIGO_IEEE.tex"
        ieee_text = ieee_file.read_text(encoding="utf-8")
        self.assertIn(r"\documentclass[conference]{IEEEtran}", ieee_text)
        self.assertIn("Bayesian Confidence Calibration", ieee_text)

        # Checar integridade do Parquet
        parquet_file = self.target_dir / "METRICAS_COMPLETAS.parquet"
        table = pq.read_table(parquet_file)
        self.assertGreater(table.num_rows, 0)
        self.assertIn("cer", table.column_names)
        self.assertIn("wer", table.column_names)
        self.assertIn("layout_iou", table.column_names)
        self.assertIn("ece", table.column_names)
        self.assertIn("tier", table.column_names)


if __name__ == "__main__":
    unittest.main()
