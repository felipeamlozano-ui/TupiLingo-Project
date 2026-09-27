"""
Módulo de Artifact Bundle Arquivístico Distribuído — TupiLingo OCR v5 (Capítulo 1).
Gera e valida bundles autocontidos, imutáveis e versionados por timestamp contendo:
  - manifest.json
  - chunks.parquet
  - audit_log.jsonl
  - confidence_components.parquet
  - checksums.sha256
"""
from __future__ import annotations

import hashlib
import json
import logging
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Any

import pyarrow as pa
import pyarrow.parquet as pq

logger = logging.getLogger("ocr_pipeline.artifact_bundle")

CHUNKS_SCHEMA = pa.schema([
    ("chunk_id", pa.string()),
    ("pdf_source", pa.string()),
    ("page", pa.int32()),
    ("text_final", pa.string()),
    ("confidence_final", pa.float32()),
    ("rollback_applied", pa.bool_()),
    ("rag_provenance_ids", pa.list_(pa.string())),
    ("needs_review", pa.bool_()),
    ("engine_versions", pa.string()),  # Serializado em JSON
])

CONFIDENCE_COMPONENTS_SCHEMA = pa.schema([
    ("chunk_id", pa.string()),
    ("c_ocr", pa.float32()),
    ("c_vis", pa.float32()),
    ("c_lex", pa.float32()),
    ("c_rag", pa.float32()),
    ("weighted_ocr", pa.float32()),
    ("weighted_vis", pa.float32()),
    ("weighted_lex", pa.float32()),
    ("weighted_rag", pa.float32()),
    ("fused_raw", pa.float32()),
    ("confidence_final", pa.float32()),
    ("floor_trap_applied", pa.bool_()),
])


def get_git_commit_hash(cwd: Path | None = None) -> str:
    """Obtém o hash SHA-1 do commit atual do Git para rastreabilidade."""
    try:
        res = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=str(cwd) if cwd else None,
            capture_output=True,
            text=True,
            check=True,
        )
        return res.stdout.strip()
    except Exception as e:
        logger.warning(f"Não foi possível obter commit git: {e}")
        return "git_hash_unavailable"


def compute_file_sha256(filepath: Path) -> str:
    """Calcula o hash SHA-256 de um arquivo em blocos de 64KB."""
    sha = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            sha.update(chunk)
    return sha.hexdigest()


class ArtifactBundleBuilder:
    """Constrói bundles de artefatos arquivísticos no ambiente Desktop (GPU)."""

    def __init__(
        self,
        output_base_dir: Path,
        pipeline_version: str = "5.0.0",
        base_bundle_id: str | None = None,
    ):
        self.output_base_dir = output_base_dir
        self.output_base_dir.mkdir(parents=True, exist_ok=True)
        self.pipeline_version = pipeline_version
        self.base_bundle_id = base_bundle_id

        self.chunks_records: list[dict[str, Any]] = []
        self.confidence_records: list[dict[str, Any]] = []
        self.audit_log_entries: list[dict[str, Any]] = []
        self.processed_pages_set: set[tuple[str, int]] = set()
        self.processed_pdfs_set: set[str] = set()

    def add_chunk(
        self,
        chunk_id: str,
        pdf_source: str,
        page: int,
        text_final: str,
        confidence_final: float,
        rollback_applied: bool,
        rag_provenance_ids: list[str],
        needs_review: bool,
        engine_versions: dict[str, str],
        confidence_components: dict[str, Any] | None = None,
    ) -> None:
        """Adiciona um chunk processado e seus componentes de confiança."""
        self.chunks_records.append({
            "chunk_id": str(chunk_id),
            "pdf_source": str(pdf_source),
            "page": int(page),
            "text_final": str(text_final),
            "confidence_final": float(confidence_final),
            "rollback_applied": bool(rollback_applied),
            "rag_provenance_ids": [str(x) for x in rag_provenance_ids],
            "needs_review": bool(needs_review),
            "engine_versions": json.dumps(engine_versions, ensure_ascii=False),
        })

        self.processed_pages_set.add((pdf_source, page))
        self.processed_pdfs_set.add(pdf_source)

        if confidence_components:
            self.confidence_records.append({
                "chunk_id": str(chunk_id),
                "c_ocr": float(confidence_components.get("c_ocr", 0.0)),
                "c_vis": float(confidence_components.get("c_vis", 0.0)),
                "c_lex": float(confidence_components.get("c_lex", 0.0)),
                "c_rag": float(confidence_components.get("c_rag", 0.0)),
                "weighted_ocr": float(confidence_components.get("weighted_ocr", 0.0)),
                "weighted_vis": float(confidence_components.get("weighted_vis", 0.0)),
                "weighted_lex": float(confidence_components.get("weighted_lex", 0.0)),
                "weighted_rag": float(confidence_components.get("weighted_rag", 0.0)),
                "fused_raw": float(confidence_components.get("fused_raw", confidence_final)),
                "confidence_final": float(confidence_final),
                "floor_trap_applied": bool(confidence_components.get("floor_trap_applied", False)),
            })

    def add_audit_log(self, entry: dict[str, Any]) -> None:
        """Registra uma entrada bruta de auditoria léxica/rollback."""
        self.audit_log_entries.append(entry)

    def build(self, timestamp: datetime | None = None) -> Path:
        """
        Escreve o bundle completo no disco com formato imutável e calcula hashes SHA-256.
        Retorna o caminho da pasta do bundle gerado.
        """
        now = timestamp or datetime.now()
        ts_str = now.strftime("%Y-%m-%dT%H-%M-%S")
        bundle_name = f"artifact_bundle_{ts_str}"
        bundle_dir = self.output_base_dir / bundle_name
        bundle_dir.mkdir(parents=True, exist_ok=False)

        # 1. chunks.parquet
        chunks_table = pa.Table.from_pylist(self.chunks_records, schema=CHUNKS_SCHEMA)
        chunks_path = bundle_dir / "chunks.parquet"
        pq.write_table(chunks_table, chunks_path, compression="snappy")

        # 2. confidence_components.parquet
        conf_table = pa.Table.from_pylist(self.confidence_records, schema=CONFIDENCE_COMPONENTS_SCHEMA)
        conf_path = bundle_dir / "confidence_components.parquet"
        pq.write_table(conf_table, conf_path, compression="snappy")

        # 3. audit_log.jsonl
        audit_path = bundle_dir / "audit_log.jsonl"
        with open(audit_path, "w", encoding="utf-8") as f:
            for item in self.audit_log_entries:
                f.write(json.dumps(item, ensure_ascii=False) + "\n")

        # 4. manifest.json
        git_hash = get_git_commit_hash(bundle_dir.parent)
        manifest_data = {
            "bundle_id": bundle_name,
            "created_at": now.isoformat(),
            "pipeline_version": self.pipeline_version,
            "git_commit": git_hash,
            "base_bundle_id": self.base_bundle_id,
            "total_chunks": len(self.chunks_records),
            "total_pages": len(self.processed_pages_set),
            "total_pdfs": len(self.processed_pdfs_set),
            "files": [
                "manifest.json",
                "chunks.parquet",
                "confidence_components.parquet",
                "audit_log.jsonl",
            ],
        }
        manifest_path = bundle_dir / "manifest.json"
        with open(manifest_path, "w", encoding="utf-8") as f:
            json.dump(manifest_data, f, indent=2, ensure_ascii=False)

        # 5. checksums.sha256
        checksums_path = bundle_dir / "checksums.sha256"
        target_files = ["manifest.json", "chunks.parquet", "confidence_components.parquet", "audit_log.jsonl"]
        lines = []
        for fname in target_files:
            fpath = bundle_dir / fname
            if fpath.exists():
                h = compute_file_sha256(fpath)
                lines.append(f"{h}  {fname}")

        with open(checksums_path, "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")

        logger.info(f"Artifact Bundle {bundle_name} criado com sucesso em: {bundle_dir}")
        return bundle_dir


class ArtifactBundleReader:
    """Lê e valida o Artifact Bundle no ambiente consumidor (Notebook / vocab_worker)."""

    def __init__(self, bundle_dir: Path):
        self.bundle_dir = bundle_dir
        if not self.bundle_dir.exists():
            raise FileNotFoundError(f"Bundle não encontrado: {bundle_dir}")

    def verify_integrity(self) -> tuple[bool, list[str]]:
        """
        Verifica todos os hashes SHA-256 contra checksums.sha256.
        Retorna (is_integro, lista_de_erros).
        """
        checksums_path = self.bundle_dir / "checksums.sha256"
        if not checksums_path.exists():
            return False, ["Arquivo checksums.sha256 ausente no bundle."]

        errors = []
        with open(checksums_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split(maxsplit=1)
                if len(parts) != 2:
                    continue
                expected_hash, fname = parts[0], parts[1].strip()
                fpath = self.bundle_dir / fname
                if not fpath.exists():
                    errors.append(f"Arquivo listado no checksum não existe: {fname}")
                    continue
                actual_hash = compute_file_sha256(fpath)
                if actual_hash.lower() != expected_hash.lower():
                    errors.append(
                        f"Checksum corrompido para {fname}: esperado {expected_hash}, obtido {actual_hash}"
                    )

        return (len(errors) == 0), errors

    def load_manifest(self) -> dict[str, Any]:
        """Carrega e retorna o manifest.json."""
        manifest_path = self.bundle_dir / "manifest.json"
        with open(manifest_path, "r", encoding="utf-8") as f:
            return json.load(f)

    def load_chunks(self) -> pa.Table:
        """Carrega chunks.parquet como tabela PyArrow."""
        return pq.read_table(self.bundle_dir / "chunks.parquet")

    def load_confidence_components(self) -> pa.Table:
        """Carrega confidence_components.parquet como tabela PyArrow."""
        return pq.read_table(self.bundle_dir / "confidence_components.parquet")

    def load_audit_log(self) -> list[dict[str, Any]]:
        """Lê o log de auditoria linha a linha."""
        log_path = self.bundle_dir / "audit_log.jsonl"
        entries = []
        with open(log_path, "r", encoding="utf-8") as f:
            for line in f:
                if line.strip():
                    entries.append(json.loads(line))
        return entries
