"""
Testes unitários para o BayesianConfidenceEngine (Capítulo 27 - Bayesian Confidence Engine).
"""
import unittest

from ocr_pipeline.confidence_engine.bayesian_confidence import (
    BayesianConfidenceEngine,
    BayesianEvidence,
    BayesianConfidenceResult,
)


class TestBayesianConfidenceEngine(unittest.TestCase):
    def setUp(self):
        self.engine = BayesianConfidenceEngine(prior_probability=0.60, temperature=1.15)

    def test_high_evidence_approval(self):
        # Evidências fortes de OCR, visual, léxico e consenso
        ev = BayesianEvidence(
            p_ocr=0.95,
            p_visual=0.90,
            p_layout=0.92,
            p_lexicon=0.88,
            p_rag=0.85,
            p_morphology=0.90,
            p_consensus=0.94,
        )
        res = self.engine.evaluate_page(ev, min_approval_p=0.70)
        self.assertIsInstance(res, BayesianConfidenceResult)
        self.assertFalse(res.floor_trap_active)
        self.assertFalse(res.needs_review)
        self.assertEqual(res.review_reason, "approved")
        self.assertGreater(res.calibrated_confidence_pct, 75.0)

    def test_low_ocr_floor_trap_enforcement(self):
        # OCR baixo (< 0.50): mesmo se layout for alto, a trava de piso Bayesiana DEVE ser acionada
        ev = BayesianEvidence(
            p_ocr=0.35,
            p_visual=0.60,
            p_layout=0.80,
            p_lexicon=0.70,
            p_rag=0.70,
            p_morphology=0.60,
            p_consensus=0.50,
        )
        res = self.engine.evaluate_page(ev)
        self.assertTrue(res.floor_trap_active)
        self.assertTrue(res.needs_review)
        self.assertIn("trava de piso", res.review_reason)

    def test_ece_computation(self):
        probs = [0.95, 0.90, 0.85, 0.60, 0.40, 0.20]
        labels = [1, 1, 1, 1, 0, 0]
        ece, bins = self.engine.compute_ece(probs, labels)
        self.assertIsInstance(ece, float)
        self.assertGreaterEqual(ece, 0.0)
        self.assertLessEqual(ece, 1.0)
        self.assertGreater(len(bins), 0)

    def test_brier_mce_and_scaling(self):
        probs = [0.95, 0.85, 0.70, 0.40, 0.20]
        labels = [1, 1, 1, 0, 0]
        brier = self.engine.compute_brier_score(probs, labels)
        self.assertIsInstance(brier, float)
        self.assertLess(brier, 0.15)

        mce = self.engine.compute_mce(probs, labels)
        self.assertIsInstance(mce, float)
        self.assertLessEqual(mce, 1.0)

        # 95% calibração
        p_iso = self.engine.isotonic_scale(0.95)
        self.assertAlmostEqual(p_iso, 0.948, delta=0.01)

        p_platt = self.engine.platt_scale(0.90)
        self.assertGreater(p_platt, 0.50)


if __name__ == "__main__":
    unittest.main()
