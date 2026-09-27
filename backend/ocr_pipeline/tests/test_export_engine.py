"""
Testes unitários para o Motor de Exportação Forense Multi-Formato (Etapa 12).
"""

import xml.etree.ElementTree as ET
from pathlib import Path

import pytest

from ocr_pipeline.core.provenance import BoundingBox, TokenProvenance
from ocr_pipeline.export_engine.multi_exporter import ForensicMultiExporter


@pytest.fixture
def sample_tokens():
    return [
        TokenProvenance(
            raw_text="Xe",
            cleaned_text="Xe",
            confidence_raw=0.95,
            confidence_fused=0.96,
            bbox=BoundingBox(x1=10, y1=10, x2=40, y2=30),
            engine_origin="rapidocr",
            preprocessing_branch="clahe",
            dpi=300,
        ),
        TokenProvenance(
            raw_text="oka",
            cleaned_text="oka",
            confidence_raw=0.97,
            confidence_fused=0.98,
            bbox=BoundingBox(x1=50, y1=10, x2=90, y2=30),
            engine_origin="tesseract",
            preprocessing_branch="sauvola",
            dpi=300,
        ),
        TokenProvenance(
            raw_text="porang",
            cleaned_text="porang",
            confidence_raw=0.75,
            confidence_fused=0.78,
            bbox=BoundingBox(x1=100, y1=10, x2=160, y2=30),
            engine_origin="rapidocr",
            preprocessing_branch="clahe",
            dpi=300,
        ),
    ]


def test_forensic_multi_exporter_all_formats(tmp_path, sample_tokens):
    exporter = ForensicMultiExporter(tmp_path)
    bundle = exporter.export_all(
        page_num=42,
        transcription_text="Xe oka porang",
        tokens=sample_tokens,
        diagnostic_meta={"blur_score": 0.85, "yellow_paper": True},
    )

    # 1. Checar se todos os caminhos foram gerados e existem
    for path_str in [
        bundle.txt_path,
        bundle.markdown_path,
        bundle.json_path,
        bundle.jsonl_path,
        bundle.csv_path,
        bundle.alto_xml_path,
        bundle.page_xml_path,
        bundle.annotated_html_path,
    ]:
        assert path_str is not None
        p = Path(path_str)
        assert p.exists()
        assert p.stat().st_size > 0

    # 2. Validar que o ALTO XML é um XML válido com schema da LOC
    alto_tree = ET.parse(bundle.alto_xml_path)
    root = alto_tree.getroot()
    assert "alto" in root.tag

    # 3. Validar que o PAGE XML é bem-formado
    page_tree = ET.parse(bundle.page_xml_path)
    root_page = page_tree.getroot()
    assert "PcGts" in root_page.tag

    # 4. Validar frontmatter no Markdown
    md_content = Path(bundle.markdown_path).read_text(encoding="utf-8")
    assert "page: 42" in md_content
    assert "Xe oka porang" in md_content
