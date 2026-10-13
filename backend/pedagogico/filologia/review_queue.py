"""
Fila de Revisão Humana e Governança do Ciclo de Vida Filológico — TupiLingo.
Permite aos especialistas inspecionar, corrigir, aprovar, quarentenar ou rejeitar candidatos
extraídos pelo pipeline progressivo, mantendo trilha de auditoria estrita.
"""

from __future__ import annotations

import json
import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

from .models import (
    AuditLogEntry,
    BibliographicSource,
    InformationTier,
    LexicalEntry,
    OCREvidence,
    PhilologicalStatus,
    normalize_tupi,
)
from .progressive_extractor import ProgressiveNavarroExtractor, CANDIDATES_FILE

logger = logging.getLogger("pedagogico.filologia.review")


class PhilologicalReviewQueue:
    """Gerencia a fila de revisão humana de verbetes candidatos de Navarro."""

    def __init__(self, extractor: Optional[ProgressiveNavarroExtractor] = None):
        self.extractor = extractor or ProgressiveNavarroExtractor()

    def list_pending(
        self,
        limit: int = 20,
        offset: int = 0,
        flagged_only: bool = False,
        page_filter: Optional[int] = None,
    ) -> List[Dict[str, Any]]:
        """Lista candidatos pendentes de revisão humana com filtros de auditoria."""
        pending = []
        for c in self.extractor.candidates_by_id.values():
            if c["status_publicacao"] == PhilologicalStatus.AGUARDANDO_REVISAO.value:
                if flagged_only and not c["ocr_evidence"]["requires_human_review"]:
                    continue
                if page_filter is not None and c["fonte"]["pagina_digital"] != page_filter:
                    continue
                pending.append(c)

        # Ordena por prioridade: primeiro os com alertas de revisão humana
        pending.sort(
            key=lambda x: (
                not x["ocr_evidence"]["requires_human_review"],
                x["fonte"]["pagina_digital"],
                x["id"],
            )
        )
        return pending[offset : offset + limit]

    def count_pending(self, flagged_only: bool = False) -> int:
        count = 0
        for c in self.extractor.candidates_by_id.values():
            if c["status_publicacao"] == PhilologicalStatus.AGUARDANDO_REVISAO.value:
                if flagged_only and not c["ocr_evidence"]["requires_human_review"]:
                    continue
                count += 1
        return count

    def review_candidate(
        self,
        candidate_id: str,
        action: str,  # "approve", "quarantine", "reject", "correct"
        revisor: str,
        justificativa: str,
        overrides: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        Executa a revisão de um candidato pelo revisor humano.
        Registra imutavelmente a decisão no audit_history do registro.
        """
        candidate = self.extractor.candidates_by_id.get(candidate_id)
        if not candidate:
            # Recarrega do disco caso novos candidatos tenham sido registrados recentemente
            self.extractor.candidates_by_id = self.extractor._load_candidates()
            candidate = self.extractor.candidates_by_id.get(candidate_id)
        if not candidate:
            raise ValueError(f"Candidato {candidate_id} não encontrado.")

        overrides = overrides or {}
        prev_state = dict(candidate)
        prev_status = candidate["status_publicacao"]

        # Aplica correções nos campos textuais, se fornecidos pelo revisor
        if "lema_original" in overrides:
            candidate["lema_original"] = str(overrides["lema_original"]).strip()
            candidate["lema_normalizado"] = normalize_tupi(candidate["lema_original"])
        if "classe_gramatical" in overrides:
            candidate["classe_gramatical"] = str(overrides["classe_gramatical"]).strip()
        if "significado_extraido" in overrides:
            candidate["significado_extraido"] = str(overrides["significado_extraido"]).strip()
        if "variantes_documentadas" in overrides:
            candidate["variantes_documentadas"] = list(overrides["variantes_documentadas"])
        if "pagina_impressa" in overrides:
            candidate["fonte"]["pagina_impressa"] = int(overrides["pagina_impressa"])

        new_status = prev_status
        new_tier = candidate["tier"]
        aprovado = False

        if action == "approve":
            new_status = PhilologicalStatus.VALIDADO.value
            new_tier = InformationTier.TIER_A_TRANSCRICAO_LITERAL.value
            aprovado = True
            candidate["revisao"]["aprovado"] = True
            candidate["revisao"]["motivo_quarentena"] = None

        elif action == "quarantine":
            new_status = PhilologicalStatus.QUARENTENA.value
            new_tier = InformationTier.TIER_E_HIPOTESE_NAO_VERIFICADA.value
            aprovado = False
            candidate["revisao"]["aprovado"] = False
            candidate["revisao"]["motivo_quarentena"] = justificativa

        elif action == "reject":
            new_status = PhilologicalStatus.RETIRADO.value
            new_tier = InformationTier.TIER_E_HIPOTESE_NAO_VERIFICADA.value
            aprovado = False
            candidate["revisao"]["aprovado"] = False
            candidate["revisao"]["motivo_quarentena"] = f"Rejeitado: {justificativa}"

        elif action == "correct":
            # Permanece aguardando revisão final após correção
            new_status = PhilologicalStatus.AGUARDANDO_REVISAO.value
            aprovado = False

        else:
            raise ValueError(f"Ação de revisão desconhecida: '{action}'.")

        candidate["status_publicacao"] = new_status
        candidate["tier"] = new_tier
        candidate["revisao"]["revisado_por"] = revisor
        candidate["revisao"]["data_revisao"] = datetime.now(timezone.utc).isoformat()

        # Cria entrada no log de auditoria
        rev_count = len(candidate.get("audit_history", [])) + 1
        audit_entry = {
            "revision_id": f"REV-{candidate_id}-{rev_count:02d}",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "revisor": revisor,
            "valor_anterior": {"status": prev_status, "tier": prev_state["tier"]},
            "valor_revisado": {"status": new_status, "tier": new_tier, "overrides": overrides},
            "justificativa": justificativa,
            "aprovado": aprovado,
        }
        candidate.setdefault("audit_history", []).append(audit_entry)

        # Persiste candidatos atualizados
        self.extractor._save_candidates()

        return candidate

    def to_lexical_entry(self, candidate_dict: Dict[str, Any]) -> LexicalEntry:
        """Converte um dicionário de candidato para o modelo tipado LexicalEntry."""
        fonte_data = candidate_dict.get("fonte", {})
        ocr_data = candidate_dict.get("ocr_evidence", {})

        fonte = BibliographicSource(
            obra=fonte_data.get("obra", "Dicionário de Tupi Antigo"),
            autor=fonte_data.get("autor", "Eduardo de Almeida Navarro"),
            edicao=fonte_data.get("edicao", "1ª Edição"),
            ano=fonte_data.get("ano", 2013),
            editora=fonte_data.get("editora", "Global Editora"),
            local=fonte_data.get("local", "São Paulo"),
            pagina_impressa=fonte_data.get("pagina_impressa"),
            pagina_digital=fonte_data.get("pagina_digital"),
            verbete=candidate_dict["lema_original"],
            hash_documento=fonte_data.get("hash_documento", ""),
            arquivo_fonte=fonte_data.get("arquivo_fonte", ""),
            extrator_versao=fonte_data.get("extrator_versao", ""),
        )

        ocr_ev = OCREvidence(
            confidence_score=ocr_data.get("confidence_score", 1.0),
            extraction_method=ocr_data.get("extraction_method", "ocr"),
            requires_human_review=ocr_data.get("requires_human_review", False),
            is_orientation_corrected=ocr_data.get("is_orientation_corrected", False),
            suspicious_characters=ocr_data.get("suspicious_characters", []),
        )

        history = [
            AuditLogEntry(
                revision_id=ah.get("revision_id", ""),
                timestamp=ah.get("timestamp", ""),
                revisor=ah.get("revisor", ""),
                valor_anterior=ah.get("valor_anterior", {}),
                valor_revisado=ah.get("valor_revisado", {}),
                justificativa=ah.get("justificativa", ""),
                aprovado=ah.get("aprovado", False),
            )
            for ah in candidate_dict.get("audit_history", [])
        ]

        significados = [s.strip() for s in candidate_dict.get("significado_extraido", "").split(";") if s.strip()]

        return LexicalEntry(
            id=candidate_dict["id"],
            lema_original=candidate_dict["lema_original"],
            lema_normalizado=candidate_dict["lema_normalizado"],
            classe_gramatical=candidate_dict["classe_gramatical"],
            significados=significados or [candidate_dict.get("significado_extraido", "")],
            variantes_documentadas=candidate_dict.get("variantes_documentadas", []),
            status_publicacao=PhilologicalStatus(candidate_dict["status_publicacao"]),
            tier=InformationTier(candidate_dict["tier"]),
            fonte=fonte,
            ocr_evidence=ocr_ev,
            audit_history=history,
            revisao_responsavel=candidate_dict.get("revisao", {}).get("revisado_por"),
        )
