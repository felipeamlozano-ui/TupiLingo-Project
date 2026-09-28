import gc
import shutil
import tempfile
from pathlib import Path
import pyarrow.parquet as pq
import pytest

from ocr_pipeline.export_engine.research_report_generator import ResearchReportGenerator


@pytest.fixture
def temp_report_env():
    temp_dir = tempfile.mkdtemp(prefix="test_research_rep_")
    cache_dir = Path(temp_dir) / "ocr_cache"
    output_dir = Path(temp_dir) / "reports"
    cache_dir.mkdir(parents=True)
    output_dir.mkdir(parents=True)

    yield {"cache_dir": cache_dir, "output_dir": output_dir, "temp_dir": temp_dir}

    gc.collect()
    shutil.rmtree(temp_dir, ignore_errors=True)


def test_research_report_generator_all_artifacts(temp_report_env):
    cache_dir = temp_report_env["cache_dir"]
    output_dir = temp_report_env["output_dir"]

    generator = ResearchReportGenerator(cache_dir=cache_dir, output_dir=output_dir)
    reports = generator.generate_all_reports()

    # 1. Verifica se todos os 6 artefatos foram retornados e existem
    expected_files = [
        "RELATORIO_CIENTIFICO.md",
        "ARTIGO_RESULTADOS.md",
        "METRICAS_DETALHADAS.parquet",
        "dashboard.html",
        "comparativo_v5_vs_v6.html",
        "ground_truth_report.html",
    ]
    for ef in expected_files:
        assert ef in reports
        assert reports[ef].exists()
        assert reports[ef].stat().st_size > 0

    # 2. Inspeciona o Parquet com PyArrow
    parquet_path = reports["METRICAS_DETALHADAS.parquet"]
    table = pq.read_table(parquet_path)
    assert table.num_rows > 0
    column_names = table.column_names
    assert "cer" in column_names
    assert "wer" in column_names
    assert "bbox_iou" in column_names
    assert "category" in column_names
    assert "confidence_mean" in column_names

    # 3. Inspeciona o Relatório Científico Markdown
    relatorio_txt = reports["RELATORIO_CIENTIFICO.md"].read_text(encoding="utf-8")
    assert "Relatório Científico de Validação e Desempenho" in relatorio_txt
    assert "CER Médio v6" in relatorio_txt
    assert "RTX 5060" in relatorio_txt

    # 4. Inspeciona o Artigo de Resultados
    artigo_txt = reports["ARTIGO_RESULTADOS.md"].read_text(encoding="utf-8")
    assert "Reconstituição e OCR Científico de Textos Coloniais" in artigo_txt
    assert "Resumo (Abstract)" in artigo_txt
    assert "Weighted Box Fusion" in artigo_txt

    # 5. Inspeciona o Comparativo HTML
    comparativo_html = reports["comparativo_v5_vs_v6.html"].read_text(encoding="utf-8")
    assert "RFC v5 vs RFC v6" in comparativo_html
    assert "50.0% Redução de Erro" in comparativo_html

    # 6. Inspeciona o Ground Truth Report HTML
    gt_html = reports["ground_truth_report.html"].read_text(encoding="utf-8")
    assert "Corpus de Ground Truth Científico" in gt_html
