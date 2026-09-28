"""
Dataset Version Control — RFC v6 Capítulo 34
=============================================
Gerencia o versionamento arquivístico, integridade criptográfica (SHA-256),
detecção de drift e metadados históricos de todos os documentos PDF do acervo TupiLingo.
"""

import hashlib
import json
import logging
import os
import re
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

logger = logging.getLogger("tupilingo.dataset_versioning")

try:
    import PyPDF2
except ImportError:
    PyPDF2 = None


@dataclass
class PDFDatasetManifest:
    """Metadados e integridade criptográfica de um PDF do acervo."""
    file_name: str
    file_path: str
    file_size_bytes: int
    sha256: str
    page_count: int
    language: str
    linguistic_variant: str
    year: Optional[int]
    source: str
    quality: str  # SCAN_PURO | MISTO_DEGRADADO | TEXTO_DIGITAL_LIMPO
    created_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "PDFDatasetManifest":
        return cls(**data)


@dataclass
class DatasetVersionSnapshot:
    """Registro histórico de versão de um dataset."""
    version_tag: str
    timestamp: str
    total_files: int
    total_pages: int
    total_size_bytes: int
    notes: str
    manifests: Dict[str, Dict[str, Any]]
    drift_summary: Dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "DatasetVersionSnapshot":
        return cls(**data)


class DatasetVersionManager:
    """
    Gerenciador de Versionamento e Integridade do Dataset (RFC v6 Cap 34).
    Garante rastreabilidade científica total dos arquivos de entrada.
    """

    # Heurísticas de variantes linguísticas por palavra-chave no nome do arquivo
    VARIANT_PATTERNS = [
        (r"nheengatu|lingua geral|língua geral", "nheengatu"),
        (r"kamaiura|kamaiurá|sek00|seki", "kamaiura"),
        (r"tupinamba|tupinambá", "tupinamba"),
        (r"guarani|guaraná", "guarani_antigo"),
        (r"potiguara", "potiguara"),
        (r"baniwa", "baniwa"),
        (r"maue|maues|maués", "maue"),
        (r"tupi antigo|tupy|curso de tupi|dicionario tupi|grammatica", "tupi_antigo"),
    ]

    # Heurísticas de fontes históricas documentadas
    HISTORICAL_SOURCES = [
        ("ayrosa", "Plínio Ayrosa (1943)"),
        ("barbosa", "Pe. A. Lemos Barbosa (1956)"),
        ("cascudo", "Luís da Câmara Cascudo (1988)"),
        ("fernandes", "Anchieta Fernandes / Fernandes (1924)"),
        ("dietrich", "Wolf Dietrich (2025)"),
        ("carta 1645", "Cartas de Camarão / Cartas dos Índios (1645)"),
        ("masucci", "Affonso Masucci (1979)"),
        ("ribeiro", "Berta G. Ribeiro (1988)"),
        ("rodrigues", "Aryon Dall'Igna Rodrigues"),
        ("seki", "Lucy Seki (1976)"),
        ("veiga", "Juracilda Veiga (2015)"),
        ("simpson", "Simpson / Lingua Brasileira (1955)"),
        ("pereira", "Nunes Pereira (1954)"),
    ]

    def __init__(self, cache_dir: Optional[Path] = None):
        self.cache_dir = cache_dir or Path(r"c:\Users\Felipe\Downloads\Tupilingo\backend\ocr_cache")
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.manifest_file = self.cache_dir / "dataset_manifest.json"
        self.history_file = self.cache_dir / "dataset_version_history.json"
        self._manifests: Dict[str, PDFDatasetManifest] = {}
        self._load_current_manifest()

    def _load_current_manifest(self) -> None:
        if self.manifest_file.exists():
            try:
                with open(self.manifest_file, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    for k, v in data.items():
                        self._manifests[k] = PDFDatasetManifest.from_dict(v)
            except Exception as e:
                logger.warning(f"Não foi possível carregar manifesto existente: {e}")

    @staticmethod
    def compute_sha256(file_path: Path) -> str:
        """Calcula SHA-256 criptográfico de um arquivo em blocos de 64KB."""
        h = hashlib.sha256()
        with open(file_path, "rb") as f:
            while chunk := f.read(65536):
                h.update(chunk)
        return h.hexdigest()

    def inspect_pdf_metadata(self, file_path: Path) -> Dict[str, Any]:
        """Extrai número de páginas e classifica qualidade do PDF."""
        fname = file_path.name
        page_count = 0
        quality = "SCAN_PURO"

        if PyPDF2 is not None:
            try:
                with open(file_path, "rb") as f:
                    reader = PyPDF2.PdfReader(f)
                    page_count = len(reader.pages)
                    if page_count > 0:
                        sample_pages = min(page_count, 10)
                        step = max(1, page_count // sample_pages)
                        low_text_count = 0
                        for i in range(0, page_count, step):
                            try:
                                text = reader.pages[i].extract_text() or ""
                                if len(text.strip()) < 120:
                                    low_text_count += 1
                            except Exception:
                                low_text_count += 1
                        ratio = low_text_count / sample_pages
                        if ratio >= 0.8:
                            quality = "SCAN_PURO"
                        elif ratio >= 0.2:
                            quality = "MISTO_DEGRADADO"
                        else:
                            quality = "TEXTO_DIGITAL_LIMPO"
            except Exception as e:
                logger.warning(f"Erro ao ler PDF com PyPDF2 ({fname}): {e}")

        # Extração de ano por regex
        year = None
        year_match = re.search(r"_(1[5-9]\d{2}|20\d{2})_", fname) or re.search(r"\b(1[5-9]\d{2}|20\d{2})\b", fname)
        if year_match:
            try:
                year = int(year_match.group(1))
            except ValueError:
                pass

        # Identificação de variante linguística
        variant = "tupi_antigo"
        fname_lower = fname.lower()
        for pat, var_name in self.VARIANT_PATTERNS:
            if re.search(pat, fname_lower):
                variant = var_name
                break

        # Identificação de fonte histórica
        source = "Documento Arquivístico"
        for key, src_name in self.HISTORICAL_SOURCES:
            if key in fname_lower:
                source = src_name
                break

        # Identificação de idioma
        if "guarani" in fname_lower or "kamaiura" in fname_lower or "baniwa" in fname_lower:
            language = "Tupi-Guarani / Português"
        elif "nheengatu" in fname_lower or "lingua geral" in fname_lower:
            language = "Nheengatu / Português"
        elif "1645" in fname_lower:
            language = "Tupi Antigo Histórico (Sec. XVII)"
        else:
            language = "Tupi Antigo / Português"

        return {
            "page_count": page_count,
            "quality": quality,
            "year": year,
            "linguistic_variant": variant,
            "source": source,
            "language": language,
        }

    def scan_dataset(self, directory: Path) -> Dict[str, PDFDatasetManifest]:
        """
        Escaneia diretório contendo PDFs e constrói/atualiza o manifesto.
        """
        pdf_dir = Path(directory)
        if not pdf_dir.exists():
            raise FileNotFoundError(f"Diretório de PDFs não encontrado: {pdf_dir}")

        pdf_files = sorted(pdf_dir.glob("*.pdf"), key=lambda p: p.name.lower())
        results: Dict[str, PDFDatasetManifest] = {}

        for pdf_path in pdf_files:
            fname = pdf_path.name
            size_bytes = pdf_path.stat().st_size
            sha = self.compute_sha256(pdf_path)
            meta = self.inspect_pdf_metadata(pdf_path)

            manifest = PDFDatasetManifest(
                file_name=fname,
                file_path=str(pdf_path.resolve()),
                file_size_bytes=size_bytes,
                sha256=sha,
                page_count=meta["page_count"],
                language=meta["language"],
                linguistic_variant=meta["linguistic_variant"],
                year=meta["year"],
                source=meta["source"],
                quality=meta["quality"],
            )
            results[fname] = manifest
            self._manifests[fname] = manifest

        self.save_manifest()
        return results

    scan_and_version_dataset = scan_dataset

    def save_manifest(self) -> None:

        """Grava manifesto JSON atômico."""
        data = {k: v.to_dict() for k, v in self._manifests.items()}
        tmp_file = self.manifest_file.with_suffix(".tmp")
        with open(tmp_file, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        tmp_file.replace(self.manifest_file)

    def detect_dataset_drift(self, directory: Path) -> Dict[str, Any]:
        """
        Detecta drift no acervo: arquivos novos, removidos ou cujo SHA256 divergiu.
        """
        pdf_dir = Path(directory)
        current_files = {p.name: p for p in pdf_dir.glob("*.pdf")}

        drift = {
            "added": [],
            "removed": [],
            "modified": [],
            "verified": [],
            "drift_detected": False,
        }

        # Verifica arquivos removidos ou modificados
        for fname, recorded in self._manifests.items():
            if fname not in current_files:
                drift["removed"].append(fname)
                drift["drift_detected"] = True
            else:
                curr_path = current_files[fname]
                curr_sha = self.compute_sha256(curr_path)
                if curr_sha != recorded.sha256:
                    drift["modified"].append({
                        "file_name": fname,
                        "old_sha256": recorded.sha256,
                        "new_sha256": curr_sha,
                    })
                    drift["drift_detected"] = True
                else:
                    drift["verified"].append(fname)

        # Verifica novos arquivos
        for fname in current_files:
            if fname not in self._manifests:
                drift["added"].append(fname)
                drift["drift_detected"] = True

        return drift

    def record_version(self, version_tag: str, notes: str = "", pdf_dir: Optional[Path] = None) -> DatasetVersionSnapshot:
        """
        Cria e congela um snapshot de versão arquivística no histórico permanente.
        """
        drift = self.detect_dataset_drift(pdf_dir) if pdf_dir else {}
        total_pages = sum(m.page_count for m in self._manifests.values())
        total_bytes = sum(m.file_size_bytes for m in self._manifests.values())

        snapshot = DatasetVersionSnapshot(
            version_tag=version_tag,
            timestamp=datetime.now(timezone.utc).isoformat(),
            total_files=len(self._manifests),
            total_pages=total_pages,
            total_size_bytes=total_bytes,
            notes=notes,
            manifests={k: v.to_dict() for k, v in self._manifests.items()},
            drift_summary=drift,
        )

        history = self.get_version_history()
        history.append(snapshot.to_dict())

        tmp_hist = self.history_file.with_suffix(".tmp")
        with open(tmp_hist, "w", encoding="utf-8") as f:
            json.dump(history, f, indent=2, ensure_ascii=False)
        tmp_hist.replace(self.history_file)

        return snapshot

    def get_version_history(self) -> List[Dict[str, Any]]:
        """Retorna lista de snapshots históricos congelados."""
        if not self.history_file.exists():
            return []
        try:
            with open(self.history_file, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception as e:
            logger.warning(f"Erro ao ler histórico de versões: {e}")
            return []

    def get_manifest(self, file_name: str) -> Optional[PDFDatasetManifest]:
        return self._manifests.get(file_name)

    @property
    def all_manifests(self) -> Dict[str, PDFDatasetManifest]:
        return self._manifests
