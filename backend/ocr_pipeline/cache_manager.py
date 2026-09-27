"""
Gerenciador de cache determinístico por hash SHA-256 (Etapa 15 da arquitetura).
Garante idempotência e evita reprocessamento de páginas e perfis idênticos.
"""
import hashlib
import json
from pathlib import Path
from typing import Any

CACHE_DIR = Path(__file__).resolve().parent.parent / "ocr_cache"
PROFILES_CACHE_DIR = CACHE_DIR / "profiles"
OCR_CACHE_DIR = CACHE_DIR / "ocr_results"

PROFILES_CACHE_DIR.mkdir(parents=True, exist_ok=True)
OCR_CACHE_DIR.mkdir(parents=True, exist_ok=True)

class DeterministicCacheManager:
    @staticmethod
    def compute_sha256(data: bytes) -> str:
        return hashlib.sha256(data).hexdigest()

    @staticmethod
    def compute_page_hash(image_bytes: bytes, extra_params: dict[str, Any] | None = None) -> str:
        hasher = hashlib.sha256(image_bytes)
        if extra_params:
            params_str = json.dumps(extra_params, sort_keys=True)
            hasher.update(params_str.encode("utf-8"))
        return hasher.hexdigest()

    @classmethod
    def get_cached_profile(cls, page_hash: str) -> dict[str, Any] | None:
        cache_path = PROFILES_CACHE_DIR / f"{page_hash}.json"
        if cache_path.exists():
            try:
                with open(cache_path, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception:
                return None
        return None

    @classmethod
    def set_cached_profile(cls, page_hash: str, profile_dict: dict[str, Any]) -> None:
        cache_path = PROFILES_CACHE_DIR / f"{page_hash}.json"
        try:
            with open(cache_path, "w", encoding="utf-8") as f:
                json.dump(profile_dict, f, indent=2, ensure_ascii=False)
        except Exception:
            pass

    @classmethod
    def get_cached_ocr(cls, page_hash: str) -> dict[str, Any] | None:
        cache_path = OCR_CACHE_DIR / f"{page_hash}.json"
        if cache_path.exists():
            try:
                with open(cache_path, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception:
                return None
        return None

    @classmethod
    def set_cached_ocr(cls, page_hash: str, ocr_dict: dict[str, Any]) -> None:
        cache_path = OCR_CACHE_DIR / f"{page_hash}.json"
        try:
            with open(cache_path, "w", encoding="utf-8") as f:
                json.dump(ocr_dict, f, indent=2, ensure_ascii=False)
        except Exception:
            pass
