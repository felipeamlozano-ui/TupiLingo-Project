"""
Testes Unitários do Módulo de Artifact Bundle Arquivístico Distribuído (Capítulo 1 do RFC v5).
"""
import json
import uuid
import tempfile
from pathlib import Path
import pytest
import pyarrow as pa

from ocr_pipeline.export_engine.artifact_bundle import (
    ArtifactBundleBuilder,
    ArtifactBundleReader,
    compute_file_sha256,
)


def test_artifact_bundle_creation_and_reading():
    with tempfile.TemporaryDirectory() as tmp_dir:
        base_dir = Path(tmp_dir)
        builder = ArtifactBundleBuilder(
            output_base_dir=base_dir,
            pipeline_version="5.0.0",
        )

        chunk_id = str(uuid.uuid4())
        builder.add_chunk(
            chunk_id=chunk_id,
            pdf_source="Dicionário Tupi.pdf",
            page=11,
            text_final="Abreviaturas utilizadas no dicionário.",
            confidence_final=88.5,
            rollback_applied=False,
            rag_provenance_ids=["rag_chunk_001", "rag_chunk_002"],
            needs_review=False,
            engine_versions={"tesseract": "5.3.0", "rapidocr": "1.4.4"},
            confidence_components={
                "c_ocr": 89.0,
                "c_vis": 88.0,
                "c_lex": 90.0,
                "c_rag": 87.0,
                "weighted_ocr": 40.05,
                "weighted_vis": 17.6,
                "weighted_lex": 18.0,
                "weighted_rag": 13.05,
                "fused_raw": 88.7,
                "floor_trap_applied": False,
            },
        )

        builder.add_audit_log({
            "chunk_id": chunk_id,
            "type": "correction_evaluated",
            "candidate": "eossad->nossa",
            "accepted": False,
            "reason": "inverted_page_noise",
        })

        bundle_dir = builder.build()
        assert bundle_dir.exists()
        assert (bundle_dir / "manifest.json").exists()
        assert (bundle_dir / "chunks.parquet").exists()
        assert (bundle_dir / "confidence_components.parquet").exists()
        assert (bundle_dir / "audit_log.jsonl").exists()
        assert (bundle_dir / "checksums.sha256").exists()

        # Leitura e verificação de integridade
        reader = ArtifactBundleReader(bundle_dir)
        is_integro, errors = reader.verify_integrity()
        assert is_integro, f"Integridade falhou: {errors}"
        assert len(errors) == 0

        # Validar Manifest
        manifest = reader.load_manifest()
        assert manifest["pipeline_version"] == "5.0.0"
        assert manifest["total_chunks"] == 1
        assert manifest["total_pages"] == 1
        assert manifest["total_pdfs"] == 1
        assert "git_commit" in manifest

        # Validar Chunks Parquet
        chunks_table = reader.load_chunks()
        assert isinstance(chunks_table, pa.Table)
        assert chunks_table.num_rows == 1
        row = chunks_table.to_pylist()[0]
        assert row["chunk_id"] == chunk_id
        assert row["pdf_source"] == "Dicionário Tupi.pdf"
        assert row["page"] == 11
        assert row["confidence_final"] == pytest.approx(88.5, rel=1e-2)
        assert row["rag_provenance_ids"] == ["rag_chunk_001", "rag_chunk_002"]

        # Validar Decomposição de Confiança Parquet (Capítulo 0 item 1 resolvido permanentemente)
        conf_table = reader.load_confidence_components()
        assert conf_table.num_rows == 1
        conf_row = conf_table.to_pylist()[0]
        assert conf_row["chunk_id"] == chunk_id
        assert conf_row["c_ocr"] == pytest.approx(89.0, rel=1e-2)
        assert conf_row["weighted_ocr"] == pytest.approx(40.05, rel=1e-2)

        # Validar Audit Log
        audit_entries = reader.load_audit_log()
        assert len(audit_entries) == 1
        assert audit_entries[0]["candidate"] == "eossad->nossa"


def test_artifact_bundle_corruption_detection():
    with tempfile.TemporaryDirectory() as tmp_dir:
        base_dir = Path(tmp_dir)
        builder = ArtifactBundleBuilder(output_base_dir=base_dir)
        builder.add_chunk(
            chunk_id=str(uuid.uuid4()),
            pdf_source="Ayrosa_1943.pdf",
            page=1,
            text_final="Texto",
            confidence_final=70.0,
            rollback_applied=False,
            rag_provenance_ids=[],
            needs_review=True,
            engine_versions={},
        )
        bundle_dir = builder.build()

        # Simular corrupção de transferência de arquivo
        chunks_path = bundle_dir / "chunks.parquet"
        with open(chunks_path, "ab") as f:
            f.write(b"CORRUPTED_BYTES")

        reader = ArtifactBundleReader(bundle_dir)
        is_integro, errors = reader.verify_integrity()
        assert not is_integro
        assert any("chunks.parquet" in e for e in errors)
