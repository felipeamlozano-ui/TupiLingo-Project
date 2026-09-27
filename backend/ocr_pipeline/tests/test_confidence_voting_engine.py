"""
Testes unitários para os Motores de Votação por Token e Fusão de Confiança (Etapas 6 e 7).
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


def test_levenshtein_distance():
    engine = ForensicTokenVotingEngine()
    assert engine.levenshtein_distance("oka", "oca") == 1
    assert engine.levenshtein_distance("tuba", "tuba") == 0
    assert engine.levenshtein_distance("tupinamba", "tupiniquim") > 3


def test_voting_engine_diacritic_preservation():
    engine = ForensicTokenVotingEngine()
    candidates = [
        {"text": "tupinamba", "confidence": 0.88, "engine": "rapidocr"},
        {"text": "tupinambá", "confidence": 0.87, "engine": "tesseract"},
    ]
    winner_text, winner_conf, _winner_eng, agree = engine.vote_on_candidates(candidates)
    assert winner_text in {"tupinamba", "tupinambá"}
    assert winner_conf > 0.80
    assert agree > 50.0


def test_confidence_fusion_calculation():
    fusion = ForensicConfidenceFusionEngine(
        w_ocr=0.45, w_vis=0.20, w_lex=0.20, w_rag=0.15
    )
    # Valores de 0 a 100
    fused = fusion.fuse_confidence(
        ocr_conf=90.0,
        visual_conf=80.0,
        lexical_conf=95.0,
        rag_conf=85.0,
    )
    # 0.45*90 (40.5) + 0.20*80 (16.0) + 0.20*95 (19.0) + 0.15*85 (12.75) = 88.25
    assert fused == 88.25


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
