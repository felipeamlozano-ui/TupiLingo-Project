"""
Gerenciador de Cache Distribuído e Checkpoints por Página — Capítulos 15 e 30 (Cache Inteligente v2)
Integra:
  - LMDB Expandido com sub-bancos dedicados por hash SHA-256 para:
    * Página (page_cache)
    * Região (region_cache)
    * Token (token_cache)
    * Filtro (filter_cache)
    * OCR (ocr_intermediate)
    * Layout (layout_cache)
    * Super-Resolução (super_res_cache)
    * Checkpoints Atômicos (page_checkpoints)
  - Garante persistência imutável e reuso instantâneo: nunca reprocessa transformações idênticas.
"""
from __future__ import annotations

import hashlib
import json
import logging
from pathlib import Path
from typing import Any, Optional

import lmdb

logger = logging.getLogger("cache_manager")


class DistributedCacheManager:
    """Gerenciador de Cache LMDB Multi-DB de Alta Performance (Cache Inteligente v2)."""

    def __init__(self, cache_dir: Optional[Path] = None):
        self.cache_dir = cache_dir or (Path(__file__).resolve().parent.parent / "ocr_cache")
        self.cache_dir.mkdir(parents=True, exist_ok=True)

        self.lmdb_dir = self.cache_dir / "lmdb_intermediate_ocr"
        self.lmdb_dir.mkdir(parents=True, exist_ok=True)
        # Inicializa LMDB (map_size de 4GB, suporte a 12 sub-bancos)
        self.env = lmdb.open(str(self.lmdb_dir), map_size=4 * 1024 * 1024 * 1024, max_dbs=12)

        # Sub-bancos temáticos por granularidade e etapa
        self.dbs = {
            "page": self.env.open_db(b"page_cache"),
            "region": self.env.open_db(b"region_cache"),
            "token": self.env.open_db(b"token_cache"),
            "filter": self.env.open_db(b"filter_cache"),
            "ocr": self.env.open_db(b"ocr_intermediate"),
            "layout": self.env.open_db(b"layout_cache"),
            "super_res": self.env.open_db(b"super_res_cache"),
            "checkpoints": self.env.open_db(b"page_checkpoints"),
        }

        # Aliases retrocompatíveis
        self.ocr_db = self.dbs["ocr"]
        self.checkpoints_db = self.dbs["checkpoints"]

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
    def compute_sha256(data: bytes | str) -> str:
        """Calcula o hash SHA-256 de dados binários ou string."""
        if isinstance(data, str):
            data = data.encode("utf-8")
        return hashlib.sha256(data).hexdigest()

    @classmethod
    def compute_transform_hash(
        cls,
        data: bytes | str,
        transform_type: str,
        params: Optional[dict[str, Any]] = None,
    ) -> str:
        """Gera hash SHA-256 composto: data + transform_type + params normalizados."""
        hasher = hashlib.sha256()
        if isinstance(data, str):
            hasher.update(data.encode("utf-8"))
        else:
            hasher.update(data)
        hasher.update(transform_type.encode("utf-8"))
        if params:
            hasher.update(json.dumps(params, sort_keys=True).encode("utf-8"))
        return hasher.hexdigest()

    @staticmethod
    def compute_page_hash(image_bytes: bytes, extra_params: Optional[dict[str, Any]] = None) -> str:
        return DistributedCacheManager.compute_transform_hash(image_bytes, "page_raw", extra_params)

    # ── GENERIC TRANSFORM CACHE (CAPÍTULO 30) ─────────────────────────────────

    def get_cached_transform(self, category: str, transform_hash: str) -> Optional[Any]:
        """Recupera resultado em cache do sub-banco LMDB especificado."""
        db = self.dbs.get(category, self.ocr_db)
        key = transform_hash.encode("utf-8")
        with self.env.begin(db=db, write=False) as txn:
            data = txn.get(key)
            if data:
                try:
                    return json.loads(data.decode("utf-8"))
                except Exception:
                    return None
        return None

    def set_cached_transform(self, category: str, transform_hash: str, payload: Any) -> None:
        """Persiste resultado em cache no sub-banco LMDB especificado."""
        db = self.dbs.get(category, self.ocr_db)
        key = transform_hash.encode("utf-8")
        val = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        with self.env.begin(db=db, write=True) as txn:
            txn.put(key, val)

    # ── TYPED HELPERS POR CAMADA (CAPÍTULO 30) ────────────────────────────────

    def get_cached_layout(self, image_hash: str) -> Optional[list[dict[str, Any]]]:
        return self.get_cached_transform("layout", image_hash)

    def set_cached_layout(self, image_hash: str, layout_blocks: list[dict[str, Any]]) -> None:
        self.set_cached_transform("layout", image_hash, layout_blocks)

    def get_cached_super_res(self, crop_hash: str) -> Optional[dict[str, Any]]:
        return self.get_cached_transform("super_res", crop_hash)

    def set_cached_super_res(self, crop_hash: str, sr_data: dict[str, Any]) -> None:
        self.set_cached_transform("super_res", crop_hash, sr_data)

    def get_cached_filter(self, img_hash: str, filter_name: str) -> Optional[dict[str, Any]]:
        h = self.compute_transform_hash(img_hash.encode("utf-8"), f"filter_{filter_name}")
        return self.get_cached_transform("filter", h)

    def set_cached_filter(self, img_hash: str, filter_name: str, result_meta: dict[str, Any]) -> None:
        h = self.compute_transform_hash(img_hash.encode("utf-8"), f"filter_{filter_name}")
        self.set_cached_transform("filter", h, result_meta)

    def get_cached_token(self, token_hash: str) -> Optional[dict[str, Any]]:
        return self.get_cached_transform("token", token_hash)

    def set_cached_token(self, token_hash: str, token_data: dict[str, Any]) -> None:
        self.set_cached_transform("token", token_hash, token_data)

    # ── LMDB: CACHE INTERMEDIÁRIO DE OCR (CAPÍTULO 15) ────────────────────────

    def get_lmdb_ocr(self, page_hash: str) -> Optional[dict[str, Any]]:
        return self.get_cached_transform("ocr", page_hash)

    def set_lmdb_ocr(self, page_hash: str, ocr_dict: dict[str, Any]) -> None:
        self.set_cached_transform("ocr", page_hash, ocr_dict)

    # ── CHECKPOINTS ATÔMICOS POR PÁGINA (CAPÍTULO 15) ─────────────────────────

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


# Compatibilidade retroativa
DeterministicCacheManager = DistributedCacheManager
