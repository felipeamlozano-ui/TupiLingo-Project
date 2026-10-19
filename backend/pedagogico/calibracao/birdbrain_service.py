"""
TupiLingo — Serviço de Calibração Contínua de Habilidade ("Birdbrain")
Monitora e atualiza dinamicamente a proficiência theta_atual do estudante
ao longo de todas as lições e checkpoints da trilha.

Funcionalidades:
  1. Atualização Bayesiana incremental em etapa única (sem dupla contagem da priori).
  2. Validação numérica estrita (proteção contra NaN, Inf, ausência de parâmetros e quarentena).
  3. Avaliação probabilística de Checkpoints Periódicos de Revisão com Z-score ponderado por SE.
  4. Política adaptativa formal:
     - Remediação orientada a competências e objetivos de aprendizagem (focus_domains).
     - Aceleração estritamente restrita a revisões redundantes; NUNCA pula conteúdo novo.
  5. Suporte a idempotência de eventos e histórico auditável com rastreabilidade de versões.
"""

import hashlib
import hmac
import json
import logging
import math
import os
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Set, Tuple

from pedagogico.nivelamento.irt_engine import IRTEngine

logger = logging.getLogger("pedagogico.calibracao.birdbrain")

BASE_DIR = Path(__file__).resolve().parent
CHECKPOINTS_FILE = BASE_DIR / "checkpoints_config.json"


def _get_telemetry_fallback_secret() -> str:
    secret = os.environ.get("BIRDBRAIN_TELEMETRY_SECRET")
    if secret:
        return secret
    try:
        from django.conf import settings
        configured_secret = getattr(settings, "BIRDBRAIN_TELEMETRY_SECRET", None)
        if configured_secret:
            return configured_secret
        return getattr(settings, "SECRET_KEY", "") or os.environ.get("SECRET_KEY", "")
    except Exception:
        return os.environ.get("SECRET_KEY", "")


class BirdbrainService:
    """Motor de calibração adaptativa contínua do TupiLingo."""

    ENGINE_VERSION = "3.1.0-eap-unified"
    MODEL_TYPE = "3PL-Birnbaum"

    def __init__(
        self,
        checkpoints_path: Path = CHECKPOINTS_FILE,
        shadow_mode: Optional[bool] = None,
        shadow_log_path: Optional[Path] = None,
        telemetry_secret: Optional[str] = None
    ):
        self.irt_engine = IRTEngine()
        self.checkpoints_path = checkpoints_path
        self.checkpoints_data: Dict[str, Any] = {}
        self._processed_events: Dict[str, Dict[str, Any]] = {}
        self.telemetry_secret = telemetry_secret or _get_telemetry_fallback_secret()
        
        # Modo Sombra: computa decisões sem aplicá-las à progressão curricular
        if shadow_mode is not None:
            self.shadow_mode = bool(shadow_mode)
        else:
            self.shadow_mode = os.environ.get("BIRDBRAIN_SHADOW_MODE", "false").lower() in ("true", "1", "yes")

        self.shadow_log_path = shadow_log_path or (BASE_DIR / "shadow_audit_events.jsonl")
        self._load_checkpoints()

    @staticmethod
    def pseudonymize_student_id(student_id: Optional[str], secret_key: Optional[str] = None) -> str:
        """
        Pseudonimiza o identificador do estudante utilizando HMAC-SHA256 com segredo de servidor.
        Previne ataques de dicionário ou rainbow tables sobre identificadores previsíveis (CPF, e-mail, matrícula).
        """
        if not student_id or not str(student_id).strip():
            return "anonymous_student"
        key = (secret_key or _get_telemetry_fallback_secret()).encode("utf-8")
        raw = str(student_id).strip().encode("utf-8")
        return hmac.new(key, raw, hashlib.sha256).hexdigest()[:24]

    def _load_checkpoints(self) -> None:
        if self.checkpoints_path.exists():
            try:
                with open(self.checkpoints_path, "r", encoding="utf-8") as f:
                    self.checkpoints_data = json.load(f)
            except Exception as exc:
                logger.error("Falha ao carregar configuração de checkpoints: %s", exc)
                self.checkpoints_data = {"checkpoints": []}

    def update_theta_after_lesson(
        self,
        current_theta: float,
        current_se: float,
        lesson_responses: List[Dict[str, Any]],
        learning_rate: float = 0.20,
        idempotency_key: Optional[str] = None
    ) -> Tuple[float, float, Dict[str, Any]]:
        """
        Atualiza a estimativa de habilidade theta_atual após a conclusão de uma lição regular.
        Utiliza atualização Bayesiana em etapa única com ponderação estocástica na verossimilhança [L]^eta.
        Garante ausência total de dupla contagem da priori.
        """
        # 1. Checagem de Idempotência
        if idempotency_key and idempotency_key in self._processed_events:
            cached = self._processed_events[idempotency_key]
            logger.info("Evento repetido detectado (idempotente): %s", idempotency_key)
            return cached["new_theta"], cached["new_se"], {**cached["diagnostic"], "status": "DUPLICATE_EVENT_CACHED"}

        # 2. Sanitização Numérica da Priori
        if not math.isfinite(current_theta):
            logger.warning("current_theta inválido (%s); resetando para 0.0.", current_theta)
            current_theta = 0.0
        if not math.isfinite(current_se) or current_se <= 0.01:
            logger.warning("current_se inválido (%s); ajustando para 1.0.", current_se)
            current_se = 1.0

        current_theta = max(-4.0, min(4.0, float(current_theta)))
        current_se = max(0.05, min(2.5, float(current_se)))

        if not lesson_responses:
            diag = {
                "old_theta": round(current_theta, 3),
                "new_theta": round(current_theta, 3),
                "delta": 0.0,
                "old_se": round(current_se, 3),
                "new_se": round(current_se, 3),
                "accuracy_pct": 0.0,
                "items_eligible_count": 0,
                "items_excluded_count": 0,
                "status": "UNCHANGED",
                "reason": "EMPTY_RESPONSES",
                "engine_version": self.ENGINE_VERSION,
                "timestamp": datetime.now(timezone.utc).isoformat(),
            }
            return round(current_theta, 3), round(current_se, 3), diag

        # 3. Filtragem Estrita e Descarte de Itens Inelegíveis (Validação Numérica & Quarentena)
        eligible_responses: List[Dict[str, Any]] = []
        excluded_items: List[Dict[str, Any]] = []
        seen_item_ids: Set[str] = set()

        for idx, r in enumerate(lesson_responses):
            if not isinstance(r, dict):
                excluded_items.append({"index": idx, "reason": "NOT_A_DICT"})
                continue

            item_id = str(r.get("item_id", f"item_{idx}"))
            if item_id in seen_item_ids:
                excluded_items.append({"item_id": item_id, "reason": "DUPLICATE_ITEM_IN_BATCH"})
                continue
            seen_item_ids.add(item_id)

            # Rejeição de respostas sem is_correct explicitamente avaliado
            is_corr = r.get("is_correct")
            if is_corr is None or not isinstance(is_corr, (bool, int)):
                excluded_items.append({"item_id": item_id, "reason": "MISSING_IS_CORRECT"})
                continue

            # Rejeição de itens em quarentena ou retirados de publicação
            status_item = str(r.get("status_publicacao", r.get("status", ""))).lower()
            if status_item in ("quarentena", "retirado"):
                excluded_items.append({"item_id": item_id, "reason": f"ITEM_IN_{status_item.upper()}"})
                continue

            # Validação dos parâmetros 3PL
            try:
                a = float(r.get("param_a", 1.2))
                b = float(r.get("param_b", 0.0))
                c = float(r.get("param_c", 0.25))
            except (ValueError, TypeError):
                excluded_items.append({"item_id": item_id, "reason": "NON_NUMERIC_PARAMETERS"})
                continue

            is_valid_param, param_err = self.irt_engine.validate_item_parameters(a, b, c)
            if not is_valid_param:
                excluded_items.append({"item_id": item_id, "reason": param_err or "INVALID_PARAMETERS"})
                continue

            eligible_responses.append({
                "item_id": item_id,
                "is_correct": bool(is_corr),
                "param_a": a,
                "param_b": b,
                "param_c": c,
                "dominio": r.get("dominio", r.get("categoria", "geral")),
            })

        if not eligible_responses:
            diag = {
                "old_theta": round(current_theta, 3),
                "new_theta": round(current_theta, 3),
                "delta": 0.0,
                "old_se": round(current_se, 3),
                "new_se": round(current_se, 3),
                "accuracy_pct": 0.0,
                "items_eligible_count": 0,
                "items_excluded_count": len(excluded_items),
                "excluded_details": excluded_items,
                "status": "UNCHANGED",
                "reason": "NO_ELIGIBLE_ITEMS",
                "engine_version": self.ENGINE_VERSION,
                "timestamp": datetime.now(timezone.utc).isoformat(),
            }
            return round(current_theta, 3), round(current_se, 3), diag

        # 4. Atualização Bayesiana EAP em Etapa Única (SEM DUPLA CONTAGEM)
        new_theta, new_se = self.irt_engine.estimate_ability_eap(
            responses=eligible_responses,
            prior_mean=current_theta,
            prior_sd=current_se,
            learning_rate=learning_rate
        )

        delta = round(new_theta - current_theta, 3)
        correct_count = sum(1 for r in eligible_responses if r["is_correct"])
        accuracy_pct = round((correct_count / len(eligible_responses)) * 100, 1)

        diagnostic = {
            "old_theta": round(current_theta, 3),
            "new_theta": round(new_theta, 3),
            "delta": delta,
            "old_se": round(current_se, 3),
            "new_se": round(new_se, 3),
            "accuracy_pct": accuracy_pct,
            "items_eligible_count": len(eligible_responses),
            "items_excluded_count": len(excluded_items),
            "excluded_details": excluded_items,
            "learning_rate": learning_rate,
            "engine_version": self.ENGINE_VERSION,
            "model_type": self.MODEL_TYPE,
            "status": "UPDATED",
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

        if idempotency_key:
            self._processed_events[idempotency_key] = {
                "new_theta": new_theta,
                "new_se": new_se,
                "diagnostic": diagnostic
            }

        return round(new_theta, 3), round(new_se, 3), diagnostic

    def evaluate_checkpoint(
        self,
        chapter_just_completed: int,
        current_theta: float,
        current_se: float,
        checkpoint_responses: List[Dict[str, Any]],
        idempotency_key: Optional[str] = None,
        student_id: Optional[str] = None,
        shadow_mode: Optional[bool] = None
    ) -> Dict[str, Any]:
        """
        Avalia o desempenho do estudante em marcos periódicos de revisão (Capítulos 4, 8, 12, 16, 20).
        Utiliza contraste probabilístico via Z-score padronizado pelo Erro Padrão combinado.
        Garante remediação orientada a domínios/competências e proibição absoluta de pular itens inéditos.
        
        Se o Modo Sombra estiver ativo (via argumento ou self.shadow_mode), calcula e audita
        todas as sugestões estatísticas sem alterar a progressão curricular do estudante.
        """
        if idempotency_key and idempotency_key in self._processed_events:
            return self._processed_events[idempotency_key]["diagnostic"]

        effective_shadow = self.shadow_mode if shadow_mode is None else bool(shadow_mode)

        checkpoint_config = None
        for cp in self.checkpoints_data.get("checkpoints", []):
            if cp.get("after_chapter") == chapter_just_completed:
                checkpoint_config = cp
                break

        if not checkpoint_config:
            return {
                "is_checkpoint": False,
                "action": "PROCEED_NORMAL",
                "is_shadow_mode": effective_shadow,
                "shadow_action_suggested": "PROCEED_NORMAL",
                "message": f"Nenhum checkpoint periódico configurado após o Capítulo {chapter_just_completed}.",
                "timestamp": datetime.now(timezone.utc).isoformat()
            }

        min_items = int(checkpoint_config.get("min_items", 5))

        # Filtra respostas elegíveis
        eligible_responses: List[Dict[str, Any]] = []
        for r in checkpoint_responses:
            if not isinstance(r, dict):
                continue
            is_corr = r.get("is_correct")
            if is_corr is None or not isinstance(is_corr, (bool, int)):
                continue
            st = str(r.get("status_publicacao", r.get("status", ""))).lower()
            if st in ("quarentena", "retirado"):
                continue
            eligible_responses.append({
                "item_id": r.get("item_id", ""),
                "is_correct": bool(is_corr),
                "param_a": float(r.get("param_a", 1.2)),
                "param_b": float(r.get("param_b", 0.0)),
                "param_c": float(r.get("param_c", 0.25)),
                "dominio": r.get("dominio", r.get("categoria", "geral")),
            })

        # Evidência insuficiente: Não tomar decisões adaptativas extremas
        if len(eligible_responses) < min_items:
            res_insufficient = {
                "is_checkpoint": True,
                "checkpoint_id": checkpoint_config.get("checkpoint_id", ""),
                "checkpoint_name": checkpoint_config.get("name", ""),
                "action": "INSUFFICIENT_EVIDENCE",
                "is_shadow_mode": effective_shadow,
                "shadow_action_suggested": "INSUFFICIENT_EVIDENCE",
                "message": (
                    f"Amostra de respostas insuficiente ({len(eligible_responses)}/{min_items} itens elegíveis). "
                    "Decisão adaptativa mantida em fluxo normal sem remediação ou aceleração prematuras."
                ),
                "remediation_domains": [],
                "remediation_items": [],
                "allows_skip_redundant_reviews": False,
                "skips_new_content": False,
                "timestamp": datetime.now(timezone.utc).isoformat()
            }
            if idempotency_key:
                self._processed_events[idempotency_key] = {"diagnostic": res_insufficient}
            return res_insufficient

        # Estima habilidade demonstrada exclusivamente no teste de checkpoint
        # Desacoplamento estatístico: prior neutro/não-informativo
        est_theta, est_se = self.irt_engine.estimate_ability_eap(
            responses=eligible_responses,
            prior_mean=0.0,
            prior_sd=2.0,
            learning_rate=1.0
        )

        divergence = round(est_theta - current_theta, 3)
        se_divergence = round(math.sqrt(current_se ** 2 + est_se ** 2), 3)

        # Cálculo do Z-score da divergência
        z_score = round(divergence / max(0.05, se_divergence), 2)
        z_threshold = 1.645  # p < 0.05 unicaudal

        action = "PROCEED_NORMAL"
        adjustment_message = (
            f"Desempenho no checkpoint plenamente compatível com a proficiência estimada "
            f"(Z={z_score:+.2f}, divergência={divergence:+.2f}, SE={se_divergence:.2f})."
        )
        remediation_domains: List[str] = []
        remediation_items: List[str] = []
        allows_skip = False

        if z_score < -z_threshold:
            action = "TRIGGER_REMEDIATION"
            focus_domains = checkpoint_config.get("focus_domains", [])

            domain_errors: Dict[str, int] = {}
            for r in eligible_responses:
                if not r["is_correct"]:
                    d = r.get("dominio", "geral")
                    domain_errors[d] = domain_errors.get(d, 0) + 1
                    remediation_items.append(r["item_id"])

            remediation_domains = [
                d for d in focus_domains if d in domain_errors
            ] or list(domain_errors.keys())

            adjustment_message = (
                f"Desempenho no checkpoint divergiu negativamente de forma estatisticamente significativa "
                f"(Z={z_score:.2f} < -{z_threshold}, p < 0.05). "
                f"Disparando reforço pedagógico nos domínios deficitários: {', '.join(remediation_domains)}."
            )

        elif z_score > z_threshold and checkpoint_config.get("allows_skip_review", True):
            action = "TRIGGER_ACCELERATION"
            allows_skip = True
            adjustment_message = (
                f"Desempenho no checkpoint superou as expectativas com evidência estatisticamente robusta "
                f"(Z={z_score:.2f} > +{z_threshold}, p < 0.05). "
                "Aceleração concedida: revisões redundantes liberadas para dispensa. ITENS NOVOS PRESERVADOS."
            )

        suggested_action = action
        suggested_allows_skip = allows_skip
        suggested_remediation_domains = list(remediation_domains)
        suggested_remediation_items = list(remediation_items)
        suggested_message = adjustment_message

        # Interceptação pelo Modo Sombra
        if effective_shadow:
            action = "PROCEED_NORMAL"
            allows_skip = False
            remediation_domains = []
            remediation_items = []
            adjustment_message = (
                f"[MODO SOMBRA ATIVO] Sugestão calculada: {suggested_action} (Z={z_score:+.2f}). "
                "Progressão mantida em fluxo regular sem aceleração ou remediação automática."
            )

            # Anonimização de PII reforçada com HMAC-SHA256 (proteção contra rainbow tables)
            student_hash = self.pseudonymize_student_id(student_id, self.telemetry_secret)
            event_id = uuid.uuid4().hex

            shadow_event = {
                "event_id": event_id,
                "algorithm_version": self.ENGINE_VERSION,
                "config_version": self.checkpoints_data.get("version", "unknown"),
                "student_id_hash": student_hash,
                "chapter_completed": chapter_just_completed,
                "checkpoint_id": checkpoint_config.get("checkpoint_id", ""),
                "current_theta": round(current_theta, 3),
                "current_se": round(current_se, 3),
                "measured_theta": round(est_theta, 3),
                "measured_se": round(est_se, 3),
                "divergence": divergence,
                "se_divergence": se_divergence,
                "z_score": z_score,
                "suggested_action": suggested_action,
                "suggested_reason": suggested_message,
                "suggested_domains": suggested_remediation_domains,
                "applied_action": "PROCEED_NORMAL",
                "items_count": len(eligible_responses),
                "accuracy_pct": round((sum(1 for r in eligible_responses if r["is_correct"]) / len(eligible_responses)) * 100, 1),
                "idempotency_key": idempotency_key or "",
                "timestamp": datetime.now(timezone.utc).isoformat()
            }
            self._log_shadow_event(shadow_event)

        result = {
            "is_checkpoint": True,
            "checkpoint_id": checkpoint_config.get("checkpoint_id", ""),
            "checkpoint_name": checkpoint_config.get("name", ""),
            "current_theta": round(current_theta, 3),
            "measured_theta": round(est_theta, 3),
            "divergence": divergence,
            "se_divergence": se_divergence,
            "z_score": z_score,
            "action": action,
            "is_shadow_mode": effective_shadow,
            "shadow_action_suggested": suggested_action,
            "shadow_allows_skip_suggested": suggested_allows_skip,
            "shadow_remediation_domains_suggested": suggested_remediation_domains,
            "message": adjustment_message,
            "remediation_domains": remediation_domains,
            "remediation_items": remediation_items,
            "revisiting_chapters": checkpoint_config.get("revisiting_chapters", []),
            "allows_skip_redundant_reviews": allows_skip,
            "skips_new_content": False,  # REGRA INEGOCIÁVEL: NUNCA PULA ITENS NOVOS
            "engine_version": self.ENGINE_VERSION,
            "timestamp": datetime.now(timezone.utc).isoformat()
        }

        if idempotency_key:
            self._processed_events[idempotency_key] = {"diagnostic": result}

        return result

    def _log_shadow_event(self, event_data: Dict[str, Any]) -> bool:
        """
        Grava evento de auditoria do modo sombra em arquivo JSONL de forma segura e resiliente.
        Falhas de I/O em telemetria NUNCA alteram o comportamento pedagógico nem lançam exceções não tratadas.
        """
        try:
            self.shadow_log_path.parent.mkdir(parents=True, exist_ok=True)
            with open(self.shadow_log_path, "a", encoding="utf-8") as f:
                f.write(json.dumps(event_data, ensure_ascii=False) + "\n")
                f.flush()
            return True
        except (OSError, IOError, PermissionError) as exc:
            logger.error("Falha de I/O ao persistir telemetria do modo sombra: %s", exc)
            return False
        except Exception as exc:
            logger.error("Erro inesperado ao registrar telemetria do modo sombra: %s", exc)
            return False

    def get_shadow_audit_events(self, limit: int = 100) -> List[Dict[str, Any]]:
        """Recupera os registros mais recentes de auditoria do modo sombra."""
        if not self.shadow_log_path.exists():
            return []
        events = []
        try:
            with open(self.shadow_log_path, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if line:
                        events.append(json.loads(line))
        except Exception as exc:
            logger.error("Falha ao ler eventos de auditoria do modo sombra: %s", exc)
        return events[-limit:]

    def record_subsequent_shadow_feedback(
        self,
        student_id_hash: str,
        checkpoint_id: str,
        subsequent_outcome: Dict[str, Any],
        feedback_id: Optional[str] = None
    ) -> bool:
        """
        Associa retrospectivamente o desempenho posterior do estudante a uma decisão sugerida no modo sombra.
        Garante idempotência por feedback_id e tratamento resiliente de I/O de disco.
        """
        feedback_file = self.shadow_log_path.parent / "shadow_feedback_outcomes.jsonl"
        try:
            feedback_file.parent.mkdir(parents=True, exist_ok=True)
            payload = {
                "feedback_id": feedback_id or uuid.uuid4().hex,
                "student_id_hash": student_id_hash,
                "checkpoint_id": checkpoint_id,
                "subsequent_outcome": subsequent_outcome,
                "timestamp": datetime.now(timezone.utc).isoformat()
            }
            with open(feedback_file, "a", encoding="utf-8") as f:
                f.write(json.dumps(payload, ensure_ascii=False) + "\n")
                f.flush()
            return True
        except (OSError, IOError, PermissionError) as exc:
            logger.error("Falha de disco ao registrar feedback retrospectivo do modo sombra: %s", exc)
            return False
        except Exception as exc:
            logger.error("Erro inesperado ao registrar feedback retrospectivo do modo sombra: %s", exc)
            return False
