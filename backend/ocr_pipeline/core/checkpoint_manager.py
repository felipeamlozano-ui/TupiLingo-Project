"""
Gerenciador de Checkpoint e Persistência Transacional — TupiLingo OCR Forense v3.0
Garante que o pipeline possa ser interrompido e reiniciado em qualquer página sem retrabalho.
"""
import json
import sqlite3
import time
from pathlib import Path
from typing import Any

from .config import GLOBAL_CONFIG

CHECKPOINTS_DB = GLOBAL_CONFIG.checkpoints_dir / "pipeline_checkpoints.db"
PROGRESS_JSONL = GLOBAL_CONFIG.checkpoints_dir / "pipeline_progress.jsonl"

class CheckpointManager:
    def __init__(self, db_path: Path | None = None, jsonl_path: Path | None = None):
        self.db_path = db_path or CHECKPOINTS_DB
        self.jsonl_path = jsonl_path or PROGRESS_JSONL
        self._init_db()

    def _init_db(self):
        conn = sqlite3.connect(self.db_path)
        c = conn.cursor()
        c.execute("""
            CREATE TABLE IF NOT EXISTS page_checkpoints (
                page_key TEXT PRIMARY KEY,
                filename TEXT NOT NULL,
                page_num INTEGER NOT NULL,
                confidence_before REAL,
                confidence_after REAL,
                delta_confidence REAL,
                status TEXT NOT NULL,
                audit_json TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        conn.commit()
        conn.close()

    def is_completed(self, filename: str, page_num: int) -> bool:
        page_key = f"{filename}::{page_num}"
        conn = sqlite3.connect(self.db_path)
        c = conn.cursor()
        c.execute("SELECT 1 FROM page_checkpoints WHERE page_key = ?", (page_key,))
        row = c.fetchone()
        conn.close()
        return row is not None

    def get_completed_keys(self) -> set[str]:
        conn = sqlite3.connect(self.db_path)
        c = conn.cursor()
        c.execute("SELECT page_key FROM page_checkpoints")
        rows = c.fetchall()
        conn.close()
        return set(r[0] for r in rows)

    def save_checkpoint(
        self,
        filename: str,
        page_num: int,
        confidence_before: float | None,
        confidence_after: float,
        audit_data: dict[str, Any]
    ):
        page_key = f"{filename}::{page_num}"
        delta = round(confidence_after - (confidence_before or 0.0), 2) if confidence_before is not None else 0.0
        status = audit_data.get("status", "concluido")
        audit_json = json.dumps(audit_data, ensure_ascii=False)

        # 1. Persistência atômica no SQLite
        conn = sqlite3.connect(self.db_path)
        c = conn.cursor()
        c.execute("""
            INSERT OR REPLACE INTO page_checkpoints 
            (page_key, filename, page_num, confidence_before, confidence_after, delta_confidence, status, audit_json)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (page_key, filename, page_num, confidence_before, confidence_after, delta, status, audit_json))
        conn.commit()
        conn.close()

        # 2. Gravação em JSONL para streaming de auditoria
        summary_record = {
            "page_key": page_key,
            "filename": filename,
            "page_num": page_num,
            "confidence_before": confidence_before,
            "confidence_after": confidence_after,
            "delta_confidence": delta,
            "status": status,
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S")
        }
        with open(self.jsonl_path, "a", encoding="utf-8") as f:
            f.write(json.dumps(summary_record, ensure_ascii=False) + "\n")

    def is_page_completed(self, filename: str, page_num: int) -> bool:
        """Alias para is_completed."""
        return self.is_completed(filename, page_num)

    def record_page(
        self,
        filename: str,
        page_num: int,
        status: str,
        metrics: dict[str, Any],
        confidence_before: float | None = None,
        confidence_after: float | None = None,
    ):
        """Grava checkpoint consolidado por página."""
        conf_after = confidence_after if confidence_after is not None else metrics.get("mean_confidence", 0.0)
        audit_payload = {"status": status, **metrics}
        self.save_checkpoint(
            filename=filename,
            page_num=page_num,
            confidence_before=confidence_before,
            confidence_after=conf_after,
            audit_data=audit_payload,
        )
