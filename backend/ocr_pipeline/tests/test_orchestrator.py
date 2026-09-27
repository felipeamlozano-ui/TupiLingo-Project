"""
Teste de Integração do Orquestrador Master Forense v3.0 (Etapa 13).
Valida o fluxo completo de ponta a ponta com imagem sintética histórica.
"""

from pathlib import Path

import cv2
import numpy as np
import pytest

from ocr_pipeline.core.config import ForensePipelineConfig
from ocr_pipeline.core.orchestrator import ForensicPipelineOrchestrator


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


def test_orchestrator_end_to_end(custom_config):
    orchestrator = ForensicPipelineOrchestrator(custom_config)

    # 1. Gerar imagem sintética emulando página antiga com texto Tupi
    img = np.full((600, 800, 3), (230, 240, 245), dtype=np.uint8)  # Tom amarelado
    # Adicionar texto nítido
    cv2.putText(
        img,
        "Dicionario da Lingua Tupi",
        (50, 80),
        cv2.FONT_HERSHEY_SIMPLEX,
        1.0,
        (20, 20, 20),
        2,
    )
    cv2.putText(
        img,
        "No tomo III o padre citou a oka e o tatu.",
        (50, 160),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.8,
        (20, 20, 20),
        2,
    )

    # 2. Executar processamento forense
    summary = orchestrator.process_page(
        image_rgb=img,
        page_num=1,
        filename="sintetico_teste.pdf",
        force_reprocess=True,
    )

    # 3. Validações
    assert summary.page_num == 1
    assert summary.tokens_count > 0
    assert summary.export_bundle is not None
    assert summary.export_bundle.markdown_path is not None
    assert Path(summary.export_bundle.markdown_path).exists()
    assert Path(summary.export_bundle.alto_xml_path).exists()
    assert Path(summary.export_bundle.page_xml_path).exists()

    # 4. Validar Checkpoint (reexecução deve retornar instantaneamente)
    summary_cached = orchestrator.process_page(
        image_rgb=img,
        page_num=1,
        filename="sintetico_teste.pdf",
        force_reprocess=False,
    )
    assert summary_cached.duration_seconds == 0.0
