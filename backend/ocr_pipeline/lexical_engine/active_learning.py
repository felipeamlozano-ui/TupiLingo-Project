"""
Active Learning Engine — Capítulo 29
Sistema de Aprendizado Ativo alimentado por revisão humana:
  - Captura revisões humanas para retroalimentar o pipeline.
  - Whitelist e Blacklist dinâmicas e auditadas.
  - Tabela de Correções Permanentes (substituições confirmadas).
  - Rastreamento de frequências de tokens corrigidos.
  - Histórico imutável de revisões.
  - Validação estrita contra benchmark: nunca aplica promoções automáticas sem confirmação prévia.
"""
from __future__ import annotations

import json
import logging
import sqlite3
import time
from datetime import datetime
from pathlib import Path
from typing import Any, Optional
from pydantic import BaseModel, Field

logger = logging.getLogger("active_learning")


class ReviewRecord(BaseModel):
    review_id: str
    token_before: str
    token_after: str
    reviewer: str
    timestamp: str
    source_pdf: str
    context: str
    confirmed: bool


class ActiveLearningEngine:
    """Motor de Aprendizado Ativo com Salvaguarda de Benchmark."""

    def __init__(
        self,
        storage_dir: Optional[Path] = None,
        min_confirmations_for_whitelist: int = 2,
    ):
        self.storage_dir = storage_dir or (Path(__file__).resolve().parent.parent.parent / "ocr_cache" / "active_learning")
        self.storage_dir.mkdir(parents=True, exist_ok=True)
        self.db_path = self.storage_dir / "active_learning.db"
        self.min_confirmations = min_confirmations_for_whitelist
        self._init_sqlite()

    def _init_sqlite(self):
        conn = sqlite3.connect(self.db_path)
        try:
            cursor = conn.cursor()
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS human_reviews (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    review_id TEXT UNIQUE,
                    token_before TEXT,
                    token_after TEXT,
                    reviewer TEXT,
                    timestamp TEXT,
                    source_pdf TEXT,
                    context TEXT,
                    confirmed INTEGER
                )
                """
            )
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS active_whitelist (
                    token TEXT PRIMARY KEY,
                    confirmations_count INTEGER,
                    first_added TEXT,
                    last_reviewed TEXT
                )
                """
            )
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS active_blacklist (
                    token TEXT PRIMARY KEY,
                    reason TEXT,
                    added_by TEXT,
                    timestamp TEXT
                )
                """
            )
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS permanent_corrections (
                    corrupted_form TEXT PRIMARY KEY,
                    corrected_form TEXT,
                    occurrences_count INTEGER,
                    benchmark_verified INTEGER
                )
                """
            )
            conn.commit()
        finally:
            conn.close()

    def submit_human_review(
        self,
        token_before: str,
        token_after: str,
        reviewer: str,
        source_pdf: str = "",
        context: str = "",
        confirmed: bool = True,
    ) -> ReviewRecord:
        """Registra uma revisão humana auditável no histórico."""
        import uuid
        rev_id = f"rev_{int(time.time() * 1000)}_{uuid.uuid4().hex[:6]}"
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        conn = sqlite3.connect(self.db_path)
        try:
            cursor = conn.cursor()
            cursor.execute(
                """
                INSERT INTO human_reviews (review_id, token_before, token_after, reviewer, timestamp, source_pdf, context, confirmed)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (rev_id, token_before, token_after, reviewer, timestamp, source_pdf, context, 1 if confirmed else 0),
            )

            # Atualizar contagem de confirmação para whitelist
            clean_after = token_after.strip().lower()
            if clean_after:
                cursor.execute(
                    """
                    INSERT INTO active_whitelist (token, confirmations_count, first_added, last_reviewed)
                    VALUES (?, 1, ?, ?)
                    ON CONFLICT(token) DO UPDATE SET
                        confirmations_count = confirmations_count + 1,
                        last_reviewed = excluded.last_reviewed
                    """,
                    (clean_after, timestamp, timestamp),
                )

            # Se for correção recorrente, registra em permanent_corrections
            clean_before = token_before.strip().lower()
            if clean_before != clean_after:
                cursor.execute(
                    """
                    INSERT INTO permanent_corrections (corrupted_form, corrected_form, occurrences_count, benchmark_verified)
                    VALUES (?, ?, 1, 0)
                    ON CONFLICT(corrupted_form) DO UPDATE SET
                        occurrences_count = occurrences_count + 1,
                        corrected_form = excluded.corrected_form
                    """,
                    (clean_before, clean_after),
                )

            conn.commit()
        finally:
            conn.close()

        logger.info(f"Revisão humana registrada: '{token_before}' -> '{token_after}' por {reviewer}")
        return ReviewRecord(
            review_id=rev_id,
            token_before=token_before,
            token_after=token_after,
            reviewer=reviewer,
            timestamp=timestamp,
            source_pdf=source_pdf,
            context=context,
            confirmed=confirmed,
        )

    def add_to_blacklist(self, token: str, reason: str, reviewer: str):
        """Adiciona token ruidoso à blacklist permanente."""
        conn = sqlite3.connect(self.db_path)
        try:
            cursor = conn.cursor()
            cursor.execute(
                """
                INSERT OR REPLACE INTO active_blacklist (token, reason, added_by, timestamp)
                VALUES (?, ?, ?, ?)
                """,
                (token.strip().lower(), reason, reviewer, datetime.now().strftime("%Y-%m-%d %H:%M:%S")),
            )
            conn.commit()
        finally:
            conn.close()

    def get_whitelist(self) -> set[str]:
        """Obtém palavras da whitelist que atingiram o mínimo de confirmações humanas."""
        conn = sqlite3.connect(self.db_path)
        try:
            cursor = conn.cursor()
            cursor.execute("SELECT token FROM active_whitelist WHERE confirmations_count >= ?", (self.min_confirmations,))
            rows = cursor.fetchall()
            return {r[0] for r in rows}
        finally:
            conn.close()

    def get_blacklist(self) -> set[str]:
        """Obtém lista de termos banidos."""
        conn = sqlite3.connect(self.db_path)
        try:
            cursor = conn.cursor()
            cursor.execute("SELECT token FROM active_blacklist")
            rows = cursor.fetchall()
            return {r[0] for r in rows}
        finally:
            conn.close()

    def verify_against_benchmark(self, previous_cer: float, new_cer: float) -> bool:
        """
        Validação do Active Learning contra benchmark:
        Se a promoção de termos piorar o CER (new_cer > previous_cer), rejeita a automação.
        """
        is_safe = new_cer <= previous_cer
        if is_safe:
            # Marcar correções permanentes como verificadas
            conn = sqlite3.connect(self.db_path)
            try:
                cursor = conn.cursor()
                cursor.execute("UPDATE permanent_corrections SET benchmark_verified = 1 WHERE occurrences_count >= 2")
                conn.commit()
            finally:
                conn.close()
        return is_safe
