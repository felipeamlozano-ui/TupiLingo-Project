"""
Testes unitários para o Forensic Lexical Engine (Etapa 8).
Valida:
- Invariantes de números e numerais romanos
- Preservação estrita de caixa tipográfica original (Regra 1.4)
- Decomposição morfológica Tupi (prefixos e sufixos)
- Rollback Gate e salvaguarda contra aportuguesamento indevido
"""

from pathlib import Path

import pytest

from ocr_pipeline.lexical_engine.forensic_lexicon import (
    ForensicLexicalEngine,
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


def test_tupi_morphological_parser():
    stems = {"oka", "pira", "katu", "aba", "abare", "y"}
    parser = TupiMorphologicalParser(stems)

    # 1. Radical exato
    res1 = parser.parse("oka")
    assert res1.is_valid_tupi is True
    assert res1.stem == "oka"

    # 2. Prefixo + Radical
    res2 = parser.parse("xe-oka")
    assert res2.is_valid_tupi is True
    assert res2.prefix == "xe-"
    assert res2.stem == "oka"

    # 3. Radical + Sufixo
    res3 = parser.parse("pira-katu")
    assert res3.is_valid_tupi is True

    # 4. Palavra não tupi
    res4 = parser.parse("computador")
    assert res4.is_valid_tupi is False


def test_invariants_numbers_and_dates(lexical_engine):
    # Números, datas e numerais romanos devem permanecer 100% inalterados
    text = "Em 1554, o padre no tomo III e capitulo IV citou 42 flechas."
    result = lexical_engine.process_text(text)

    assert "1554" in result.corrected_text
    assert "III" in result.corrected_text
    assert "IV" in result.corrected_text
    assert "42" in result.corrected_text
    assert result.invariants_checked >= 5


def test_tupi_casing_preservation(lexical_engine):
    # Regra 1.4: minúsculas permanecem minúsculas, maiúsculas maiúsculas
    text = "A palavra oka e Oka e OKA são formas de habitação."
    result = lexical_engine.process_text(text)

    assert "oka" in result.corrected_text
    assert "Oka" in result.corrected_text
    assert "OKA" in result.corrected_text


def test_rollback_gate_rejects_corruption(lexical_engine):
    # Uma palavra Tupi autêntica nunca deve ser transformada em palavra portuguesa
    text = "O guerreiro foi até a oka."
    result = lexical_engine.process_text(text)

    # oka não pode virar oca ou ora ou outra palavra
    assert "oka" in result.corrected_text
    assert result.tupi_tokens_count >= 1
