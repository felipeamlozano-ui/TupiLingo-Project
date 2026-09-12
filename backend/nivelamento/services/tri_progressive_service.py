"""
TupiLingo — Motor de TRI Progressivo em Tempo Real (RFC v3.2)

Implementa:
1. Cálculo síncrono e progressivo questão por questão (< 50ms total).
2. Atualização bayesiana recursiva online de theta (traço latente de proficiência).
3. Prevenção e detecção matemática de chutes (Anti-Guessing 3PL com latência cognitiva).
4. Distribuição justa e em tempo real de XP e Conchas (moedas do Pindorama).
5. Consolidação atômica e instantânea no término da sessão.
"""

from __future__ import annotations

import json
import logging
import math
import time
import uuid
from dataclasses import asdict, dataclass
from typing import Any, Optional

import numpy as np
from django.core.cache import cache
from django.db import transaction

from app.ai.ping_race import get_redis_client
from nivelamento.services.tri_engine_vectorized import D_FACTOR, VectorizedTRIEngine

logger = logging.getLogger(__name__)

REDIS_TRI_PREFIX = "tri_session:"
SESSION_TTL_SECONDS = 7200  # 2 horas


@dataclass
class ProgressiveTRISessionState:
    session_id: str
    user_id: int
    variante_id: int
    current_theta: float
    current_info: float
    total_xp_accumulated: int
    total_conchas_accumulated: int
    answers_count: int
    correct_count: int
    guesses_detected: int
    is_finished: bool
    freeze_theta: bool = False
    created_at: float = 0.0
    updated_at: float = 0.0

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> ProgressiveTRISessionState:
        return cls(
            session_id=data["session_id"],
            user_id=int(data["user_id"]),
            variante_id=int(data["variante_id"]),
            current_theta=float(data["current_theta"]),
            current_info=float(data["current_info"]),
            total_xp_accumulated=int(data["total_xp_accumulated"]),
            total_conchas_accumulated=int(data["total_conchas_accumulated"]),
            answers_count=int(data["answers_count"]),
            correct_count=int(data["correct_count"]),
            guesses_detected=int(data.get("guesses_detected", 0)),
            is_finished=bool(data.get("is_finished", False)),
            freeze_theta=bool(data.get("freeze_theta", False)),
            created_at=float(data.get("created_at", time.time())),
            updated_at=float(data.get("updated_at", time.time())),
        )


class TRIProgressiveEngine:
    """Motor de atualização online questão por questão com latência < 1ms."""

    @staticmethod
    def level_to_theta(level: int) -> float:
        """Converte nível 1-10 para a escala theta [-2.5, +2.5]."""
        lvl = max(1, min(10, level))
        return float(round((lvl - 5.5) / 1.8, 2))

    @staticmethod
    def theta_to_level(theta: float) -> int:
        return VectorizedTRIEngine.theta_to_level(theta)

    @classmethod
    def calcular_probabilidade_3pl(
        cls, theta: float, a: float, b: float, c: float
    ) -> float:
        """P_i(theta) = c_i + (1 - c_i) / (1 + exp(-D * a_i * (theta - b_i)))."""
        linear = -D_FACTOR * a * (theta - b)
        linear = float(np.clip(linear, -35.0, 35.0))
        logistic = 1.0 / (1.0 + math.exp(linear))
        return c + (1.0 - c) * logistic

    @classmethod
    def detectar_chute_matematico(
        cls,
        theta_anterior: float,
        a: float,
        b: float,
        c: float,
        is_correct: bool,
        time_taken_seconds: float,
    ) -> tuple[bool, float]:
        """
        Calcula o índice bayesiano de chute gamma_i.
        Retorna (suspeita_chute: bool, indice_gamma: float).
        """
        if not is_correct:
            return False, 0.0

        p = cls.calcular_probabilidade_3pl(theta_anterior, a, b, c)
        p_safe = max(p, 1e-4)

        # Probabilidade a posteriori de que o acerto foi por chute
        prob_chute = c / p_safe

        # Fator de penalidade por tempo de resposta cognitivo (tempo de leitura < 1.8s)
        tempo_ref = 1.8
        tau = 1.0 / (1.0 + math.exp(3.0 * (time_taken_seconds - tempo_ref)))

        # Índice composto de suspeita
        gamma = prob_chute * (0.4 + 0.6 * tau)

        # Se acertou questão muito acima da habilidade (b >> theta) em tempo mínimo
        chute_evidente = (time_taken_seconds < 1.6 and (b - theta_anterior) > 0.8) or (gamma > 0.58)

        return chute_evidente, float(round(gamma, 3))

    @classmethod
    def calcular_recompensas(
        cls,
        b: float,
        is_correct: bool,
        suspected_guess: bool,
    ) -> tuple[int, int]:
        """
        Calcula ganho de XP e Conchas para o item respondido.
        Retorna (xp_item, conchas_item).
        """
        if not is_correct:
            return 0, 0

        # Base de XP escala com a dificuldade psicométrica do item (b)
        xp_base = max(6, int(round(10 + 4.0 * b)))

        if suspected_guess:
            # Penalização de anti-farming: amortecimento a 25% de XP e 0 conchas
            xp_ganho = max(2, int(round(xp_base * 0.25)))
            conchas_ganho = 0
            logger.info("[Anti-Guessing] Chute identificado: XP amortecido para %d, Conchas zeradas.", xp_ganho)
        else:
            xp_ganho = xp_base
            # Conchas são concedidas por proficiência real (itens moderados/difíceis rendem 2 conchas)
            conchas_ganho = 2 if b >= 0.2 else 1

        return xp_ganho, conchas_ganho

    @classmethod
    def update_step(
        cls,
        current_theta: float,
        current_info: float,
        a: float,
        b: float,
        c: float,
        is_correct: bool,
    ) -> tuple[float, float, float]:
        """
        Atualização Online Bayesiana recursiva em 1 passo de Newton-Raphson.
        Retorna (novo_theta, nova_info, sem).
        Complexidade: O(1), tempo de execução < 0.1ms.
        """
        u = 1.0 if is_correct else 0.0
        p = cls.calcular_probabilidade_3pl(current_theta, a, b, c)
        p_safe = float(np.clip(p, 1e-4, 1.0 - 1e-4))
        c_safe = float(np.clip(c, 0.0, 0.95))

        # 1. Informação de Fisher do item k
        num_info = ((D_FACTOR * a) ** 2) * ((p_safe - c_safe) ** 2) * (1.0 - p_safe)
        den_info = ((1.0 - c_safe) ** 2) * p_safe
        item_info = num_info / den_info

        # 2. Gradiente do item k
        grad = D_FACTOR * a * ((p_safe - c_safe) / (1.0 - c_safe)) * ((u - p_safe) / p_safe)

        # 3. Atualização recursiva da informação e do theta
        nova_info = current_info + item_info
        passo = grad / max(nova_info, 1.0)
        passo_amortecido = float(np.clip(passo, -0.65, 0.65))

        novo_theta = float(np.clip(current_theta + passo_amortecido, -3.5, 3.5))
        sem = 1.0 / math.sqrt(max(nova_info, 0.1))

        return novo_theta, nova_info, float(round(sem, 4))


_redis_available: bool | None = None
_last_redis_check: float = 0.0


def _get_fast_redis_client():
    """Retorna cliente Redis apenas se o servidor estiver acessível (< 100ms)."""
    global _redis_available, _last_redis_check
    now = time.monotonic()
    if _redis_available is False and (now - _last_redis_check < 30.0):
        return None

    r = get_redis_client()
    if not r:
        _redis_available = False
        _last_redis_check = now
        return None

    try:
        # Ping ultrarrápido com socket_timeout
        r.ping()
        _redis_available = True
        return r
    except Exception:
        _redis_available = False
        _last_redis_check = now
        return None


class TRIProgressiveSessionManager:
    """Gerenciador de Sessões de Prática / Nivelamento com suporte a Redis e Cache Django."""

    @classmethod
    def _get_storage_key(cls, session_id: str) -> str:
        return f"{REDIS_TRI_PREFIX}{session_id}"

    @classmethod
    def salvar_estado(cls, state: ProgressiveTRISessionState) -> None:
        key = cls._get_storage_key(state.session_id)
        state.updated_at = time.time()
        raw = json.dumps(state.to_dict())

        r = _get_fast_redis_client()
        if r:
            try:
                r.set(key, raw, ex=SESSION_TTL_SECONDS)
                return
            except Exception as exc:
                logger.warning("[TRISession] Erro gravando no Redis: %s. Usando cache Django.", exc)

        cache.set(key, state.to_dict(), timeout=SESSION_TTL_SECONDS)

    @classmethod
    def obter_estado(cls, session_id: str) -> Optional[ProgressiveTRISessionState]:
        key = cls._get_storage_key(session_id)
        r = _get_fast_redis_client()
        if r:
            try:
                raw = r.get(key)
                if raw:
                    return ProgressiveTRISessionState.from_dict(json.loads(raw))
            except Exception as exc:
                logger.warning("[TRISession] Erro lendo do Redis: %s", exc)

        data = cache.get(key)
        if data and isinstance(data, dict):
            return ProgressiveTRISessionState.from_dict(data)
        return None

    @classmethod
    def iniciar_sessao(
        cls,
        user_id: int,
        variante_id: int,
        nivel_inicial: int = 1,
        freeze_theta: bool = False,
    ) -> ProgressiveTRISessionState:
        """Inicia uma sessão de prática/teste com prior centrado no nível atual do aluno."""
        session_id = str(uuid.uuid4())
        initial_theta = TRIProgressiveEngine.level_to_theta(nivel_inicial)
        # Prior gaussiano padrão sigma=1.0 -> Info inicial = 1.0
        initial_info = 1.0

        state = ProgressiveTRISessionState(
            session_id=session_id,
            user_id=user_id,
            variante_id=variante_id,
            current_theta=initial_theta,
            current_info=initial_info,
            total_xp_accumulated=0,
            total_conchas_accumulated=0,
            answers_count=0,
            correct_count=0,
            guesses_detected=0,
            is_finished=False,
            freeze_theta=freeze_theta,
            created_at=time.time(),
            updated_at=time.time(),
        )
        cls.salvar_estado(state)
        logger.info("[TRISession] Sessão %s iniciada para user %d (theta=%.2f, freeze=%s).", session_id, user_id, initial_theta, freeze_theta)
        return state

    @classmethod
    def processar_item(
        cls,
        session_id: str,
        is_correct: bool,
        time_taken_seconds: float,
        param_a: float = 1.2,
        param_b: float = 0.0,
        param_c: float = 0.25,
        is_last_item: bool = False,
    ) -> dict[str, Any]:
        """
        Processamento síncrono e progressivo do item com latência final < 50ms.
        """
        t_start = time.monotonic()
        state = cls.obter_estado(session_id)
        if not state:
            # Sessão órfã/expirada: recria transparentemente
            state = cls.iniciar_sessao(user_id=0, variante_id=1, nivel_inicial=1)

        theta_anterior = state.current_theta

        # 1. Detecção Matemática de Chute
        suspected_guess, gamma = TRIProgressiveEngine.detectar_chute_matematico(
            theta_anterior=theta_anterior,
            a=param_a,
            b=param_b,
            c=param_c,
            is_correct=is_correct,
            time_taken_seconds=time_taken_seconds,
        )

        # 2. Recompensas em Tempo Real
        earned_xp, earned_conchas = TRIProgressiveEngine.calcular_recompensas(
            b=param_b,
            is_correct=is_correct,
            suspected_guess=suspected_guess,
        )

        # 3. Atualização Bayesiana de Theta (< 0.1ms)
        if state.freeze_theta:
            # Em treinos temáticos/revisão, o nível permanece congelado
            novo_theta = theta_anterior
            nova_info = state.current_info
            sem = 1.0 / (nova_info ** 0.5)
        else:
            novo_theta, nova_info, sem = TRIProgressiveEngine.update_step(
                current_theta=theta_anterior,
                current_info=state.current_info,
                a=param_a,
                b=param_b,
                c=param_c,
                is_correct=is_correct,
            )
            state.current_theta = novo_theta
            state.current_info = nova_info

        # 4. Atualiza estado da sessão
        state.total_xp_accumulated += earned_xp
        state.total_conchas_accumulated += earned_conchas
        state.answers_count += 1
        if is_correct:
            state.correct_count += 1
        if suspected_guess:
            state.guesses_detected += 1

        novo_nivel = TRIProgressiveEngine.theta_to_level(novo_theta)

        # 5. Se for o último item, consolida o ganho imediatamente sem recálculo pesado
        consolidado = False
        if is_last_item:
            state.is_finished = True
            cls._consolidar_ganhos_no_banco(state, novo_nivel)
            consolidado = True

        cls.salvar_estado(state)
        elapsed_ms = int((time.monotonic() - t_start) * 1000)

        logger.info(
            "[TRISession][%s] Item %d processado em %d ms! Theta: %.2f -> %.2f (Nível %d) | +%d XP, +%d 🐚",
            session_id, state.answers_count, elapsed_ms, theta_anterior, novo_theta, novo_nivel, earned_xp, earned_conchas
        )

        return {
            "session_id": session_id,
            "answers_count": state.answers_count,
            "is_correct": is_correct,
            "suspected_guess": suspected_guess,
            "guess_index": gamma,
            "earned_xp": earned_xp,
            "earned_conchas": earned_conchas,
            "total_xp_accumulated": state.total_xp_accumulated,
            "total_conchas_accumulated": state.total_conchas_accumulated,
            "previous_theta": round(theta_anterior, 3),
            "current_theta": round(novo_theta, 3),
            "current_level": novo_nivel,
            "sem": sem,
            "is_last_item": is_last_item,
            "is_consolidated": consolidado,
            "server_latency_ms": elapsed_ms,
        }

    @classmethod
    def _consolidar_ganhos_no_banco(
        cls, state: ProgressiveTRISessionState, final_level: int
    ) -> None:
        """Consolidação atômica e instantânea dos ganhos de XP e Conchas no UserProfile."""
        if state.user_id <= 0:
            return

        try:
            from users.models import UserProfile
            from nivelamento.models import UserVarianteLevel
            from users.services.streak_service import StreakService
            from users.services.progress_service import ProgressService
            from users.services.statistics_service import StatisticsService

            with transaction.atomic():
                user = UserProfile.objects.filter(id=state.user_id).first()
                if not user:
                    return

                # Credita XP e Conchas acumulados atomicamente
                user.xp_total += state.total_xp_accumulated
                user.conchas = getattr(user, "conchas", 0) + state.total_conchas_accumulated
                user.save(update_fields=["xp_total", "conchas", "updated_at"])

                # Atualiza nível na variante correspondente (apenas se freeze_theta=False)
                if state.variante_id and not state.freeze_theta:
                    UserVarianteLevel.objects.update_or_create(
                        user=user,
                        variante_id=state.variante_id,
                        defaults={"nivel": final_level, "theta": state.current_theta},
                    )

                # Registra atividade diária de estudo (streak)
                StreakService.register_study_activity(
                    user=user,
                    xp_ganho=state.total_xp_accumulated,
                    tempo_segundos=state.answers_count * 5,
                    is_lesson_completed=False,
                    exercicios_respondidos=state.answers_count,
                    exercicios_corretos=state.correct_count,
                )

                # Invalida caches para o dashboard refletir na hora
                StatisticsService.invalidate_user_stats_cache(user.id)
                ProgressService.invalidate_user_trail_cache(user.id, state.variante_id)

            logger.info(
                "[TRISession] Ganhos consolidados com sucesso: User %d | +%d XP | +%d Conchas | Nível %d",
                state.user_id, state.total_xp_accumulated, state.total_conchas_accumulated, final_level
            )
        except Exception as exc:
            logger.error("[TRISession] Falha ao consolidar ganhos no banco: %s", exc, exc_info=True)
