import gc
import json
import shutil
import tempfile
from pathlib import Path
import pytest

from ocr_pipeline.core.dataset_versioning import (
    DatasetVersionManager,
    PDFDatasetManifest,
    DatasetVersionSnapshot,
)


@pytest.fixture
def temp_env():
    temp_dir = tempfile.mkdtemp(prefix="test_dataset_ver_")
    cache_dir = Path(temp_dir) / "cache"
    pdf_dir = Path(temp_dir) / "pdfs"
    cache_dir.mkdir(parents=True)
    pdf_dir.mkdir(parents=True)

    # Cria PDFs dummy
    pdf1 = pdf_dir / "Barbosa_1956_CursoDeTupiAntigo.pdf"
    pdf1.write_bytes(b"%PDF-1.4\n1 0 obj\n<< /Title (Curso de Tupi) >>\nendobj\ntrailer\n<< >>\n%%EOF")

    pdf2 = pdf_dir / "Carta_1645_Camarao.pdf"
    pdf2.write_bytes(b"%PDF-1.4\n1 0 obj\n<< /Title (Carta 1645) >>\nendobj\ntrailer\n<< >>\n%%EOF")

    yield {"cache_dir": cache_dir, "pdf_dir": pdf_dir, "temp_dir": temp_dir}

    gc.collect()
    shutil.rmtree(temp_dir, ignore_errors=True)


def test_dataset_scan_and_manifest(temp_env):
    cache_dir = temp_env["cache_dir"]
    pdf_dir = temp_env["pdf_dir"]

    manager = DatasetVersionManager(cache_dir=cache_dir)
    manifests = manager.scan_dataset(pdf_dir)

    assert len(manifests) == 2
    assert "Barbosa_1956_CursoDeTupiAntigo.pdf" in manifests
    assert "Carta_1645_Camarao.pdf" in manifests

    barbosa = manifests["Barbosa_1956_CursoDeTupiAntigo.pdf"]
    assert barbosa.year == 1956
    assert barbosa.linguistic_variant == "tupi_antigo"
    assert "Barbosa" in barbosa.source
    assert len(barbosa.sha256) == 64

    carta = manifests["Carta_1645_Camarao.pdf"]
    assert carta.year == 1645
    assert "1645" in carta.source or "Carta" in carta.file_name


def test_drift_detection_and_version_history(temp_env):
    cache_dir = temp_env["cache_dir"]
    pdf_dir = temp_env["pdf_dir"]

    manager = DatasetVersionManager(cache_dir=cache_dir)
    manager.scan_dataset(pdf_dir)

    # Sem alterações: drift = False
    drift = manager.detect_dataset_drift(pdf_dir)
    assert not drift["drift_detected"]
    assert len(drift["verified"]) == 2

    # Registra versão v1.0.0
    snap = manager.record_version("v1.0.0", notes="Versão inicial de teste", pdf_dir=pdf_dir)
    assert snap.version_tag == "v1.0.0"
    assert snap.total_files == 2

    history = manager.get_version_history()
    assert len(history) == 1
    assert history[0]["version_tag"] == "v1.0.0"

    # Adiciona um novo arquivo
    pdf3 = pdf_dir / "Cascudo_1988_Folclore.pdf"
    pdf3.write_bytes(b"%PDF-1.4 Cascudo test data")

    drift_after_add = manager.detect_dataset_drift(pdf_dir)
    assert drift_after_add["drift_detected"]
    assert "Cascudo_1988_Folclore.pdf" in drift_after_add["added"]

    # Modifica um arquivo existente
    pdf1 = pdf_dir / "Barbosa_1956_CursoDeTupiAntigo.pdf"
    pdf1.write_bytes(b"%PDF-1.4 MODIFIED DATA")

    drift_after_mod = manager.detect_dataset_drift(pdf_dir)
    assert drift_after_mod["drift_detected"]
    assert any(m["file_name"] == "Barbosa_1956_CursoDeTupiAntigo.pdf" for m in drift_after_mod["modified"])
