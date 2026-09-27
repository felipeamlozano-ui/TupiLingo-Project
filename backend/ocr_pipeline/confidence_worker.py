"""
Worker de Grafo de Confiança Simplificado e Auditoria Completa (Etapas 10 e 12 da Fase 1).
Calcula score composto multidimensional integrando:
  1. Confiança bruta dos motores de OCR.
  2. Taxa de concordância inter-motores (Tesseract vs RapidOCR).
  3. Checagem determinística de sanidade linguística e ausência de ruído.
"""
import re
from typing import Any

from .models import PageAuditRecord


class ConfidenceWorker:
    def __init__(self, min_char_threshold: int = 80):
        self.min_char_threshold = min_char_threshold

    def check_sanity(self, text: str) -> tuple[bool, str, float]:
        """
        Aplica as checagens determinísticas de sanidade do TupiLingo.
        Retorna: (is_valido, motivo_falha, score_sanidade 0-100)
        """
        if not text or len(text.strip()) < self.min_char_threshold:
            return False, "comprimento_insuficiente", 30.0

        # 1. Checagem de pontilhados de sumário excessivos
        if re.search(r"\.{6,}", text):
            return False, "sumario_pontilhado", 50.0

        # 2. Checagem de proporção de caracteres não-alfabéticos
        total_chars = len(text)
        alpha_chars = len(re.findall(r"[a-zA-ZáéíóúÁÉÍÓÚãõÃÕâêîôûÂÊÎÔÛẽĩỹẼĨỸçÇ'-]", text))
        alpha_ratio = alpha_chars / max(total_chars, 1)
        if alpha_ratio < 0.45:
            return False, "excesso_caracteres_nao_alfabeticos", 40.0

        # 3. Checagem de proporção mínima de vogais (evita lixo de OCR tipo "bxcvdfgh")
        vowels = len(re.findall(r"[aeiouyáéíóúãõâêîôûẽĩỹAEIOUYÁÉÍÓÚÃÕÂÊÎÔÛẼĨỸ]", text, flags=re.IGNORECASE))
        vowel_ratio = vowels / max(alpha_chars, 1)
        if vowel_ratio < 0.18:
            return False, "ruido_ocr_sem_vogais", 35.0

        # 4. Sequências repetitivas anômalas (ex: "nnnnn", "|||||")
        if re.search(r"(\w)\1{5,}", text):
            return False, "sequencia_repetitiva_anomala", 45.0

        # Texto válido
        sanity_score = min(100.0, 70.0 + (alpha_ratio * 20.0) + (vowel_ratio * 10.0))
        return True, "valido", round(sanity_score, 2)

    def compute_composite_confidence(
        self,
        ocr_confidence: float,
        agreement_rate: float,
        text: str
    ) -> tuple[float, bool, str, dict[str, Any]]:
        """
        Gera o score de confiança composto da Etapa 10 simplificada.
        Pesos:
          - 55% Confiança direta dos motores de OCR
          - 25% Taxa de concordância entre Tesseract e RapidOCR
          - 20% Sanidade determinística do texto resultante
        """
        is_valido, sanity_reason, sanity_score = self.check_sanity(text)
        agreement_score = agreement_rate * 100.0

        composite = (
            0.55 * ocr_confidence +
            0.25 * agreement_score +
            0.20 * sanity_score
        )

        # Se falhar na sanidade determinística, penaliza e marca para revisão
        needs_review = False
        if not is_valido or composite < 75.0:
            needs_review = True
            composite = min(composite, 84.0)

        composite = round(float(min(100.0, max(0.0, composite))), 2)

        details = {
            "ocr_confidence_raw": ocr_confidence,
            "engine_agreement_score": round(agreement_score, 2),
            "sanity_score": sanity_score,
            "sanity_reason": sanity_reason,
            "composite_confidence": composite,
            "needs_review": needs_review
        }
        return composite, needs_review, sanity_reason, details

    def build_audit_record(
        self,
        filename: str,
        page_num: int,
        quality_score: float,
        routing_decision: str,
        preprocessing_applied: list,
        engine_used: str,
        confidence_before: float,
        confidence_after: float,
        agreement_rate: float,
        lexical_corrections_count: int,
        dictionary_entries_found: int,
        chunks_generated: int,
        needs_manual_review: bool,
        sanity_status: str,
        elapsed_seconds: float
    ) -> PageAuditRecord:
        """Gera o artefato de auditoria da página (Etapa 12)."""
        return PageAuditRecord(
            filename=filename,
            page_num=page_num,
            quality_score=round(quality_score, 2),
            routing_decision=routing_decision,
            preprocessing_applied=preprocessing_applied,
            engine_used=engine_used,
            confidence_before=round(confidence_before, 2) if confidence_before else None,
            confidence_after=round(confidence_after, 2),
            agreement_rate=round(agreement_rate, 4),
            lexical_corrections_count=lexical_corrections_count,
            dictionary_entries_found=dictionary_entries_found,
            chunks_generated=chunks_generated,
            needs_manual_review=needs_manual_review,
            sanity_status=sanity_status,
            elapsed_seconds=round(elapsed_seconds, 3)
        )
