"""
Banco Vetorial customizado usando SQLite + NumPy.
100% puro Python - zero DLLs, zero compilacao, funciona em qualquer Python 3.x.

Armazena embeddings em SQLite como JSON e usa similaridade coseno para busca.
"""
import json
import logging
import sqlite3
from pathlib import Path

import numpy as np

logger = logging.getLogger("nivelamento.vectordb")


class SQLiteVectorDB:
    """
    Banco de dados vetorial simples baseado em SQLite + NumPy.
    Drop-in replacement do ChromaDB para o projeto TupiLingo.
    """

    def __init__(self, db_path: str):
        self.db_path = str(db_path)
        Path(db_path).parent.mkdir(parents=True, exist_ok=True)
        self._init_db()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path, timeout=30.0, check_same_thread=False)
        conn.execute("PRAGMA journal_mode=DELETE")
        conn.execute("PRAGMA synchronous=NORMAL")
        conn.execute("PRAGMA busy_timeout = 30000")
        return conn

    def _init_db(self):
        with self._connect() as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS documents (
                    id TEXT PRIMARY KEY,
                    document TEXT NOT NULL,
                    embedding TEXT,
                    metadata TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)
            conn.execute("CREATE INDEX IF NOT EXISTS idx_documents_id ON documents(id)")
            conn.commit()
        logger.info(f"[VectorDB] SQLite inicializado em: {self.db_path}")

    def count(self) -> int:
        with self._connect() as conn:
            return conn.execute("SELECT COUNT(*) FROM documents").fetchone()[0]

    def upsert(self, ids: list, documents: list, embeddings: list, metadatas: list):
        """Insere ou atualiza documentos com seus embeddings."""
        with self._connect() as conn:
            for doc_id, doc, emb, meta in zip(ids, documents, embeddings, metadatas):
                emb_json = json.dumps(emb) if emb is not None else None
                meta_json = json.dumps(meta, ensure_ascii=False) if meta else "{}"
                conn.execute("""
                    INSERT INTO documents (id, document, embedding, metadata)
                    VALUES (?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                        document=excluded.document,
                        embedding=excluded.embedding,
                        metadata=excluded.metadata
                """, (doc_id, doc, emb_json, meta_json))
            conn.commit()
        logger.debug(f"[VectorDB] {len(ids)} documentos salvos.")

    def get_by_metadata(self, key: str, value: str) -> list:
        """Retorna todos os documentos com metadado especifico."""
        results = []
        with self._connect() as conn:
            rows = conn.execute(
                "SELECT id FROM documents WHERE json_extract(metadata, ?) = ?",
                (f"$.{key}", value)
            ).fetchall()
            results = [row[0] for row in rows]
        return results

    def has_file_hash(self, file_hash: str) -> bool:
        """Verifica se um arquivo com dado hash ja foi indexado."""
        ids = self.get_by_metadata("file_hash", file_hash)
        return len(ids) > 0

    def query(self, query_embedding: list, n_results: int = 5) -> list[dict]:
        """
        Busca os n_results mais similares usando similaridade coseno.
        Retorna lista de dicts com 'document', 'metadata' e 'score'.
        """
        if not query_embedding:
            return []

        query_vec = np.array(query_embedding, dtype=np.float32)
        norm = np.linalg.norm(query_vec)
        if norm == 0:
            return []
        query_vec = query_vec / norm

        results = []
        with self._connect() as conn:
            # Busca apenas documentos que tem embedding
            rows = conn.execute(
                "SELECT id, document, embedding, metadata FROM documents WHERE embedding IS NOT NULL"
            ).fetchall()

        for doc_id, doc, emb_json, meta_json in rows:
            try:
                emb = np.array(json.loads(emb_json), dtype=np.float32)
                norm_emb = np.linalg.norm(emb)
                if norm_emb == 0:
                    continue
                emb = emb / norm_emb
                score = float(np.dot(query_vec, emb))
                meta = json.loads(meta_json) if meta_json else {}
                results.append({"id": doc_id, "document": doc, "metadata": meta, "score": score})
            except Exception:
                continue

        results.sort(key=lambda x: x["score"], reverse=True)
        return results[:n_results]

    def get_all_metadata(self) -> list[dict]:
        """Retorna todos os metadados para inspeção."""
        with self._connect() as conn:
            rows = conn.execute("SELECT id, metadata FROM documents").fetchall()
        return [{"id": row[0], "metadata": json.loads(row[1] or "{}")} for row in rows]
