"""
Testes unitários para o HierarchicalLexiconEngine (Capítulo 23 - Hierarchical Lexicon Engine).
"""
import unittest

from ocr_pipeline.lexical_engine.hierarchical_lexicon import (
    HierarchicalLexiconEngine,
    HierarchicalTokenScore,
)


class TestHierarchicalLexiconEngine(unittest.TestCase):
    def setUp(self):
        self.engine = HierarchicalLexiconEngine(
            document_frequency_map={"oka": 12, "morubixaba": 8, "tatu": 15}
        )

    def test_canonical_token_evaluation(self):
        score = self.engine.evaluate_token("oka")
        self.assertIsInstance(score, HierarchicalTokenScore)
        self.assertEqual(score.token, "oka")
        # Nível 1: Frequência
        self.assertEqual(score.document_frequency, 12)
        # Nível 2: Fontes Históricas
        self.assertGreater(score.historical_probability, 0.5)
        self.assertIn("Navarro", score.sources_found)
        self.assertIn("Anchieta", score.sources_found)
        # Nível 3: Variante
        self.assertEqual(score.detected_variant, "tupi_antigo")
        self.assertGreater(score.variant_probability, 0.8)
        # Nível 4: Morfologia
        self.assertGreater(score.morphological_probability, 0.8)
        # Probabilidade combinada
        self.assertGreater(score.lexicon_probability, 0.7)

    def test_morphological_derivation_evaluation(self):
        # Prefixo pronominal 'xe-' + 'oka' (minha casa) -> 'xeoka'
        score = self.engine.evaluate_token("xeoka")
        self.assertGreater(score.morphological_probability, 0.7)
        self.assertGreater(score.lexicon_probability, 0.5)

    def test_unknown_gibberish_token(self):
        score = self.engine.evaluate_token("xyzkw123")
        self.assertEqual(score.historical_probability, 0.0)
        self.assertEqual(score.morphological_probability, 0.0)
        self.assertLess(score.lexicon_probability, 0.3)


if __name__ == "__main__":
    unittest.main()
