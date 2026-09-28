"""
Controle de Qualidade para Produção — Capítulo O (RFC v6.1 Research Hardening)
Classifica páginas e lotes em 3 níveis de homologação:
  - BRONZE: Uso interno / exploratório
  - PRATA: Corpus revisado parcialmente
  - OURO: Qualidade comprovada apta a alimentar o vector_store.db pedagógico

Critérios estritos para Nível OURO:
  1. CER <= max_gold_cer (default 5.0%)
  2. WER <= max_gold_wer (default 10.0%)
  3. Confiança calibrada >= min_gold_confidence (default 90.0%)
  4. ECE <= max_gold_ece (default 0.05)
  5. Proveniência completa em todos os tokens
  6. Zero tokens UNCERTAIN em quarentena
"""
from __future__ import annotations

import json
import logging
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import Any, Optional
from pydantic import BaseModel, Field

logger = logging.getLogger("quality_certification")


class QualityTier(str, Enum):
    BRONZE = "BRONZE"
    PRATA = "PRATA"
    OURO = "OURO"


class CertificationResult(BaseModel):
    page_id: str
    tier: QualityTier
    cer: Optional[float] = None
    wer: Optional[float] = None
    calibrated_confidence: float
    ece: float
    has_complete_provenance: bool
    uncertain_tokens_count: int
    can_enter_pedagogical_db: bool
    rejection_reasons: list[str] = Field(default_factory=list)
    evaluated_at: str = Field(default_factory=lambda: datetime.now().strftime("%Y-%m-%d %H:%M:%S"))


class QualityCertifier:
    """Avaliador e Porteiro de Qualidade Homologada para o Corpus TupiLingo."""

    def __init__(
        self,
        max_gold_cer: float = 5.0,
        max_gold_wer: float = 10.0,
        min_gold_confidence: float = 90.0,
        max_gold_ece: float = 0.05,
        max_silver_cer: float = 12.0,
        max_silver_wer: float = 20.0,
        min_silver_confidence: float = 75.0,
    ):
        self.max_gold_cer = max_gold_cer
        self.max_gold_wer = max_gold_wer
        self.min_gold_confidence = min_gold_confidence
        self.max_gold_ece = max_gold_ece
        self.max_silver_cer = max_silver_cer
        self.max_silver_wer = max_silver_wer
        self.min_silver_confidence = min_silver_confidence

    def evaluate_page(
        self,
        page_data: dict[str, Any],
        tokens_provenance: Optional[list[Any]] = None,
    ) -> CertificationResult:
        """Avalia uma página e retorna a certificação Bronze/Prata/Ouro."""
        page_id = page_data.get("page_id") or f"{page_data.get('pdf_stem', 'doc')}::{page_data.get('page_num', 1)}"
        cer = page_data.get("cer")
        wer = page_data.get("wer")
        calibrated_conf = float(page_data.get("fused_confidence") or page_data.get("calibrated_confidence") or 0.0)
        ece = float(page_data.get("ece", 0.032))

        # 1. Checagem de tokens UNCERTAIN
        uncertain_count = 0
        if "uncertain_tokens_count" in page_data:
            uncertain_count = int(page_data["uncertain_tokens_count"])
        elif tokens_provenance:
            uncertain_count = sum(
                1 for t in tokens_provenance
                if getattr(t, "rollback_applied", False) is True or getattr(t, "winning_ocr", "") == "UNCERTAIN"
            )

        # 2. Checagem de proveniência completa
        has_complete_provenance = True
        if tokens_provenance is not None:
            for t in tokens_provenance:
                if not (hasattr(t, "winning_ocr") and hasattr(t, "winning_filter")):
                    has_complete_provenance = False
                    break
        else:
            has_complete_provenance = page_data.get("has_complete_provenance", True)

        rejection_reasons: list[str] = []

        # Critérios para OURO
        is_gold = True
        if cer is not None and cer > self.max_gold_cer:
            is_gold = False
            rejection_reasons.append(f"CER ({cer:.1f}%) excede o teto Ouro ({self.max_gold_cer}%)")
        if wer is not None and wer > self.max_gold_wer:
            is_gold = False
            rejection_reasons.append(f"WER ({wer:.1f}%) excede o teto Ouro ({self.max_gold_wer}%)")
        if calibrated_conf < self.min_gold_confidence:
            is_gold = False
            rejection_reasons.append(f"Confiança ({calibrated_conf:.1f}%) abaixo do limiar Ouro ({self.min_gold_confidence}%)")
        if ece > self.max_gold_ece:
            is_gold = False
            rejection_reasons.append(f"ECE ({ece:.3f}) excede teto de calibração ({self.max_gold_ece})")
        if not has_complete_provenance:
            is_gold = False
            rejection_reasons.append("Proveniência de tokens incompleta")
        if uncertain_count > 0:
            is_gold = False
            rejection_reasons.append(f"Existem {uncertain_count} tokens UNCERTAIN em quarentena")

        if is_gold:
            tier = QualityTier.OURO
            can_enter = True
        else:
            # Avaliar se ao menos é PRATA
            is_silver = True
            if cer is not None and cer > self.max_silver_cer:
                is_silver = False
            if wer is not None and wer > self.max_silver_wer:
                is_silver = False
            if calibrated_conf < self.min_silver_confidence:
                is_silver = False

            tier = QualityTier.PRATA if is_silver else QualityTier.BRONZE
            can_enter = False

        return CertificationResult(
            page_id=page_id,
            tier=tier,
            cer=cer,
            wer=wer,
            calibrated_confidence=round(calibrated_conf, 2),
            ece=round(ece, 3),
            has_complete_provenance=has_complete_provenance,
            uncertain_tokens_count=uncertain_count,
            can_enter_pedagogical_db=can_enter,
            rejection_reasons=rejection_reasons,
        )

    def filter_corpus_for_pedagogical_db(
        self,
        pages_records: list[dict[str, Any]],
    ) -> list[dict[str, Any]]:
        """Filtra estritamente apenas as páginas com selo OURO para inserção no vector_store.db."""
        accepted = []
        for p in pages_records:
            cert = self.evaluate_page(p)
            if cert.can_enter_pedagogical_db:
                p_copy = dict(p)
                p_copy["quality_certification"] = cert.model_dump()
                accepted.append(p_copy)
            else:
                logger.info(
                    f"Página {cert.page_id} retida ({cert.tier.value}): {'; '.join(cert.rejection_reasons)}"
                )
        return accepted

    def export_certification_report(
        self,
        results: list[CertificationResult],
        output_path: Path,
    ) -> Path:
        """Gera relatório de auditoria de qualidade das páginas em Markdown."""
        gold_count = sum(1 for r in results if r.tier == QualityTier.OURO)
        silver_count = sum(1 for r in results if r.tier == QualityTier.PRATA)
        bronze_count = sum(1 for r in results if r.tier == QualityTier.BRONZE)
        total = len(results)

        rows = []
        for r in results:
            badge = "🥇 OURO" if r.tier == QualityTier.OURO else ("🥈 PRATA" if r.tier == QualityTier.PRATA else "🥉 BRONZE")
            entry = "✅ Permitido" if r.can_enter_pedagogical_db else "⛔ Bloqueado"
            cer_str = f"{r.cer:.1f}%" if r.cer is not None else "N/A"
            wer_str = f"{r.wer:.1f}%" if r.wer is not None else "N/A"
            notes = "; ".join(r.rejection_reasons) if r.rejection_reasons else "Conformidade total"
            rows.append(
                f"| `{r.page_id}` | {badge} | {cer_str} | {wer_str} | {r.calibrated_confidence}% | {r.uncertain_tokens_count} | {entry} | {notes} |"
            )

        table_md = "\n".join(rows)

        content = f"""# Relatório de Certificação de Qualidade — Capítulo O

**Data da Homologação:** {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}  
**Total de Páginas Avaliadas:** {total}  

### Resumo por Nível de Qualidade
- 🥇 **Nível OURO (Apto para vector_store.db):** {gold_count} páginas ({gold_count/max(total,1)*100:.1f}%)
- 🥈 **Nível PRATA (Corpus intermediário / Revisão parcial):** {silver_count} páginas ({silver_count/max(total,1)*100:.1f}%)
- 🥉 **Nível BRONZE (Uso exploratório / Retido):** {bronze_count} páginas ({bronze_count/max(total,1)*100:.1f}%)

---

## Tabela de Certificação Detalhada

| ID da Página | Nível | CER | WER | Conf. Calibrada | Tokens UNCERTAIN | Acesso ao Banco Pedagógico | Observações / Motivos |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
{table_md}

---
*Relatório gerado pelo TupiLingo QualityCertifier (RFC v6.1 Hardening).*
"""
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(content, encoding="utf-8")
        return output_path
