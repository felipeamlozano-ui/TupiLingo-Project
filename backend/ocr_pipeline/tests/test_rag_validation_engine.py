"""
Testes unitários para o Validador RAG Zero Alucinação (Etapa 9).
"""

from pathlib import Path

import pytest

from ocr_pipeline.rag_validation_engine.rag_validator import RAGValidator


@pytest.fixture
def rag_validator():
    db_path = Path("vector_store.db")
    lex_path = Path("pedagogico/lexicon_data.py")
    return RAGValidator(vector_store_path=db_path, lexicon_data_path=lex_path)


def test_rag_validates_known_corpus_term(rag_validator):
    # Termo autêntico que existe no acervo
    res = rag_validator.validate_term("oka")
    assert res.exists_in_corpus is True or res.exists_in_lexicon is True
    assert res.is_hallucination is False
    assert res.rag_confidence_score >= 0.85
    assert len(res.evidence_samples) > 0 or res.exists_in_lexicon is True


def test_rag_rejects_hallucinated_gibberish(rag_validator):
    # Palavra inexistente no corpus e no dicionário
    bogus = "xkcdqwerty999z"
    res = rag_validator.validate_term(bogus)
    assert res.exists_in_corpus is False
    assert res.exists_in_lexicon is False
    assert res.is_hallucination is True
    assert res.verdict == "rejected_hallucination"
    assert res.rag_confidence_score <= 0.20


def test_rag_batch_validation_preserves_tokens(rag_validator):
    tokens = ["Em", "1554", "o", "tatu", "andava", "pela", "mata"]
    results = rag_validator.validate_page_tokens(tokens)
    assert len(results) == len(tokens)
