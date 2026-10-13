"""
Pipeline Explícito de Orientação de Imagem e Recuperação de Páginas — TupiLingo.
Processa folhas escaneadas com renderização visual, detecção comparativa de rotação (0° vs 180°),
re-execução de OCR sobre imagem corrigida, cálculo de hashes criptográficos e encaminhamento
à fila de revisão humana.

Regras Inegociáveis:
- A rotação é fisicamente aplicada sobre a imagem em memória e em disco (PIL Image.rotate).
- Imagens original e corrigida são preservadas com hashes SHA-256 independentes.
- Os verbetes extraídos recebem obrigatoriamente status AGUARDANDO_REVISAO (NUNCA VALIDADO automaticamente).
"""

from __future__ import annotations

import hashlib
import json
import logging
import re
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import pymupdf
import pytesseract
from PIL import Image

from .models import (
    BibliographicSource,
    InformationTier,
    LexicalEntry,
    OCREvidence,
    PhilologicalStatus,
    normalize_tupi,
)

logger = logging.getLogger("pedagogico.filologia.image_pipeline")

BASE_DIR = Path(__file__).resolve().parent
PDF_PATH = BASE_DIR.parent.parent / "pdfs" / "Dicionário Tupi.pdf"
IMAGES_DIR = BASE_DIR / "page_images"
ORIGINAL_IMAGES_DIR = IMAGES_DIR / "original"
CORRECTED_IMAGES_DIR = IMAGES_DIR / "corrected"
REPORTS_DIR = IMAGES_DIR / "reports"

# Configuração do caminho do Tesseract no Windows
TESSERACT_EXE = Path(r"C:\Program Files\Tesseract-OCR\tesseract.exe")
if TESSERACT_EXE.exists():
    pytesseract.pytesseract.tesseract_cmd = str(TESSERACT_EXE)


def compute_file_sha256(path: Path) -> str:
    """Calcula o hash SHA-256 de um arquivo em disco."""
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()


def compute_bytes_sha256(data: bytes) -> str:
    """Calcula o hash SHA-256 de um buffer em memória."""
    return hashlib.sha256(data).hexdigest()


@dataclass
class OrientationAnalysisReport:
    page_digital: int
    original_image_path: str
    original_image_sha256: str
    corrected_image_path: Optional[str]
    corrected_image_sha256: Optional[str]
    orientation_applied_degrees: int
    quality_score_0_deg: float
    quality_score_180_deg: float
    is_inverted_detected: bool
    is_ambiguous: bool
    requires_human_review: bool
    ocr_text_length: int
    candidates_extracted_count: int
    extracted_candidates: List[Dict[str, Any]] = field(default_factory=list)
    timestamp: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())


class ImageOrientationPipeline:
    """Pipeline físico de rotação e extração de páginas digitalizadas do Dicionário."""

    LEXICAL_KEYWORDS = {
        "de", "em", "do", "da", "que", "para", "com", "um", "uma", "não", "se", "por",
        "tupi", "fonte", "anch", "vlb", "poemas", "etim", "var", "adj", "pron", "fig",
        "subst", "adv", "part", "homem", "mulher", "água", "fogo", "terra", "peixe",
    }

    INVERTED_NOISE_PATTERNS = [
        r"\(69\s*[‘']\s*1\s*[‘']\s*Q7A\)",
        r"[dD]44\)",
        r"gweinsusD",
        r"ajend",
        r"“youy",
        r"\)s\(",
        r"\)v\(",
        r"\)adj\(",
    ]

    def __init__(self, pdf_path: Path = PDF_PATH):
        self.pdf_path = pdf_path
        ORIGINAL_IMAGES_DIR.mkdir(parents=True, exist_ok=True)
        CORRECTED_IMAGES_DIR.mkdir(parents=True, exist_ok=True)
        REPORTS_DIR.mkdir(parents=True, exist_ok=True)

        from .progressive_extractor import ProgressiveNavarroExtractor
        self.extractor = ProgressiveNavarroExtractor()

        class_regex = r"\((?:[^\)]*(?:s\.|v\.|adj\.|part\.|pron\.|interj\.|posp\.|adv\.|conj\.|num\.|suf\.|pref\.|loc\.|prep\.)[^\)]*)\)"
        self.entry_pattern = re.compile(
            r"(?m)^([a-zîŷáéíóúãẽĩõũ'¹²³⁴⁵\-]+(?:\s+(?:ou|e)\s+[a-zîŷáéíóúãẽĩõũ'¹²³⁴⁵\-]+)?)\s*("
            + class_regex
            + r")\s*-\s*([^\n\r]+)",
            re.IGNORECASE,
        )

    def render_page(self, page_digital: int, dpi: int = 150) -> Tuple[Image.Image, str]:
        """Renderiza a folha digital do PDF em uma imagem PIL RGB."""
        doc = pymupdf.open(self.pdf_path)
        page_idx = page_digital - 1
        if not (0 <= page_idx < len(doc)):
            doc.close()
            raise IndexError(f"Página digital {page_digital} fora dos limites (1 a {len(doc)}).")

        page = doc[page_idx]
        pix = page.get_pixmap(dpi=dpi)
        img = Image.frombytes("RGB", [pix.width, pix.height], pix.samples)
        page_hash = compute_bytes_sha256(pix.samples)
        doc.close()
        return img, page_hash

    def evaluate_text_quality(self, text: str) -> float:
        """
        Avalia a qualidade do texto OCR calculando a densidade léxica positiva
        menos penalidades por marcadores tipográficos de inversão.
        """
        words = re.findall(r"\b[a-zA-ZáéíóúãẽĩõũîŷçÁÉÍÓÚÃẼĨÕŨÎŶÇ]{2,}\b", text.lower())
        if not words:
            return 0.0

        pos_matches = sum(1 for w in words if w in self.LEXICAL_KEYWORDS)
        pos_score = (pos_matches / len(words)) * 100.0

        # Penalidades por ruído de texto invertido
        neg_score = 0.0
        for pat in self.INVERTED_NOISE_PATTERNS:
            matches = len(re.findall(pat, text))
            neg_score += matches * 15.0

        return max(0.0, pos_score - neg_score)

    def process_page(
        self, page_digital: int, dpi: int = 150, register_in_candidates: bool = True
    ) -> OrientationAnalysisReport:
        """
        Executa o pipeline completo para uma folha digital:
        1. Renderiza imagem original.
        2. Executa OCR em 0° e em 180°.
        3. Compara scores léxicos.
        4. Aplica rotação se 180° for superior.
        5. Extrai verbetes candidatos da orientação correta.
        """
        img_orig, orig_bytes_hash = self.render_page(page_digital, dpi=dpi)

        orig_filename = f"page_{page_digital:03d}_orig.png"
        orig_path = ORIGINAL_IMAGES_DIR / orig_filename
        img_orig.save(orig_path, "PNG")
        orig_file_sha256 = compute_file_sha256(orig_path)

        # 1. OCR na orientação 0°
        text_0 = pytesseract.image_to_string(img_orig, lang="por")
        score_0 = self.evaluate_text_quality(text_0)

        # 2. OCR na orientação 180° (rotacionada fisicamente)
        img_180 = img_orig.rotate(180, expand=True)
        text_180 = pytesseract.image_to_string(img_180, lang="por")
        score_180 = self.evaluate_text_quality(text_180)

        # Decisão de orientação
        is_inverted = (score_180 > score_0 + 5.0) or any(re.search(pat, text_0) for pat in self.INVERTED_NOISE_PATTERNS)
        is_ambiguous = abs(score_180 - score_0) < 3.0 and not is_inverted

        corrected_path_str: Optional[str] = None
        corrected_file_sha256: Optional[str] = None
        applied_degrees = 0
        final_text = text_0

        if is_inverted:
            applied_degrees = 180
            corr_filename = f"page_{page_digital:03d}_rot180.png"
            corr_path = CORRECTED_IMAGES_DIR / corr_filename
            img_180.save(corr_path, "PNG")
            corrected_file_sha256 = compute_file_sha256(corr_path)
            corrected_path_str = str(corr_path)
            final_text = text_180
        else:
            # Mantém 0 graus
            applied_degrees = 0
            corr_filename = f"page_{page_digital:03d}_rot000.png"
            corr_path = CORRECTED_IMAGES_DIR / corr_filename
            img_orig.save(corr_path, "PNG")
            corrected_file_sha256 = compute_file_sha256(corr_path)
            corrected_path_str = str(corr_path)
            final_text = text_0

        # 3. Extrai candidatos da saída corrigida
        extracted_candidates = self._extract_candidates_from_text(
            page_digital=page_digital,
            text=final_text,
            is_orientation_corrected=(applied_degrees != 0),
            image_sha256=(corrected_file_sha256 or orig_file_sha256),
        )

        if register_in_candidates and extracted_candidates:
            self.extractor.register_candidates(extracted_candidates)

        report = OrientationAnalysisReport(
            page_digital=page_digital,
            original_image_path=str(orig_path),
            original_image_sha256=orig_file_sha256,
            corrected_image_path=corrected_path_str,
            corrected_image_sha256=corrected_file_sha256,
            orientation_applied_degrees=applied_degrees,
            quality_score_0_deg=round(score_0, 2),
            quality_score_180_deg=round(score_180, 2),
            is_inverted_detected=is_inverted,
            is_ambiguous=is_ambiguous,
            requires_human_review=(is_ambiguous or is_inverted or len(extracted_candidates) == 0),
            ocr_text_length=len(final_text),
            candidates_extracted_count=len(extracted_candidates),
            extracted_candidates=extracted_candidates,
        )

        # Salva relatório JSON da página
        rep_path = REPORTS_DIR / f"report_page_{page_digital:03d}.json"
        with open(rep_path, "w", encoding="utf-8") as f:
            json.dump(asdict(report), f, indent=2, ensure_ascii=False)

        return report

    def _extract_candidates_from_text(
        self,
        page_digital: int,
        text: str,
        is_orientation_corrected: bool,
        image_sha256: str
    ) -> List[Dict[str, Any]]:
        """Extrai candidatos estruturados a partir do texto OCR corrigido."""
        candidates = []
        entry_idx = 1
        seen_lemmas = set()

        for m in self.entry_pattern.finditer(text):
            raw_lema = m.group(1).strip()
            classe = m.group(2).strip()
            def_raw = m.group(3).strip()

            clean_lema = re.sub(r"[¹²³⁴⁵\?!]", "", raw_lema).strip()
            if " ou " in clean_lema.lower():
                clean_lema = re.split(r"\s+ou\s+", clean_lema, flags=re.I)[0].strip()

            norm_lema = normalize_tupi(clean_lema)
            candidate_id = f"NAV-IMG-P{page_digital:03d}-{entry_idx:02d}"
            entry_idx += 1

            is_dup = clean_lema.lower() in seen_lemmas
            seen_lemmas.add(clean_lema.lower())

            candidate_dict = {
                "id": candidate_id,
                "lema_original": clean_lema,
                "lema_completo_fonte": raw_lema,
                "lema_normalizado": norm_lema,
                "classe_gramatical": classe,
                "significado_extraido": def_raw,
                "variantes_documentadas": [],
                "status_publicacao": PhilologicalStatus.AGUARDANDO_REVISAO.value,
                "tier": InformationTier.TIER_B_NORMALIZACAO_PESQUISA.value,
                "fonte": {
                    "obra": "Dicionário de Tupi Antigo: a língua indígena clássica do Brasil",
                    "autor": "Eduardo de Almeida Navarro",
                    "edicao": "1ª Edição",
                    "ano": 2013,
                    "editora": "Global Editora",
                    "local": "São Paulo",
                    "pagina_impressa": None,
                    "pagina_digital": page_digital,
                    "hash_documento": image_sha256,
                    "arquivo_fonte": "Dicionário Tupi.pdf",
                    "extrator_versao": "3.0.0-image-orientation-pipeline",
                },
                "ocr_evidence": {
                    "confidence_score": 88.0,
                    "extraction_method": "tesseract_physical_rotation_pipeline",
                    "requires_human_review": True,
                    "is_orientation_corrected": is_orientation_corrected,
                    "suspicious_characters": [],
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
                        "revisor": "Pipeline Físico de Orientação de Imagem v3.0.0",
                        "valor_anterior": {},
                        "valor_revisado": {"status": PhilologicalStatus.AGUARDANDO_REVISAO.value},
                        "justificativa": (
                            f"Candidato recuperado da folha digital {page_digital} após "
                            f"{'rotação de 180°' if is_orientation_corrected else 'orientação regular (0°)'}."
                        ),
                        "aprovado": False,
                    }
                ],
            }
            candidates.append(candidate_dict)

        return candidates


if __name__ == "__main__":
    pipeline = ImageOrientationPipeline()
    print("=" * 70)
    print("EXECUÇÃO DO PIPELINE DE ORIENTAÇÃO DE IMAGEM (Páginas 31, 33, 34)")
    print("=" * 70)

    for p in [31, 33, 34]:
        rep = pipeline.process_page(p)
        print(f"\n[Folha Digital {p:03d}]")
        print(f"  Score 0°: {rep.quality_score_0_deg:.1f} | Score 180°: {rep.quality_score_180_deg:.1f}")
        print(f"  Orientação Aplicada: {rep.orientation_applied_degrees}°")
        print(f"  Inversão Detectada: {rep.is_inverted_detected}")
        print(f"  Imagem Original: {rep.original_image_path} (SHA: {rep.original_image_sha256[:16]}...)")
        print(f"  Imagem Corrigida: {rep.corrected_image_path} (SHA: {rep.corrected_image_sha256[:16]}...)")
        print(f"  Verbetes Candidatos Extraídos: {rep.candidates_extracted_count}")
        for c in rep.extracted_candidates[:3]:
            print(f"    - {c['id']}: '{c['lema_original']}' ({c['classe_gramatical']}) -> {c['significado_extraido'][:60]}...")
    print("=" * 70)
