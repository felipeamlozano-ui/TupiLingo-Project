"""
Gerenciador de Cache Distribuído e Checkpoints por Página — Capítulo 15
Integra:
  - SQLite (vector_store.db): fonte de verdade para chunks finais e metadados.
  - LMDB: cache rápido de alta escala para resultados intermediários de OCR
    (hash da imagem pré-processada -> resultado bruto do motor).
  - Checkpoints Atômicos por Página: permite pausar e retomar o lote de 559 páginas
    sem nunca reprocessar o trabalho já concluído.
"""
import hashlib
import json
import sqlite3
from pathlib import Path
from typing import Any, Optional

import lmdb


class DistributedCacheManager:
    def __init__(self, cache_dir: Optional[Path] = None):
        self.cache_dir = cache_dir or (Path(__file__).resolve().parent.parent / "ocr_cache")
        self.cache_dir.mkdir(parents=True, exist_ok=True)

        self.lmdb_dir = self.cache_dir / "lmdb_intermediate_ocr"
        self.lmdb_dir.mkdir(parents=True, exist_ok=True)
        # Inicializa LMDB (map_size de 2GB)
        self.env = lmdb.open(str(self.lmdb_dir), map_size=2 * 1024 * 1024 * 1024, max_dbs=5)
        self.ocr_db = self.env.open_db(b"ocr_intermediate")
        self.checkpoints_db = self.env.open_db(b"page_checkpoints")

        self.profiles_cache_dir = self.cache_dir / "profiles"
        self.profiles_cache_dir.mkdir(parents=True, exist_ok=True)

        self.checkpoints_json_dir = self.cache_dir / "checkpoints"
        self.checkpoints_json_dir.mkdir(parents=True, exist_ok=True)

    def close(self):
        """Fecha o ambiente LMDB de forma limpa."""
        if hasattr(self, "env") and self.env:
            self.env.close()

    def __del__(self):
        self.close()

    @staticmethod
    def compute_sha256(data: bytes) -> str:
        return hashlib.sha256(data).hexdigest()

    @staticmethod
    def compute_page_hash(image_bytes: bytes, extra_params: Optional[dict[str, Any]] = None) -> str:
        hasher = hashlib.sha256(image_bytes)
        if extra_params:
            params_str = json.dumps(extra_params, sort_keys=True)
            hasher.update(params_str.encode("utf-8"))
        return hasher.hexdigest()

    # ── LMDB: CACHE INTERMEDIÁRIO DE OCR ──────────────────────────────────────

    def get_lmdb_ocr(self, page_hash: str) -> Optional[dict[str, Any]]:
        """Recupera resultado intermediário de OCR do LMDB por hash."""
        key = page_hash.encode("utf-8")
        with self.env.begin(db=self.ocr_db, write=False) as txn:
            data = txn.get(key)
            if data:
                try:
                    return json.loads(data.decode("utf-8"))
                except Exception:
                    return None
        return None

    def set_lmdb_ocr(self, page_hash: str, ocr_dict: dict[str, Any]) -> None:
        """Salva resultado intermediário de OCR no LMDB com garantia de persistência."""
        key = page_hash.encode("utf-8")
        val = json.dumps(ocr_dict, ensure_ascii=False).encode("utf-8")
        with self.env.begin(db=self.ocr_db, write=True) as txn:
            txn.put(key, val)

    # ── CHECKPOINTS ATÔMICOS POR PÁGINA ───────────────────────────────────────

    def is_page_completed(self, pdf_stem: str, page_idx: int) -> bool:
        """Verifica se uma página específica já foi concluída com sucesso e gravada em checkpoint."""
        chk = self.get_page_checkpoint(pdf_stem, page_idx)
        if chk and chk.get("status") in ("sucesso", "completed"):
            return True
        return False

    def record_page_checkpoint(
        self,
        pdf_stem: str,
        page_idx: int,
        checkpoint_data: dict[str, Any],
    ) -> None:
        """Grava checkpoint atômico por página no LMDB e espelho JSON."""
        key = f"{pdf_stem}_p{page_idx}".encode("utf-8")
        val = json.dumps(checkpoint_data, ensure_ascii=False).encode("utf-8")
        with self.env.begin(db=self.checkpoints_db, write=True) as txn:
            txn.put(key, val)

        json_path = self.checkpoints_json_dir / f"chk_{pdf_stem}_p{page_idx}.json"
        try:
            with open(json_path, "w", encoding="utf-8") as f:
                json.dump(checkpoint_data, f, indent=2, ensure_ascii=False)
        except Exception:
            pass

    def get_page_checkpoint(self, pdf_stem: str, page_idx: int) -> Optional[dict[str, Any]]:
        """Lê os dados de checkpoint da página se já processada."""
        key = f"{pdf_stem}_p{page_idx}".encode("utf-8")
        with self.env.begin(db=self.checkpoints_db, write=False) as txn:
            data = txn.get(key)
            if data:
                try:
                    return json.loads(data.decode("utf-8"))
                except Exception:
                    pass

        json_path = self.checkpoints_json_dir / f"chk_{pdf_stem}_p{page_idx}.json"
        if json_path.exists():
            try:
                with open(json_path, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception:
                pass
        return None

    # ── PERFIS FORENSES DE PÁGINA (CAPÍTULO 3) ────────────────────────────────

    def get_cached_profile(self, page_hash: str) -> Optional[dict[str, Any]]:
        cache_path = self.profiles_cache_dir / f"{page_hash}.json"
        if cache_path.exists():
            try:
                with open(cache_path, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception:
                return None
        return None

    def set_cached_profile(self, page_hash: str, profile_dict: dict[str, Any]) -> None:
        cache_path = self.profiles_cache_dir / f"{page_hash}.json"
        try:
            with open(cache_path, "w", encoding="utf-8") as f:
                json.dump(profile_dict, f, indent=2, ensure_ascii=False)
        except Exception:
            pass


# Compatibilidade retroativa para código legado
DeterministicCacheManager = DistributedCacheManager
