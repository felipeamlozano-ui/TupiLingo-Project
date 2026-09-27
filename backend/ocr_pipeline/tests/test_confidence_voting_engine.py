"""
Testes unitários para Votação de Tokens e Fusão de Confiança — Capítulos 8 e 9.
"""
from PIL import Image

from ocr_pipeline.confidence_engine.confidence_fusion import (
    ForensicConfidenceFusionEngine,
)
from ocr_pipeline.confidence_engine.token_voting import ForensicTokenVotingEngine
from ocr_pipeline.core.provenance import BoundingBox


def test_needleman_wunsch_alignment():
    engine = ForensicTokenVotingEngine()
    s1 = "tupinamba"
    s2 = "tupinambá"

    a1, a2, score = engine.needleman_wunsch_align(s1, s2)
    assert len(a1) == len(a2)
    assert score > 0


def test_smith_waterman_local_alignment():
    engine = ForensicTokenVotingEngine()
    corrupted = "xxmorubixabayy"
    target = "morubixaba"

    a1, a2, score = engine.smith_waterman_align(corrupted, target)
    assert len(a1) == len(a2)
    assert score > 0
    assert "morubixaba" in a1 or "morubixaba" in a2


def test_beam_search_consensus():
    engine = ForensicTokenVotingEngine()
    candidates = [
        "tupinamba",
        "tupinambá",
        "tupinamba.",
    ]
    weights = [1.4, 1.0, 0.9]
    consensus, score = engine.beam_search_consensus(candidates, weights, beam_width=4)
    assert "tupinamb" in consensus
    assert score > 50.0


def test_levenshtein_distance():
    engine = ForensicTokenVotingEngine()
    assert engine.levenshtein_distance("oka", "oca") == 1
    assert engine.levenshtein_distance("tuba", "tuba") == 0
    assert engine.levenshtein_distance("tupinamba", "tupiniquim") > 3


def test_voting_engine_diacritic_preservation():
    engine = ForensicTokenVotingEngine()
    candidates = [
        {"text": "tupinamba", "confidence": 0.88, "engine": "rapidocr_gpu"},
        {"text": "tupinambá", "confidence": 0.87, "engine": "tesseract_psm6"},
    ]
    winner_text, winner_conf, _winner_eng, agree = engine.vote_on_candidates(candidates)
    assert winner_text in {"tupinamba", "tupinambá"}
    assert winner_conf > 0.80
    assert agree > 50.0


def test_confidence_fusion_structural_floor_trap():
    fusion = ForensicConfidenceFusionEngine(min_ocr_threshold=50.0)

    # Caso Ayrosa p.1: Texto de saída idêntico ao de entrada (zero correções)
    raw_text = "eossad sono Waye"
    final_text = "eossad sono Waye"

    decomp = fusion.decompose_and_fuse(
        ocr_conf=34.73,
        visual_conf=75.0,
        lexical_conf=75.0,
        rag_conf=90.0,
        consensus_conf=80.0,
        raw_text=raw_text,
        final_text=final_text,
    )

    # 1. Floor trap acionada
    assert decomp.floor_trap_triggered is True
    assert decomp.lexical_conf == 0.0
    assert decomp.rag_conf == 0.0

    # 2. Gate de revisão humana: c_ocr < 50% obriga needs_review = True
    assert decomp.needs_review is True
    assert "ocr_conf" in decomp.review_reason


def test_confidence_fusion_with_real_corrections():
    fusion = ForensicConfidenceFusionEngine(min_ocr_threshold=50.0)

    raw_text = "eossad sono Waye"
    final_text = "nossa so'o Paye"  # 100% modificado/corrigido

    decomp = fusion.decompose_and_fuse(
        ocr_conf=65.0,
        visual_conf=80.0,
        lexical_conf=90.0,
        rag_conf=85.0,
        consensus_conf=95.0,
        raw_text=raw_text,
        final_text=final_text,
        min_char_count=10,
    )

    # Floor trap NÃO deve ser acionada pois houve correções reais
    assert decomp.floor_trap_triggered is False
    assert decomp.lexical_conf == 90.0
    assert decomp.rag_conf == 85.0
    assert decomp.needs_review is False
    assert decomp.fused_confidence > 75.0


def test_confidence_heatmap_generation():
    fusion = ForensicConfidenceFusionEngine()
    base_img = Image.new("RGB", (300, 200), color=(240, 240, 240))
    tokens = [
        {"bbox": BoundingBox(x1=20, y1=20, x2=80, y2=50), "confidence": 92.0},
        {"bbox": BoundingBox(x1=90, y1=20, x2=150, y2=50), "confidence": 75.0},
        {"bbox": BoundingBox(x1=160, y1=20, x2=220, y2=50), "confidence": 60.0},
    ]
    heatmap = fusion.generate_confidence_heatmap(base_img, tokens)
    assert heatmap.size == (300, 200)
    assert heatmap.mode == "RGB"
