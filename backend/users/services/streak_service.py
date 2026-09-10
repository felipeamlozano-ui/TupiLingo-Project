"""
StreakService — Gestão Canônica da Ofensiva Diária (Streak) no Supabase.

Garante:
1. Atualização transacional atômica de ofensiva via PostgreSQL (fn_record_user_activity).
2. Respeito estrito ao fuso horário brasileiro (America/Sao_Paulo).
3. Regras de Duolingo-style streak:
   - Mesmo dia: acumula XP e tempo no log sem duplicar o streak.
   - Dia consecutivo: incrementa +1 e atualiza maior recorde.
   - 2+ dias sem estudar: reseta para 1 no retorno.
4. Alta performance: zero lock contention e chamadas diretas via RPC/SQL.
"""

import logging
import zoneinfo
from datetime import date, timedelta
from typing import Any

from django.db import connection, transaction
from django.utils import timezone

from users.models import DailyStudyLog, UserProfile

logger = logging.getLogger("users.streak")

BR_TZ = zoneinfo.ZoneInfo("America/Sao_Paulo")


class StreakService:
    """Serviço de Domínio para Ofensiva Diária."""

    @classmethod
    def get_today_brasilia(cls) -> date:
        """Retorna a data atual no fuso horário de Brasília."""
        return timezone.now().astimezone(BR_TZ).date()

    @classmethod
    def register_study_activity(
        cls,
        user: UserProfile,
        xp_ganho: int,
        tempo_segundos: int = 60,
        is_lesson_completed: bool = False,
        exercicios_respondidos: int = 0,
        exercicios_corretos: int = 0,
    ) -> dict[str, Any]:
        """
        Registra uma atividade de estudo válida no banco e atualiza a ofensiva do usuário.
        Executa prioritariamente a função SQL atômica do PostgreSQL fn_record_user_activity.
        """
        try:
            with transaction.atomic():
                with connection.cursor() as cursor:
                    cursor.execute(
                        """
                        SELECT out_streak_atual, out_maior_streak, out_xp_total, out_streak_incremented
                        FROM fn_record_user_activity(%s, %s, %s, %s, %s, %s);
                        """,
                        [
                            user.id,
                            xp_ganho,
                            tempo_segundos,
                            is_lesson_completed,
                            exercicios_respondidos,
                            exercicios_corretos,
                        ],
                    )
                    row = cursor.fetchone()
                    if row:
                        streak_atual, maior_streak, xp_total, streak_incremented = row
                        user.streak_atual = streak_atual
                        user.maior_streak = maior_streak
                        user.xp_total = xp_total
                        user.ultimo_dia_estudado = cls.get_today_brasilia()

                        logger.info(
                            "Ofensiva registrada via SQL para user %d: streak=%d, maior=%d, xp=%d",
                            user.id,
                            streak_atual,
                            maior_streak,
                            xp_total,
                        )
                        return {
                            "success": True,
                            "streak_atual": streak_atual,
                            "maior_streak": maior_streak,
                            "xp_total": xp_total,
                            "streak_incremented": streak_incremented,
                        }
        except Exception as exc:  # noqa: BLE001
            logger.warning(
                "Falha ao invocar fn_record_user_activity, executando fallback ORM: %s",
                exc,
            )

        # Fallback ORM caso a conexão direta a procedure falhe ou em ambiente de testes
        return cls._register_study_activity_orm(
            user,
            xp_ganho,
            tempo_segundos,
            is_lesson_completed,
            exercicios_respondidos,
            exercicios_corretos,
        )

    @classmethod
    @transaction.atomic
    def _register_study_activity_orm(
        cls,
        user: UserProfile,
        xp_ganho: int,
        tempo_segundos: int,
        is_lesson_completed: bool,
        exercicios_respondidos: int,
        exercicios_corretos: int,
    ) -> dict[str, Any]:
        today_br = cls.get_today_brasilia()
        yesterday_br = today_br - timedelta(days=1)

        user = UserProfile.objects.select_for_update().get(pk=user.pk)
        last_studied = user.ultimo_dia_estudado
        streak_atual = user.streak_atual
        maior_streak = user.maior_streak
        streak_incremented = False

        if last_studied is None:
            streak_atual = 1
            streak_incremented = True
        elif last_studied == today_br:
            # Já estudou hoje
            streak_incremented = False
        elif last_studied == yesterday_br:
            # Dia consecutivo
            streak_atual += 1
            streak_incremented = True
        else:
            # Mais de um dia sem estudar
            streak_atual = 1
            streak_incremented = True

        maior_streak = max(maior_streak, streak_atual)

        user.streak_atual = streak_atual
        user.maior_streak = maior_streak
        user.ultimo_dia_estudado = today_br
        if last_studied != today_br:
            user.dias_estudados_total += 1
        user.xp_total += xp_ganho
        user.save()

        # Upsert log diário
        log, created = DailyStudyLog.objects.get_or_create(
            user=user,
            data=today_br,
            defaults={
                "xp_ganho": xp_ganho,
                "tempo_estudo_segundos": tempo_segundos,
                "licoes_concluidas": 1 if is_lesson_completed else 0,
                "exercicios_respondidos": exercicios_respondidos,
                "exercicios_corretos": exercicios_corretos,
            },
        )
        if not created:
            log.xp_ganho += xp_ganho
            log.tempo_estudo_segundos += tempo_segundos
            if is_lesson_completed:
                log.licoes_concluidas += 1
            log.exercicios_respondidos += exercicios_respondidos
            log.exercicios_corretos += exercicios_corretos
            log.save()

        return {
            "success": True,
            "streak_atual": streak_atual,
            "maior_streak": maior_streak,
            "xp_total": user.xp_total,
            "streak_incremented": streak_incremented,
        }

    @classmethod
    def check_and_sync_streak(cls, user: UserProfile) -> int:
        """
        Garante que, se o usuário ficou inativo e o cron ainda não rodou,
        o streak_atual retornado na API reflita a realidade (0 se perdeu a sequência).
        """
        today_br = cls.get_today_brasilia()
        yesterday_br = today_br - timedelta(days=1)

        if user.streak_atual > 0:
            if (
                user.ultimo_dia_estudado is None
                or user.ultimo_dia_estudado < yesterday_br
            ):
                user.streak_atual = 0
                user.save(update_fields=["streak_atual", "updated_at"])
                logger.info(
                    "Streak do usuário %d recalculado para 0 devido a inatividade.",
                    user.id,
                )

        return user.streak_atual
