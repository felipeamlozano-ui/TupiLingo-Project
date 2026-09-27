"""
Testes Unitários do Diagnóstico Forense de PDFs (Capítulo 3 do RFC v5).
Valida extração de IQA, LAB, orientação e poda de branches.
"""
import tempfile
from pathlib import Path
import numpy as np
from PIL import Image

from ocr_pipeline.diagnostic_engine.forensic_analyzer import (
    ForensicDiagnosticEngine,
    PageProfile,
)


def test_forensic_diagnostic_profile_generation():
    engine = ForensicDiagnosticEngine()
    
    # Criar imagem sintética representativa (texto com amarelamento e ruído)
    img_arr = np.ones((800, 600, 3), dtype=np.uint8) * 240
    # Adicionar canal b* amarelado
    img_arr[:, :, 0] = 200 # B
    img_arr[:, :, 1] = 230 # G
    img_arr[:, :, 2] = 250 # R
    
    # Desenhar linhas simulando texto escuro
    img_arr[100:110, 50:550] = 30
    img_arr[150:160, 50:550] = 30
    img_arr[200:210, 50:550] = 30

    pil_img = Image.fromarray(img_arr)
    profile = engine.analyze_image(pil_img, page_num=1)

    assert isinstance(profile, PageProfile)
    assert profile.page == 1
    assert profile.dimensions == (600, 800)
    assert profile.contrast_rms > 0
    assert profile.stroke_width_median > 0
    assert len(profile.recommended_branches) > 0
    assert "clahe" in profile.recommended_branches

    # Testar salvamento em JSON
    with tempfile.TemporaryDirectory() as tmp_dir:
        json_path = Path(tmp_dir) / "page_profile.json"
        profile.save_json(json_path)
        assert json_path.exists()
        import json
        with open(json_path, "r", encoding="utf-8") as f:
            data = json.load(f)
            assert data["page"] == 1
            assert "recommended_branches" in data
            assert "orientation_degrees" in data


def test_orientation_detection_upside_down():
    engine = ForensicDiagnosticEngine()
    
    # Imagem com texto concentrado exclusivamente no rodapé (simulando 180°)
    img_arr = np.ones((800, 600), dtype=np.uint8) * 255
    img_arr[650:750, 50:550] = 20 # Texto no rodapé
    
    pil_img = Image.fromarray(img_arr)
    profile = engine.analyze_image(pil_img, page_num=11)
    
    assert profile.needs_rotation_180 is True
    assert profile.orientation_degrees == 180
