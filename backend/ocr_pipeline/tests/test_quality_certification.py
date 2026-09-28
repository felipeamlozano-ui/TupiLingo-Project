"""
Testes unitários para QualityCertifier e níveis Bronze/Prata/Ouro (Capítulo O).
"""
import unittest
import tempfile
from pathlib import Path

from ocr_pipeline.core.quality_certification import (
    QualityCertifier,
    QualityTier,
    CertificationResult,
)


class TestQualityCertification(unittest.TestCase):
    def setUp(self):
        self.certifier = QualityCertifier(
            max_gold_cer=5.0,
            max_gold_wer=10.0,
            min_gold_confidence=90.0,
            max_gold_ece=0.05,
        )

    def test_page_qualifies_for_gold(self):
        page_data = {
            "page_id": "Ayrosa_1943::15",
            "cer": 3.2,
            "wer": 6.8,
            "fused_confidence": 95.5,
            "ece": 0.025,
            "uncertain_tokens_count": 0,
            "has_complete_provenance": True,
        }
        res = self.certifier.evaluate_page(page_data)
        self.assertEqual(res.tier, QualityTier.OURO)
        self.assertTrue(res.can_enter_pedagogical_db)
        self.assertEqual(len(res.rejection_reasons), 0)

    def test_page_rejected_from_gold_due_to_uncertain_tokens(self):
        page_data = {
            "page_id": "Ayrosa_1943::16",
            "cer": 2.0,
            "wer": 4.0,
            "fused_confidence": 96.0,
            "ece": 0.02,
            "uncertain_tokens_count": 2,  # Quarentena de tokens suspeitos
            "has_complete_provenance": True,
        }
        res = self.certifier.evaluate_page(page_data)
        self.assertEqual(res.tier, QualityTier.PRATA)
        self.assertFalse(res.can_enter_pedagogical_db)
        self.assertIn("tokens UNCERTAIN em quarentena", res.rejection_reasons[0])

    def test_page_falls_to_bronze_due_to_high_cer(self):
        page_data = {
            "page_id": "Degraded_1600::1",
            "cer": 25.0,
            "wer": 45.0,
            "fused_confidence": 55.0,
            "ece": 0.12,
            "uncertain_tokens_count": 5,
            "has_complete_provenance": False,
        }
        res = self.certifier.evaluate_page(page_data)
        self.assertEqual(res.tier, QualityTier.BRONZE)
        self.assertFalse(res.can_enter_pedagogical_db)
        self.assertGreater(len(res.rejection_reasons), 1)

    def test_filter_corpus_pedagogical_db(self):
        corpus = [
            {"page_id": "p1", "cer": 2.5, "wer": 5.0, "fused_confidence": 96.0, "uncertain_tokens_count": 0},
            {"page_id": "p2", "cer": 8.0, "wer": 15.0, "fused_confidence": 85.0, "uncertain_tokens_count": 1},
            {"page_id": "p3", "cer": 1.5, "wer": 3.0, "fused_confidence": 98.0, "uncertain_tokens_count": 0},
        ]
        pedagogical_pages = self.certifier.filter_corpus_for_pedagogical_db(corpus)
        self.assertEqual(len(pedagogical_pages), 2)
        self.assertEqual([p["page_id"] for p in pedagogical_pages], ["p1", "p3"])

    def test_export_certification_report(self):
        results = [
            CertificationResult(
                page_id="doc1::1",
                tier=QualityTier.OURO,
                cer=2.5,
                wer=5.0,
                calibrated_confidence=95.0,
                ece=0.03,
                has_complete_provenance=True,
                uncertain_tokens_count=0,
                can_enter_pedagogical_db=True,
            ),
            CertificationResult(
                page_id="doc1::2",
                tier=QualityTier.PRATA,
                cer=7.0,
                wer=12.0,
                calibrated_confidence=82.0,
                ece=0.04,
                has_complete_provenance=True,
                uncertain_tokens_count=1,
                can_enter_pedagogical_db=False,
                rejection_reasons=["Existem 1 tokens UNCERTAIN em quarentena"],
            ),
        ]
        with tempfile.TemporaryDirectory() as tmp_dir:
            out_md = Path(tmp_dir) / "cert_report.md"
            self.certifier.export_certification_report(results, out_md)
            self.assertTrue(out_md.exists())
            content = out_md.read_text(encoding="utf-8")
            self.assertIn("Nível OURO", content)
            self.assertIn("Nível PRATA", content)
            self.assertIn("Permitido", content)
            self.assertIn("Bloqueado", content)


if __name__ == "__main__":
    unittest.main()
