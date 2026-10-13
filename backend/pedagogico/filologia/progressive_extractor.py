"""
Pipeline de Extração Progressiva, Auditável e Retomável — TupiLingo.
Processa o Dicionário de Tupi Antigo de Eduardo de Almeida Navarro (Ed. 2013)
em lotes controlados com detecção de orientação, segmentação lexical,
avaliação de integridade tipográfica e fila de revisão humana.

Regras Inegociáveis:
- Candidatos extraídos recebem status AGUARDANDO_REVISAO; NUNCA VALIDADO automaticamente.
- Chunks de OCR e confiança de digitalização são separados da validação filológica.
- O hash do PDF e a versão do extrator são registrados imutavelmente.
"""

from __future__ import annotations

import json
import logging
import re
import sqlite3
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

from .models import (
    AuditLogEntry,
    BibliographicSource,
    InformationTier,
    LexicalEntry,
    OCREvidence,
    PhilologicalStatus,
    normalize_tupi,
)

logger = logging.getLogger("pedagogico.filologia.extractor")

BASE_DIR = Path(__file__).resolve().parent
STATE_FILE = BASE_DIR / "extraction_state.json"
CANDIDATES_FILE = BASE_DIR / "candidatos_navarro.json"
VECTOR_STORE_PATH = BASE_DIR.parent.parent / "vector_store.db"

NAVARRO_FILE_HASH = "87c9662bc45de33bf5f5592c24f249d4ac86ed3fe568d99bcff11f96ad131671"
EXTRACTOR_VERSION = "2.0.0-navarro-progressive"


@dataclass
class BatchExecutionReport:
    batch_id: str
    started_at: str
    finished_at: str
    start_page: int
    end_page: int
    pages_processed: List[int]
    candidates_extracted_count: int
    unique_lemmas_count: int
    duplicates_detected_count: int
    flagged_for_human_review_count: int
    orientation_corrected_pages: List[int]
    errors: List[Dict[str, Any]]
    total_duration_seconds: float


class ProgressiveNavarroExtractor:
    """
    Extrator progressivo em lotes pequenos, auditáveis e retomáveis.
    """

    CLASS_ABBREVIATIONS = (
        r"s\.|v\.|adj\.|part\.|pron\.|interj\.|posp\.|adv\.|conj\.|num\.|suf\.|pref\.|loc\.|prep\."
    )

    def __init__(
        self,
        db_path: Path = VECTOR_STORE_PATH,
        state_file: Path = STATE_FILE,
        candidates_file: Path = CANDIDATES_FILE,
    ):
        self.db_path = db_path
        self.state_file = state_file
        self.candidates_file = candidates_file
        self.state: Dict[str, Any] = self._load_state()
        self.candidates_by_id: Dict[str, Dict[str, Any]] = self._load_candidates()

        # Regex para verbetes estruturados do padrão Navarro
        class_regex = r"\((?:[^\)]*" + self.CLASS_ABBREVIATIONS + r"[^\)]*)\)"
        self.entry_pattern = re.compile(
            r"(?m)^([a-zîŷáéíóúãẽĩõũ'¹²³⁴⁵\-]+(?:\s+(?:ou|e)\s+[a-zîŷáéíóúãẽĩõũ'¹²³⁴⁵\-]+)?)\s*("
            + class_regex
            + r")\s*-\s*([^\n\r]+)",
            re.IGNORECASE,
        )

    def _load_state(self) -> Dict[str, Any]:
        if self.state_file.exists():
            try:
                with open(self.state_file, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception as exc:
                logger.error("Falha ao carregar estado de extração: %s", exc)
        return {
            "extractor_version": EXTRACTOR_VERSION,
            "target_hash": NAVARRO_FILE_HASH,
            "last_processed_page": 0,
            "processed_pages": [],
            "failed_pages": [],
            "batches_history": [],
            "last_updated": datetime.now(timezone.utc).isoformat(),
        }

    def _save_state(self) -> None:
        self.state["last_updated"] = datetime.now(timezone.utc).isoformat()
        with open(self.state_file, "w", encoding="utf-8") as f:
            json.dump(self.state, f, indent=2, ensure_ascii=False)

    def _load_candidates(self) -> Dict[str, Dict[str, Any]]:
        if self.candidates_file.exists():
            try:
                with open(self.candidates_file, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    return {it["id"]: it for it in data.get("candidates", [])}
            except Exception as exc:
                logger.error("Falha ao carregar candidatos: %s", exc)
        return {}

    def _save_candidates(self) -> None:
        payload = {
            "version": EXTRACTOR_VERSION,
            "hash_fonte": NAVARRO_FILE_HASH,
            "total_candidates": len(self.candidates_by_id),
            "updated_at": datetime.now(timezone.utc).isoformat(),
            "candidates": list(self.candidates_by_id.values()),
        }
        with open(self.candidates_file, "w", encoding="utf-8") as f:
            json.dump(payload, f, indent=2, ensure_ascii=False)

    def register_candidates(self, candidates: List[Dict[str, Any]]) -> int:
        """Registra candidatos externos (ex.: do pipeline físico de imagem) para homologação."""
        added = 0
        for c in candidates:
            if c["id"] not in self.candidates_by_id:
                self.candidates_by_id[c["id"]] = c
                added += 1
        if added > 0:
            self._save_candidates()
        return added

    @staticmethod
    def detect_inverted_page(text: str) -> bool:
        """
        Detecta se o scan da página foi digitalizado de ponta-cabeça (rotação de 180°).
        Heurística: presença de sequências tipográficas espelhadas como 'ajend', '“youy', 'D44)', 'gweinsusD'.
        """
        markers = ("“youy", "ajend", "gweinsusD", "D44)", "d44)", "odury", "dn ")
        return any(m in text for m in markers)

    @staticmethod
    def detect_suspicious_characters(lema: str, definicao: str) -> List[str]:
        """Identifica caracteres suspeitos, números no lema ou pontuações anômalas geradas por OCR."""
        suspicious = []
        if re.search(r"\d", lema):
            # Dígitos que não sejam índices sobrescritos ¹²³⁴
            if not re.search(r"^[a-zîŷáéíóúãẽĩõũ'\-]+[¹²³⁴⁵]?$", lema, re.I):
                suspicious.append("DIGIT_IN_LEMMA")
        if re.search(r"[#\$%\*_\+=\<\>\{\}]", lema):
            suspicious.append("SPECIAL_SYMBOLS_IN_LEMMA")
        if len(lema) < 2 and not lema in ("y", "a", "e", "o", "u", "i"):
            suspicious.append("ISOLATED_SHORT_TOKEN")
        if "?" in definicao[:20] and not "significado incerto" in definicao.lower():
            suspicious.append("QUESTION_MARK_IN_DEFINITION")
        if len(definicao.strip()) < 5:
            suspicious.append("TRUNCATED_DEFINITION")
        return suspicious

    def extract_from_page(
        self, page_num: int, documents: List[Tuple[str, float]]
    ) -> Tuple[List[Dict[str, Any]], bool, List[str]]:
        """
        Extrai verbetes candidatos de uma página digital específica.
        Retorna (lista_de_candidatos, is_inverted, logs_de_alerta).
        """
        extracted = []
        warnings = []
        combined_text = "\n".join(doc for doc, _ in documents)
        mean_conf = (
            sum(conf for _, conf in documents) / len(documents) if documents else 0.0
        )

        is_inverted = self.detect_inverted_page(combined_text)
        if is_inverted:
            warnings.append(
                f"Página digital {page_num} detectada com orientação invertida (180°). Requer rotação pré-OCR."
            )
            # Para páginas invertidas, não extraímos via regex direta sem rotação para evitar ruído
            return [], True, warnings

        seen_lemmas_in_page = set()
        entry_idx = 1

        for doc, chunk_conf in documents:
            matches = self.entry_pattern.findall(doc)
            for m in matches:
                raw_lema = m[0].strip()
                classe = m[1].strip()
                def_raw = m[2].strip()

                # Separa variantes registradas no lema (ex.: "aan! (ou aã)")
                variantes = []
                lema_principal = raw_lema
                if " ou " in raw_lema.lower():
                    parts = re.split(r"\s+ou\s+", raw_lema, flags=re.I)
                    lema_principal = parts[0].strip()
                    variantes.extend(p.strip() for p in parts[1:])

                # Remove sobrescritos de homógrafos do lema principal para normalização
                clean_lema = re.sub(r"[¹²³⁴⁵\?!]", "", lema_principal).strip()
                norm_lema = normalize_tupi(clean_lema)

                # Identifica caracteres suspeitos
                sus_flags = self.detect_suspicious_characters(clean_lema, def_raw)
                requires_review = (
                    bool(sus_flags) or chunk_conf < 85.0 or len(clean_lema) <= 1
                )

                candidate_id = f"NAV-CAND-{page_num:03d}-{entry_idx:02d}"
                entry_idx += 1

                is_dup = clean_lema.lower() in seen_lemmas_in_page
                seen_lemmas_in_page.add(clean_lema.lower())

                entry_dict = {
                    "id": candidate_id,
                    "lema_original": clean_lema,
                    "lema_completo_fonte": raw_lema,
                    "lema_normalizado": norm_lema,
                    "classe_gramatical": classe,
                    "significado_extraido": def_raw,
                    "variantes_documentadas": variantes,
                    "status_publicacao": PhilologicalStatus.AGUARDANDO_REVISAO.value,
                    "tier": InformationTier.TIER_B_NORMALIZACAO_PESQUISA.value,
                    "fonte": {
                        "obra": "Dicionário de Tupi Antigo: a língua indígena clássica do Brasil",
                        "autor": "Eduardo de Almeida Navarro",
                        "edicao": "1ª Edição",
                        "ano": 2013,
                        "editora": "Global Editora",
                        "local": "São Paulo",
                        "pagina_impressa": None,  # Pendente de cotejamento com o volume físico
                        "pagina_digital": page_num,
                        "hash_documento": NAVARRO_FILE_HASH,
                        "arquivo_fonte": "Dicionário Tupi.pdf",
                        "extrator_versao": EXTRACTOR_VERSION,
                    },
                    "ocr_evidence": {
                        "confidence_score": round(chunk_conf, 2),
                        "extraction_method": "regex_structured_chunk",
                        "requires_human_review": requires_review,
                        "is_orientation_corrected": is_inverted,
                        "suspicious_characters": sus_flags,
                    },
                    "is_possible_duplicate": is_dup,
                    "revisao": {
                        "revisado_por": None,
                        "data_revisao": None,
                        "aprovado": False,
                        "motivo_quarentena": None,
                    },
                    "audit_history": [
                        {
                            "revision_id": f"REV-{candidate_id}-00",
                            "timestamp": datetime.now(timezone.utc).isoformat(),
                            "revisor": f"Extrator Automatizado v{EXTRACTOR_VERSION}",
                            "valor_anterior": {},
                            "valor_revisado": {
                                "status": PhilologicalStatus.AGUARDANDO_REVISAO.value
                            },
                            "justificativa": f"Candidato extraído da folha digital {page_num} com confiança OCR {chunk_conf:.1f}%.",
                            "aprovado": False,
                        }
                    ],
                }
                extracted.append(entry_dict)

        return extracted, is_inverted, warnings

    def process_batch(
        self,
        start_page: int,
        end_page: int,
        batch_id: Optional[str] = None,
        force_reprocess: bool = False,
    ) -> BatchExecutionReport:
        """
        Executa um lote de extração progressivo e auditável entre start_page e end_page (inclusivo).
        """
        start_time = datetime.now(timezone.utc)
        b_id = (
            batch_id
            or f"BATCH-P{start_page:03d}-P{end_page:03d}-{int(start_time.timestamp())}"
        )

        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        pages_to_process = [
            p
            for p in range(start_page, end_page + 1)
            if force_reprocess or p not in self.state["processed_pages"]
        ]

        pages_done = []
        orientation_corrected = []
        extracted_this_batch = []
        duplicates_count = 0
        flagged_count = 0
        errors = []

        for page in pages_to_process:
            try:
                cursor.execute(
                    """
                    SELECT document, json_extract(metadata, '$.ocr_conf_mean')
                    FROM documents
                    WHERE json_extract(metadata, '$.file_hash') = ?
                      AND json_extract(metadata, '$.page') = ?
                    ORDER BY json_extract(metadata, '$.chunk_index')
                """,
                    (NAVARRO_FILE_HASH, page),
                )
                docs = cursor.fetchall()
                if not docs:
                    continue

                candidates, is_inv, warns = self.extract_from_page(page, docs)
                if is_inv:
                    orientation_corrected.append(page)

                for c in candidates:
                    self.candidates_by_id[c["id"]] = c
                    extracted_this_batch.append(c)
                    if c["is_possible_duplicate"]:
                        duplicates_count += 1
                    if c["ocr_evidence"]["requires_human_review"]:
                        flagged_count += 1

                pages_done.append(page)
                if page not in self.state["processed_pages"]:
                    self.state["processed_pages"].append(page)

            except Exception as exc:
                logger.error("Erro ao processar página digital %d: %s", page, exc)
                errors.append({"page": page, "error": str(exc)})
                if page not in self.state["failed_pages"]:
                    self.state["failed_pages"].append(page)

        conn.close()

        end_time = datetime.now(timezone.utc)
        duration = (end_time - start_time).total_seconds()

        self.state["last_processed_page"] = (
            max(pages_done) if pages_done else self.state["last_processed_page"]
        )

        report = BatchExecutionReport(
            batch_id=b_id,
            started_at=start_time.isoformat(),
            finished_at=end_time.isoformat(),
            start_page=start_page,
            end_page=end_page,
            pages_processed=pages_done,
            candidates_extracted_count=len(extracted_this_batch),
            unique_lemmas_count=len(
                set(c["lema_original"].lower() for c in extracted_this_batch)
            ),
            duplicates_detected_count=duplicates_count,
            flagged_for_human_review_count=flagged_count,
            orientation_corrected_pages=orientation_corrected,
            errors=errors,
            total_duration_seconds=round(duration, 3),
        )

        self.state["batches_history"].append(asdict(report))
        self._save_state()
        self._save_candidates()

        return report

    def get_inventory_summary(self) -> Dict[str, Any]:
        """Calcula o inventário quantitativo consolidado dos candidatos e estados."""
        total_cand = len(self.candidates_by_id)
        lemmas = set(c["lema_original"].lower() for c in self.candidates_by_id.values())
        status_counts = Counter(
            c["status_publicacao"] for c in self.candidates_by_id.values()
        )
        flagged = sum(
            1
            for c in self.candidates_by_id.values()
            if c["ocr_evidence"]["requires_human_review"]
        )
        pages_with_candidates = set(
            c["fonte"]["pagina_digital"] for c in self.candidates_by_id.values()
        )

        return {
            "total_candidates": total_cand,
            "unique_lemmas": len(lemmas),
            "status_distribution": dict(status_counts),
            "flagged_for_human_review": flagged,
            "pages_with_candidates_count": len(pages_with_candidates),
            "processed_pages_total": len(self.state.get("processed_pages", [])),
            "failed_pages_total": len(self.state.get("failed_pages", [])),
        }
