"""
Testes unitários para o Motor de Benchmarking Forense v3.0 (Etapa 14).
"""

import cv2
import numpy as np
import pytest

from ocr_pipeline.benchmarking.benchmark_v3 import (
    BenchmarkComparisonReport,
    ForensicBenchmarkEngine,
)
from ocr_pipeline.core.config import ForensePipelineConfig


@pytest.fixture
def custom_config(tmp_path):
    cfg = ForensePipelineConfig()
    cfg.cache_dir = tmp_path / "cache"
    cfg.checkpoints_dir = tmp_path / "checkpoints"
    cfg.exports_dir = tmp_path / "exports"
    cfg.cache_dir.mkdir(parents=True, exist_ok=True)
    cfg.checkpoints_dir.mkdir(parents=True, exist_ok=True)
    cfg.exports_dir.mkdir(parents=True, exist_ok=True)
    return cfg


def test_benchmark_engine_execution(custom_config, tmp_path):
    engine = ForensicBenchmarkEngine(custom_config)

    # Criar 1 imagem de teste sintética
    img = np.full((500, 700, 3), (235, 240, 245), dtype=np.uint8)
    cv2.putText(
        img,
        "Vocabulario da Lingua Tupi",
        (40, 70),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.9,
        (10, 10, 10),
        2,
    )
    cv2.putText(
        img,
        "A palavra oka significa habitacao.",
        (40, 130),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.8,
        (10, 10, 10),
        2,
    )

    out_json = tmp_path / "benchmark_comparison.json"
    report = engine.execute_benchmark(
        test_images=[img],
        filenames=["teste_bench.pdf"],
        output_json_path=out_json,
    )

    assert isinstance(report, BenchmarkComparisonReport)
    assert report.forense_v3.total_pages == 1
    assert report.baseline_legacy.total_pages == 1
    assert report.memory_stability_status == "ESTÁVEL (< 1500 MB)"
    assert out_json.exists()
    assert out_json.stat().st_size > 0
