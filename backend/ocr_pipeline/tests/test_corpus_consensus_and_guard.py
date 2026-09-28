import gc
import shutil
import tempfile
from pathlib import Path
import pytest

from ocr_pipeline.rag_validation_engine.corpus_inverted_index import CorpusInvertedIndex
from ocr_pipeline.lexical_engine.never_hallucinate_guard import NeverHallucinateGuard


@pytest.fixture
def temp_cache():
    t_dir = tempfile.mkdtemp(prefix="test_corpus_guard_")
    cache_path = Path(t_dir)
    yield cache_path
    gc.collect()
    shutil.rmtree(t_dir, ignore_errors=True)


def test_corpus_inverted_index(temp_cache):
    index = CorpusInvertedIndex(cache_dir=temp_cache)
    occs = index.lookup("oka")
    assert len(occs) >= 3

    score = index.compute_consensus_score("oka")
    assert score["independent_sources_count"] >= 3
    assert score["consensus_status"] == "CONSENSO_MULTIFONTE"
    assert score["confidence_boost"] == 0.15
    assert score["allow_automatic_approval"] is True

    # Palavra sem evidência
    score_unknown = index.compute_consensus_score("inexistente_xyz")
    assert score_unknown["independent_sources_count"] == 0
    assert score_unknown["consensus_status"] == "SEM_EVIDENCIA_DOCUMENTAL"
    assert score_unknown["allow_automatic_approval"] is False


def test_never_hallucinate_guard_protects_invariants():
    guard = NeverHallucinateGuard()

    # 1. Proteger anos e datas
    d1 = guard.evaluate_token("1645", proposed_correction="1646")
    assert d1.is_protected_invariant is True
    assert d1.invariant_type == "DATE"
    assert d1.cleaned_token == "1645"

    # 2. Proteger números romanos
    d2 = guard.evaluate_token("XIV", proposed_correction="X")
    assert d2.is_protected_invariant is True
    assert d2.invariant_type == "ROMAN"
    assert d2.cleaned_token == "XIV"

    # 3. Proteger etnônimos e nomes próprios
    d3 = guard.evaluate_token("potiguara", proposed_correction="portugues")
    assert d3.is_protected_invariant is True
    assert d3.invariant_type == "ETHNONYM"
    assert d3.cleaned_token == "potiguara"

    d4 = guard.evaluate_token("Anchieta", proposed_correction="Antonieta")
    assert d4.is_protected_invariant is True
    assert d4.invariant_type == "PROPER_NAME"
    assert d4.cleaned_token == "Anchieta"

    # 4. Marcar UNCERTAIN para tokens com baixa confiança
    d5 = guard.evaluate_token("xwyz", confidence=0.45)
    assert d5.is_uncertain is True
    assert d5.allowed_for_pedagogical_db is False
    assert len(guard.uncertain_queue) > 0

    # 5. Filtro pedagógico estrito rejeita UNCERTAIN
    filtered = guard.filter_pedagogical_export([d1, d2, d3, d4, d5])
    assert len(filtered) == 4
    assert d5 not in filtered
