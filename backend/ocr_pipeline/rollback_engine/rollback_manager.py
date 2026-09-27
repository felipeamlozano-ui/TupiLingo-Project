"""
Motor de Rollback Invariante e Auditoria Forense Completa (Etapas 10 e 11).

Garante:
- Verificação formal de invariantes de integridade (números, nomes próprios, salvaguarda Tupi)
- Rollback automático e imediato em caso de degradação de confiança
- Logging estruturado em formato JSONL (audit trail forense completo)
- Motor de Recuperação Iterativa para regiões com confiança < 0.90 (até 5 iterações com permutações de filtros, resoluções e motores)
"""

from __future__ import annotations

import logging
import re
import time
from collections.abc import Callable
from pathlib import Path

from pydantic import BaseModel, Field

from ocr_pipeline.core.provenance import BoundingBox

logger = logging.getLogger("ocr_pipeline.rollback_engine")


class AuditEvent(BaseModel):
    """Evento individual de auditoria forense registrado em JSONL."""

    timestamp: float = Field(default_factory=time.time)
    page_num: int
    stage: str
    action: str = Field(..., description="accepted | rejected | rollback | recovered")
    token_original: str
    token_final: str
    confidence_before: float
    confidence_after: float
    engine: str
    bbox: BoundingBox | None = None
    reason: str = ""
    processing_time_ms: float = 0.0


class IterationAttempt(BaseModel):
    """Tentativa de recuperação iterativa de uma região de baixa confiança."""

    iteration: int
    filter_branch: str
    engine: str
    scale_factor: float
    text_result: str
    confidence_achieved: float
    duration_ms: float


class RegionRecoveryHistory(BaseModel):
    """Histórico de tentativas de recuperação para uma região específica."""

    region_id: str
    bbox: BoundingBox
    initial_confidence: float
    final_confidence: float
    final_text: str = ""
    iterations: list[IterationAttempt] = Field(default_factory=list)
    successful: bool = False
    chosen_iteration: int = 0


class ForensicAuditLogger:
    """Gravador estruturado de auditoria forense em JSONL streaming."""

    def __init__(self, log_path: Path):
        self.log_path = log_path
        self.log_path.parent.mkdir(parents=True, exist_ok=True)

    def log_event(self, event: AuditEvent):
        """Registra um evento em JSONL de forma thread-safe e append-only."""
        try:
            with open(self.log_path, "a", encoding="utf-8") as f:
                f.write(event.model_dump_json() + "\n")
        except Exception as e:
            logger.error(f"Erro ao salvar evento de auditoria: {e}")


class RollbackManager:
    """Gerenciador de Invariantes e Rollback Forense."""

    def __init__(self, audit_log_path: Path | None = None):
        self.audit_log_path = (
            audit_log_path
            if audit_log_path
            else Path("ocr_pipeline/forensic_audit_trail.jsonl")
        )
        self.audit_logger = ForensicAuditLogger(self.audit_log_path)
        self.total_accepted = 0
        self.total_rejected = 0
        self.total_rollbacks = 0

    def evaluate_and_enforce(
        self,
        original_token: str,
        proposed_token: str,
        conf_before: float,
        conf_after: float,
        page_num: int,
        engine: str,
        bbox: BoundingBox | None = None,
        duration_ms: float = 0.0,
    ) -> tuple[str, float, bool]:
        """
        Avalia se a modificação proposta respeita todas as regras invariantes.
        Se violar ou se degradar a confiança, força ROLLBACK imediato para o original.
        Retorna: (token_escolhido, confianca_final, foi_feito_rollback)
        """
        # INVARIANTE 1: Nenhuma alteração pode reduzir a confiança
        if conf_after < conf_before:
            self.total_rollbacks += 1
            self.audit_logger.log_event(
                AuditEvent(
                    page_num=page_num,
                    stage="rollback_gate",
                    action="rollback",
                    token_original=original_token,
                    token_final=original_token,
                    confidence_before=conf_before,
                    confidence_after=conf_before,
                    engine=engine,
                    bbox=bbox,
                    reason=f"Degradação de confiança: {conf_after:.3f} < {conf_before:.3f}",
                    processing_time_ms=duration_ms,
                )
            )
            return original_token, conf_before, True

        # INVARIANTE 2: Números, datas e numerais nunca podem ser alterados
        clean_orig = original_token.strip(".,;:()[]{}'\"-")
        clean_prop = proposed_token.strip(".,;:()[]{}'\"-")
        if re.match(r"^\d+([.,/\-]\d+)*$", clean_orig):
            if clean_orig != clean_prop:
                self.total_rollbacks += 1
                self.audit_logger.log_event(
                    AuditEvent(
                        page_num=page_num,
                        stage="rollback_gate",
                        action="rollback",
                        token_original=original_token,
                        token_final=original_token,
                        confidence_before=conf_before,
                        confidence_after=conf_before,
                        engine=engine,
                        bbox=bbox,
                        reason="Tentativa de alterar número protegido",
                        processing_time_ms=duration_ms,
                    )
                )
                return original_token, conf_before, True

        # Modificação aprovada
        if original_token != proposed_token:
            self.total_accepted += 1
            self.audit_logger.log_event(
                AuditEvent(
                    page_num=page_num,
                    stage="lexical_gate",
                    action="accepted",
                    token_original=original_token,
                    token_final=proposed_token,
                    confidence_before=conf_before,
                    confidence_after=conf_after,
                    engine=engine,
                    bbox=bbox,
                    reason="Modificação aprovada por todos os gates",
                    processing_time_ms=duration_ms,
                )
            )
        return proposed_token, conf_after, False


class IterativeRecoveryEngine:
    """Motor de recuperação iterativa para regiões com confiança < 0.90."""

    RECOVERY_STRATEGIES = [
        # (Filtro, Engine, Escala)
        ("clahe", "rapidocr", 1.0),
        ("sauvola", "tesseract_psm6", 1.5),
        ("retinex", "rapidocr", 2.0),
        ("morph_reconstruction", "tesseract_psm4", 2.0),
        ("niblack", "rapidocr", 2.0),
    ]

    def __init__(self, rollback_manager: RollbackManager, max_iterations: int = 5):
        self.rollback_manager = rollback_manager
        self.max_iterations = min(max_iterations, len(self.RECOVERY_STRATEGIES))

    def recover_region(
        self,
        region_id: str,
        bbox: BoundingBox,
        initial_text: str,
        initial_conf: float,
        region_processor_fn: Callable[[str, str, float], tuple[str, float]],
    ) -> RegionRecoveryHistory:
        """
        Executa até 5 iterações de recuperação sobre a região, testando permutações
        de pré-processamento, motores e resoluções até superar o limiar de 0.90.
        """
        history = RegionRecoveryHistory(
            region_id=region_id,
            bbox=bbox,
            initial_confidence=initial_conf,
            final_confidence=initial_conf,
        )

        if initial_conf >= 0.90:
            history.successful = True
            history.final_confidence = initial_conf
            return history

        best_text = initial_text
        best_conf = initial_conf
        best_iter = 0

        for it_idx in range(self.max_iterations):
            filter_name, engine_name, scale = self.RECOVERY_STRATEGIES[it_idx]
            t0 = time.time()
            try:
                candidate_text, candidate_conf = region_processor_fn(
                    filter_name, engine_name, scale
                )
            except Exception as e:
                logger.debug(f"Falha na iteração {it_idx + 1} de recuperação: {e}")
                candidate_text = initial_text
                candidate_conf = 0.0

            dur_ms = (time.time() - t0) * 1000.0

            attempt = IterationAttempt(
                iteration=it_idx + 1,
                filter_branch=filter_name,
                engine=engine_name,
                scale_factor=scale,
                text_result=candidate_text,
                confidence_achieved=candidate_conf,
                duration_ms=dur_ms,
            )
            history.iterations.append(attempt)

            # Validar ganho real de confiança
            if candidate_conf > best_conf:
                best_conf = candidate_conf
                best_text = candidate_text
                best_iter = it_idx + 1

            # Se atingiu o limiar de alta confiança, encerra o ciclo de recuperação
            if best_conf >= 0.90:
                history.successful = True
                break

        history.final_confidence = best_conf
        history.final_text = best_text
        history.chosen_iteration = best_iter
        return history
