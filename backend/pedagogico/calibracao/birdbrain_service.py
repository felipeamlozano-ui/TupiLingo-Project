"""
TupiLingo — Serviço de Calibração Contínua de Habilidade ("Birdbrain")
Monitora e atualiza dinamicamente a proficiência theta_atual do estudante
ao longo de todas as lições e checkpoints da trilha.

Funcionalidades:
  1. Atualização Bayesiana incremental de theta_atual a cada lição concluída.
  2. Inserção de Checkpoints Periódicos de Revisão adaptativos (Capítulos 4, 8, 12, 16, 20).
  3. Detecção de Divergência de Desempenho e Disparo de Ajustes:
     - Reforço remediador de itens fracos se desempenho < esperado.
     - Aceleração adaptativa (pula revisões redundantes, nunca itens novos) se desempenho >> esperado.
  4. Histórico completo e auditável de theta por usuário e variante.
"""

from __future__ import annotations

import json
import math
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from pedagogico.nivelamento.irt_engine import IRTEngine

BASE_DIR = Path(__file__).resolve().parent
CHECKPOINTS_FILE = BASE_DIR / "checkpoints_config.json"


class BirdbrainService:
    def __init__(self, checkpoints_path: Path = CHECKPOINTS_FILE):
        self.irt_engine = IRTEngine()
        self.checkpoints_path = checkpoints_path
        self.checkpoints_data: Dict[str, Any] = {}
        self._load_checkpoints()

    def _load_checkpoints(self) -> None:
        if self.checkpoints_path.exists():
            with open(self.checkpoints_path, "r", encoding="utf-8") as f:
                self.checkpoints_data = json.load(f)

    def update_theta_after_lesson(
        self,
        current_theta: float,
        current_se: float,
        lesson_responses: List[Dict[str, Any]],
        learning_rate: float = 0.15
    ) -> Tuple[float, float, Dict[str, Any]]:
        """
        Atualiza a estimativa de habilidade theta_atual após a conclusão de uma lição regular.
        Usa atualização estocástica Bayesiana com amortecimento suave (learning rate).
        """
        if not lesson_responses:
            return current_theta, current_se, {"delta": 0.0, "status": "UNCHANGED"}

        # Estima theta da lição via IRT EAP
        lesson_theta, lesson_se = self.irt_engine.estimate_ability_eap(
            lesson_responses,
            prior_mean=current_theta,
            prior_sd=max(0.4, current_se)
        )

        # Atualização ponderada pelo inverso das variâncias (Filtro Bayesiano / Kalman)
        w_current = 1.0 / (current_se ** 2)
        w_lesson = (1.0 / (lesson_se ** 2)) * learning_rate
        new_theta = (w_current * current_theta + w_lesson * lesson_theta) / (w_current + w_lesson)
        new_se = math.sqrt(1.0 / (w_current + w_lesson))

        delta = round(new_theta - current_theta, 3)

        diagnostic = {
            "old_theta": round(current_theta, 3),
            "new_theta": round(new_theta, 3),
            "delta": delta,
            "new_se": round(new_se, 3),
            "lesson_theta": lesson_theta,
            "total_items_in_lesson": len(lesson_responses),
            "accuracy_pct": round((sum(1 for r in lesson_responses if r.get("is_correct")) / len(lesson_responses)) * 100, 1),
            "timestamp": datetime.now(timezone.utc).isoformat()
        }

        return round(new_theta, 3), round(new_se, 3), diagnostic

    def evaluate_checkpoint(
        self,
        chapter_just_completed: int,
        current_theta: float,
        checkpoint_responses: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """
        Avalia o desempenho do usuário em um marco de revisão periódica (Checkpoint).
        Compara o desempenho real contra o theta_atual esperado.
        """
        checkpoint_config = None
        for cp in self.checkpoints_data.get("checkpoints", []):
            if cp["after_chapter"] == chapter_just_completed:
                checkpoint_config = cp
                break

        if not checkpoint_config:
            return {
                "is_checkpoint": False,
                "action": "PROCEED_NORMAL",
                "message": "Nenhum checkpoint configurado para este capítulo."
            }

        # Estima habilidade demonstrada no checkpoint
        est_theta, est_se = self.irt_engine.estimate_ability_eap(
            checkpoint_responses,
            prior_mean=current_theta,
            prior_sd=0.6
        )

        divergence = round(est_theta - current_theta, 3)
        threshold = checkpoint_config.get("divergence_threshold_theta", 0.45)

        action = "PROCEED_NORMAL"
        adjustment_message = "Desempenho plenamente alinhado à curva esperada de proficiência."
        remediation_items: List[str] = []

        if divergence < -threshold:
            # Desempenho significativamente abaixo do esperado -> Reforço remediador
            action = "TRIGGER_REMEDIATION"
            adjustment_message = (
                f"Desempenho no checkpoint divergiu negativamente ({divergence} abaixo do esperado). "
                f"Disparando reforço dos itens com taxa de erro elevada antes de liberar o Capítulo {chapter_just_completed + 1}."
            )
            # Identifica itens fracos
            for r in checkpoint_responses:
                if not r.get("is_correct"):
                    remediation_items.append(r.get("item_id", ""))

        elif divergence > threshold and checkpoint_config.get("allows_skip_review", True):
            # Desempenho significativamente acima do esperado -> Aceleração adaptativa
            action = "TRIGGER_ACCELERATION"
            adjustment_message = (
                f"Desempenho no checkpoint superou as expectativas ({divergence} acima do esperado). "
                f"Avanço acelerado concedido: revisões redundantes liberadas para salto (itens novos preservados)."
            )

        return {
            "is_checkpoint": True,
            "checkpoint_id": checkpoint_config["checkpoint_id"],
            "checkpoint_name": checkpoint_config["name"],
            "current_theta": current_theta,
            "measured_theta": est_theta,
            "divergence": divergence,
            "action": action,
            "message": adjustment_message,
            "remediation_items": remediation_items,
            "revisiting_chapters": checkpoint_config["revisiting_chapters"],
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
