"""
Serviço de Avaliação Adaptativa baseado em Teoria da Resposta ao Item (TRI - 3PL).
Refatorado para alta performance e precisão matemática estrita via VectorizedTRIEngine (MAP).
"""

import logging
from typing import Any

from .tri_engine_vectorized import TRIResult, VectorizedTRIEngine

logger = logging.getLogger(__name__)

# Instância singleton pré-configurada do motor vetorizado com prior padrão N(0, 1)
_tri_engine = VectorizedTRIEngine(prior_mu=0.0, prior_sigma=1.0)


def p_theta(theta: float, a: float, b: float, c: float) -> float:
    """Função 3PL da Teoria da Resposta ao Item (TRI) com métrica D=1.702."""
    import numpy as np
    val = _tri_engine.p_3pl(
        theta=theta,
        a=np.array([a], dtype=np.float64),
        b=np.array([b], dtype=np.float64),
        c=np.array([c], dtype=np.float64),
    )
    return float(val[0])


def evaluate_test(answers: list[dict[str, Any]], current_level: int) -> dict[str, Any]:
    """
    Avalia a proficiência latente (theta) e o nível pedagógico do aluno usando MAP vetorizado.

    answers: lista de dicts com as seguintes chaves:
      - is_correct (bool)
      - time_taken_seconds (float)
      - param_a (float, default 1.2)
      - param_b (float, mapeado a partir do nível da questão)
      - param_c (float, default 0.25)
      - selected_letter (str)
    """
    if not answers:
        return {
            "level": current_level,
            "theta": 0.0,
            "sem": 1.0,
            "cheating": False,
        }

    total_time = sum(ans.get("time_taken_seconds", 0.0) for ans in answers)
    avg_time = total_time / max(len(answers), 1)

    # 1. Heurística Anti-chute: Speedrun
    is_cheating = False
    if avg_time < 2.5:
        is_cheating = True
        logger.warning("Speedrun detectado no teste de nivelamento. Média: %.2fs", avg_time)

    # 2. Heurística Anti-chute: Padrões repetitivos
    selected_letters = [
        ans.get("selected_letter", "") for ans in answers if ans.get("selected_letter")
    ]
    if len(selected_letters) >= 4:
        # Padrão: mesma letra em todas as questões
        if len(set(selected_letters)) == 1:
            is_cheating = True
            logger.warning("Padrão de chute detectado (mesma letra): %s", selected_letters)
        # Padrão alternado: A-B-A-B-A-B
        elif all(
            selected_letters[i] == selected_letters[i - 2]
            for i in range(2, len(selected_letters))
        ):
            is_cheating = True
            logger.warning("Padrão de chute alternado detectado: %s", selected_letters)

    # 3. Estimação Vetorizada Maximum A Posteriori (MAP) via Newton-Raphson
    responses = [1 if ans.get("is_correct") else 0 for ans in answers]
    params_a = [float(ans.get("param_a", 1.2)) for ans in answers]
    params_b = [
        float(ans.get("param_b", (current_level - 5) / 2.0)) for ans in answers
    ]
    params_c = [float(ans.get("param_c", 0.25)) for ans in answers]

    # Prior inicial baseado no nível atual do usuário
    init_theta = float((current_level - 5.5) / 2.5)

    tri_result: TRIResult = _tri_engine.estimate_theta_map(
        responses=responses,
        params_a=params_a,
        params_b=params_b,
        params_c=params_c,
        initial_theta=init_theta,
    )

    final_theta = tri_result.theta
    final_level = tri_result.level

    # Se houve detecção flagrante de trapaça/speedrun, penaliza a nota
    if is_cheating:
        final_theta = -3.0
        final_level = 1

    return {
        "level": final_level,
        "theta": final_theta,
        "sem": tri_result.sem,
        "cheating": is_cheating,
        "converged": tri_result.converged,
        "iterations": tri_result.iterations,
    }
