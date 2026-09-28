"""
Testes unitários para o DocumentConsensusValidator (Capítulo 24 - Document Consensus Validator).
"""
import unittest

from ocr_pipeline.rag_validation_engine.document_consensus import (
    DocumentConsensusValidator,
    ConsensusTable,
)


class TestDocumentConsensusValidator(unittest.TestCase):
    def setUp(self):
        self.validator = DocumentConsensusValidator()

    def test_multi_source_consensus_boost(self):
        # 'oka' existe em 4 fontes independentes (Ayrosa, Barbosa, Masucci, Fernandes)
        table = self.validator.validate_token_consensus("oka")
        self.assertIsInstance(table, ConsensusTable)
        self.assertEqual(table.consensus_status, "consenso_multiplo")
        self.assertGreaterEqual(table.independent_sources_count, 3)
        self.assertEqual(table.confidence_boost, 0.15)
        self.assertTrue(table.allow_automatic_approval)

    def test_two_source_consensus_boost(self):
        # 'pira' existe em 2 fontes independentes (Ayrosa, Barbosa)
        table = self.validator.validate_token_consensus("pira")
        self.assertEqual(table.consensus_status, "consenso_multiplo")
        self.assertEqual(table.independent_sources_count, 2)
        self.assertEqual(table.confidence_boost, 0.08)
        self.assertTrue(table.allow_automatic_approval)

    def test_single_source_quarantine(self):
        # Termo existente em apenas uma única fonte: quarentena obrigatória, zero boost
        table = self.validator.validate_token_consensus("solitaria_raro")
        self.assertEqual(table.consensus_status, "fonte_unica_quarentena")
        self.assertEqual(table.independent_sources_count, 1)
        self.assertEqual(table.confidence_boost, 0.0)
        self.assertFalse(table.allow_automatic_approval)

    def test_no_source_rejected(self):
        table = self.validator.validate_token_consensus("palavra_inexistente_xyz")
        self.assertEqual(table.consensus_status, "sem_evidencia_documental")
        self.assertEqual(table.independent_sources_count, 0)
        self.assertEqual(table.confidence_boost, 0.0)
        self.assertFalse(table.allow_automatic_approval)


if __name__ == "__main__":
    unittest.main()
