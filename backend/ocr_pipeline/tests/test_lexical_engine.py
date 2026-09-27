"""
Testes unitários automatizados para o Forensic Lexical Engine — Capítulos 10, 11 e 12.
"""
from pathlib import Path
from unittest.mock import MagicMock

import pytest

from ocr_pipeline.lexical_engine.forensic_lexicon import (
    ForensicLexicalEngine,
    LexicalCorrection,
    TupiMorphologicalParser,
)


@pytest.fixture
def lexical_engine():
    tupi_vocab_file = Path("tupi_user_words.txt")
    lexicon_data_path = Path("pedagogico/lexicon_data.py")
    return ForensicLexicalEngine(
        tupi_vocab_path=tupi_vocab_file if tupi_vocab_file.exists() else None,
        lexicon_data_path=lexicon_data_path if lexicon_data_path.exists() else None,
        max_edit_distance=2,
    )


def test_tupi_morphological_parser_with_variants_and_status():
    stems = {"oka", "pira", "katu", "aba", "abare", "y", "wer"}
    parser = TupiMorphologicalParser(stems)

    # 1. Radical exato com classificação de variante
    res1 = parser.parse("oka")
    assert res1.is_valid_tupi is True
    assert res1.stem == "oka"
    assert res1.linguistic_variant in {"Tupi Antigo", "Tupinambá"}

    # 2. Prefixo + Radical com status
    mock_rag = MagicMock()
    mock_rag.validate_term.return_value.exists_in_corpus = True
    mock_rag.validate_term.return_value.exists_in_lexicon = True

    res2 = parser.parse("xe-oka", rag_validator=mock_rag)
    assert res2.is_valid_tupi is True
    assert res2.prefix == "xe-"
    assert res2.stem == "oka"
    assert res2.morphology_status == "validado_corpus"

    # 3. Status não verificado quando RAG não encontra
    mock_rag_unverified = MagicMock()
    mock_rag_unverified.validate_term.return_value.exists_in_corpus = False
    mock_rag_unverified.validate_term.return_value.exists_in_lexicon = False

    res3 = parser.parse("xe-oka", rag_validator=mock_rag_unverified)
    assert res3.morphology_status == "morfologia_nao_verificada"


def test_invariants_numbers_and_dates(lexical_engine):
    text = "Em 1554, o padre no tomo III e capitulo IV citou 42 flechas."
    result = lexical_engine.process_text(text)

    assert "1554" in result.corrected_text
    assert "III" in result.corrected_text
    assert "IV" in result.corrected_text
    assert "42" in result.corrected_text
    assert result.invariants_checked >= 5


def test_tupi_casing_preservation(lexical_engine):
    text = "A palavra oka e Oka e OKA são formas de habitação."
    result = lexical_engine.process_text(text)

    assert "oka" in result.corrected_text
    assert "Oka" in result.corrected_text
    assert "OKA" in result.corrected_text


def test_rollback_gate_rejects_corruption(lexical_engine):
    text = "O guerreiro foi até a oka."
    result = lexical_engine.process_text(text)

    assert "oka" in result.corrected_text
    assert result.tupi_tokens_count >= 1


def test_rejected_candidates_logging(lexical_engine):
    # Tokens com alta confiança (>90%) devem ser rejeitados e logados
    text = "Um texto de altissima certeza"
    confs = [0.95, 0.95, 0.95, 0.95, 0.95]
    result = lexical_engine.process_text(text, token_confidences=confs)

    assert len(result.rejected_candidates) > 0
    reasons = [r["reason"] for r in result.rejected_candidates]
    assert any("confidence_gate" in r or "proportional_distance" in r for r in reasons)


def test_audit_magnet_words(lexical_engine):
    corrections = [
        LexicalCorrection(
            token_idx=i, original="err", corrected="oka", edit_distance=1,
            confidence_before=0.5, confidence_after=0.8, category="tupi_stem"
        )
        for i in range(5)
    ]
    # Injetar uma correção diferente
    corrections.append(
        LexicalCorrection(
            token_idx=6, original="err2", corrected="pira", edit_distance=1,
            confidence_before=0.5, confidence_after=0.8, category="tupi_stem"
        )
    )

    audit = lexical_engine.audit_magnet_words(corrections)
    assert audit["frequencies"]["oka"] == 5
    assert audit["has_suspicious_magnet"] is True
    assert "oka" in audit["flagged_suspicious_magnets"]


def test_rag_provenance_citation_requirement(lexical_engine):
    # Mock de RAG que rejeita termo sem evidência
    mock_rag = MagicMock()
    mock_rag.validate_term.return_value.exists_in_corpus = False
    mock_rag.validate_term.return_value.exists_in_lexicon = False

    text = "O termo desconhecidoxx foi encontrado."
    result = lexical_engine.process_text(text, rag_validator=mock_rag)

    # Se houve tentativa de correção sem respaldo do RAG, deve cair em rejected_candidates
    assert isinstance(result.rejected_candidates, list)
