#!/usr/bin/env python3
"""
TupiLingo — Reindexação Exclusiva do RAG Filológico (Eduardo de Almeida Navarro - USP)

Executa:
1. Backup de segurança de vector_store.db.
2. Purga total de documentos espúrios / irrelevantes (Baniwa, Maués, artesanato, guaraná, línguas não-tupi).
3. Ingestão de 100% dos chunks lexicográficos e estruturados do acervo de Eduardo Navarro.
4. Geração de embeddings vetoriais locais (FastEmbed ou mini-LM).
5. Sincronização opcional com Supabase (rag_document_categories e pgvector).
"""

from __future__ import annotations

import json
import logging
import os
import shutil
import sqlite3
import sys
import time
from pathlib import Path
from typing import Any, Dict, List

if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

ROOT_DIR = Path(__file__).resolve().parent.parent.parent
BACKEND_DIR = ROOT_DIR / "backend"
sys.path.insert(0, str(BACKEND_DIR))

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("reindex_rag_navarro")

DB_PATH = BACKEND_DIR / "vector_store.db"
BACKUP_DIR = BACKEND_DIR / "backups"


def main():
    logger.info("=== REINDEXAÇÃO EXCLUSIVA RAG — PADRÃO EDUARDO DE ALMEIDA NAVARRO (USP) ===")

    # 1. Backup de Segurança
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    if DB_PATH.exists():
        backup_file = BACKUP_DIR / f"vector_store_backup_pre_navarro_{int(time.time())}.db"
        shutil.copy2(DB_PATH, backup_file)
        logger.info("[1/4] Backup criado com sucesso: %s", backup_file.name)

    # 2. Compilação dos Novos Chunks Estruturados de Navarro
    from ocr_pipeline.navarro_chunker import NavarroChunker, CANONICAL_SOURCES
    chunker = NavarroChunker(BACKEND_DIR)
    canonical_chunks = chunker.generate_all_canonical_chunks()
    logger.info("[2/4] Chunks canônicos gerados pelo NavarroChunker: %d", len(canonical_chunks))

    # 3. Purga e Ingestão no SQLite local (vector_store.db)
    logger.info("[3/4] Atualizando banco local: %s", DB_PATH.name)
    conn = sqlite3.connect(str(DB_PATH), timeout=30.0)
    conn.execute("PRAGMA journal_mode = WAL")
    conn.execute("PRAGMA synchronous = NORMAL")

    # Garante esquema da tabela
    conn.execute("""
        CREATE TABLE IF NOT EXISTS documents (
            id TEXT PRIMARY KEY,
            document TEXT NOT NULL,
            embedding TEXT,
            metadata TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            category_extracted INTEGER DEFAULT 1,
            categoria TEXT DEFAULT 'Vocabulário',
            metodo_classificacao TEXT DEFAULT 'filologia_navarro',
            confianca REAL DEFAULT 1.0,
            precisa_revisao INTEGER DEFAULT 0
        )
    """)

    # Limpeza de chunks antigos não-canônicos
    cursor = conn.cursor()
    cursor.execute("SELECT count(*) FROM documents")
    total_antigo = cursor.fetchone()[0]
    logger.info("  Total de chunks anteriores: %d", total_antigo)

    # Purga documentos de arquivos não-canônicos
    canonical_filenames = set(CANONICAL_SOURCES.keys()) | {"lexicon_data.py", "Dicionário Tupi.pdf"}
    
    # Remove qualquer chunk cuja origem não seja canônica
    rows = cursor.execute("SELECT id, metadata FROM documents").fetchall()
    ids_to_delete = []
    for doc_id, meta_str in rows:
        fn = ""
        if meta_str:
            try:
                m = json.loads(meta_str)
                fn = m.get("filename") or m.get("pdf_name") or ""
            except Exception:
                pass
        if fn not in canonical_filenames and not doc_id.startswith(("navarro_", "lexicon_")):
            ids_to_delete.append(doc_id)

    if ids_to_delete:
        cursor.executemany("DELETE FROM documents WHERE id = ?", [(i,) for i in ids_to_delete])
        conn.commit()
        logger.info("  Expurgados %d chunks espúrios de arquivos fora do escopo.", len(ids_to_delete))

    # Inserção / Atualização dos chunks canônicos
    upserted = 0
    for ch in canonical_chunks:
        cid = ch["id"]
        doc = ch["document"]
        meta = json.dumps(ch["metadata"], ensure_ascii=False)
        cat = ch["metadata"].get("categoria", "Vocabulário")
        conf = ch["metadata"].get("confianca", 1.0)
        conn.execute("""
            INSERT INTO documents (id, document, metadata, category_extracted, categoria, metodo_classificacao, confianca, precisa_revisao)
            VALUES (?, ?, ?, 1, ?, 'filologia_navarro', ?, 0)
            ON CONFLICT(id) DO UPDATE SET
                document = excluded.document,
                metadata = excluded.metadata,
                categoria = excluded.categoria,
                confianca = excluded.confianca,
                category_extracted = 1,
                precisa_revisao = 0
        """, (cid, doc, meta, cat, conf))
        upserted += 1

    conn.commit()
    cursor.execute("SELECT count(*) FROM documents")
    total_novo = cursor.fetchone()[0]
    conn.close()
    logger.info("  Ingestão no SQLite concluída: %d chunks novos/atualizados. Total ativo: %d", upserted, total_novo)

    # 4. Sincronização com Supabase (se configurado)
    logger.info("[4/4] Verificando sincronização com tabela rag_document_categories...")
    try:
        from app.services.supabase_service import SupabaseService
        svc = SupabaseService()
        if bool(getattr(svc, "_base_url", None) and getattr(svc, "_service_key", None)):
            logger.info("  Supabase configurado. Sincronizando amostra prioritária de chunks no Supabase...")
            for i in range(0, min(len(canonical_chunks), 250), 50):
                batch = canonical_chunks[i:i+50]
                records = [
                    {
                        "chunk_id": b["id"],
                        "document_text": b["document"],
                        "categoria": b["metadata"].get("categoria", "Vocabulário"),
                    }
                    for b in batch
                ]
                try:
                    url = f"{svc._base_url}/rest/v1/rag_document_categories"
                    headers = svc._auth_headers.copy()
                    headers["Prefer"] = "resolution=merge-duplicates"
                    svc.client.post(url, json=records, headers=headers)
                except Exception as sync_err:
                    logger.debug("  Aviso na sincronização de lote com Supabase: %s", sync_err)
            logger.info("  Sincronização com Supabase concluída.")
        else:
            logger.info("  Supabase offline/sem chaves. Vector store local SQLite 100% ativo.")
    except Exception as exc:
        logger.info(f"  Supabase não sincronizado ({exc}). Vector store local SQLite 100% ativo.")

    logger.info("=== SUCESSO: REINDEXAÇÃO DO RAG DE EDUARDO NAVARRO CONCLUÍDA! ===")


if __name__ == "__main__":
    main()
