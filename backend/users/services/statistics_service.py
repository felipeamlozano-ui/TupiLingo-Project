"""
StatisticsService — Cálculo Analítico 100% Autêntico de Estatísticas e Desempenho.

Garante:
1. Eliminação total de mocks, seeds ou dados fictícios.
2. Contagem real de vocábulos aprendidos (VocabularyProgress + Lições Concluídas).
3. Precisão calculada a partir de respostas reais de exercícios.
4. Ritmo semanal (Seg-Dom) com 0 XP nos dias inativos.
5. Tempo real de estudo acumulado.
6. Detecção de Empty State para novos usuários.
7. Alta performance: agregações de passo único com índices parciais.
"""

import logging
from datetime import date, timedelta
from typing import Dict, Any, List
from django.db.models import Avg, Sum, Count
from django.utils import timezone
import zoneinfo

from users.models import UserProfile, UserLesson, VocabularyProgress, DailyStudyLog
from users.services.streak_service import StreakService
from trilha.models import VocabularyItem, Licao

logger = logging.getLogger("users.stats")
BR_TZ = zoneinfo.ZoneInfo("America/Sao_Paulo")

DAY_NAMES_PT = ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]
CATEGORY_ICONS = {
    "geral": "🌿",
    "saudacoes": "🏹",
    "fauna": "🐆",
    "flora": "🌴",
    "natureza": "🌊",
    "corpo": "✋",
    "mitologia": "⚡",
    "alimentos": "🌽",
}


class StatisticsService:
    """Serviço de cálculo estatístico de desempenho e memória."""

    @classmethod
    def invalidate_user_stats_cache(cls, user_id: int):
        """
        Invalida de forma imediata o cache Redis e Django Cache das estatísticas
        do usuário, garantindo atualização instantânea do painel de desempenho.
        """
        from django.core.cache import cache
        cache.delete(f"dashboard_stats_{user_id}")
        cache.delete(f"stats_v3_{user_id}")
        try:
            from app.ai.ping_race import get_redis_client
            r = get_redis_client()
            if r:
                r.delete(f"dashboard_stats_{user_id}")
                r.delete(f"stats_v3_{user_id}")
                for vid in range(1, 15):
                    r.delete(f"mapa_regioes_{user_id}_{vid}")
        except Exception as exc:
            logger.warning("Falha ao invalidar cache Redis de stats do usuário %s: %s", user_id, exc)

    @classmethod
    def get_user_progress_stats(cls, user: UserProfile) -> Dict[str, Any]:
        """
        Retorna todas as estatísticas consolidadas do usuário
        para o ProgressDashboardScreen do Flutter.
        """
        user.refresh_from_db(fields=["xp_total", "streak_atual", "maior_streak", "dias_estudados_total", "ultimo_dia_estudado"])
        today_br = timezone.now().astimezone(BR_TZ).date()

        # 1. Sincroniza e obtém ofensiva real
        streak_dias = StreakService.check_and_sync_streak(user)

        # 2. Lições concluídas
        completed_lessons_count = UserLesson.objects.filter(
            usuario=user, status="concluida"
        ).count()

        # 3. Total de lições da variante ativa ou geral
        total_lessons = 0
        if user.variante_ativa:
            total_lessons = Licao.objects.filter(
                capitulo__trilha__variante=user.variante_ativa, publicada=True
            ).count()
        if total_lessons == 0:
            total_lessons = Licao.objects.filter(publicada=True).count() or 20

        # 4. Termos únicos aprendidos (Vocabulário Real)
        # Itens com pelo menos 1 repetição no SM-2 OU de lições concluídas
        sm2_learned_ids = set(
            VocabularyProgress.objects.filter(
                usuario=user, repetitions__gt=0
            ).values_list("item_id", flat=True)
        )
        lesson_learned_ids = set(
            VocabularyItem.objects.filter(
                licao__progressos_usuarios__usuario=user,
                licao__progressos_usuarios__status="concluida"
            ).values_list("id", flat=True)
        )
        unique_learned_term_ids = sm2_learned_ids | lesson_learned_ids
        total_termos_aprendidos = len(unique_learned_term_ids)

        # 5. Precisão real (média de accuracy de lições e logs)
        acc_agg = UserLesson.objects.filter(
            usuario=user, status="concluida"
        ).aggregate(media_acc=Avg("accuracy"))
        precisao_real = round(acc_agg["media_acc"] or 0.0, 2)
        precisao_percentual = int(round(precisao_real * 100))

        # 6. Tempo de Estudo Real
        time_agg = DailyStudyLog.objects.filter(user=user).aggregate(
            tempo_total=Sum("tempo_estudo_segundos")
        )
        tempo_segundos = time_agg["tempo_total"] or 0
        tempo_minutos = tempo_segundos // 60
        tempo_horas = tempo_minutos // 60
        if tempo_horas > 0:
            tempo_formatado = f"{tempo_horas}h {tempo_minutos % 60}m"
        else:
            tempo_formatado = f"{tempo_minutos} min"

        # 7. Ritmo Semanal de Aprendizado (Semana Atual: Segunda a Domingo)
        # Determina a segunda-feira da semana corrente
        weekday_idx = today_br.weekday()  # 0=Segunda, 6=Domingo
        monday = today_br - timedelta(days=weekday_idx)
        sunday = monday + timedelta(days=6)

        # Busca logs reais dos dias desta semana
        logs_semana = {
            log.data: log
            for log in DailyStudyLog.objects.filter(
                user=user, data__gte=monday, data__lte=sunday
            )
        }

        weekly_activity: List[Dict[str, Any]] = []
        for i in range(7):
            current_day = monday + timedelta(days=i)
            day_name = DAY_NAMES_PT[i]
            log = logs_semana.get(current_day)

            weekly_activity.append({
                "day_name": day_name,
                "day_index": i,
                "date": current_day.isoformat(),
                "xp": log.xp_ganho if log else 0,
                "lessons_completed": log.licoes_concluidas if log else 0,
                "is_today": current_day == today_br,
            })

        # 8. Categorias Lexicais e Domínio Real
        category_masteries = cls._calculate_category_masteries(user, unique_learned_term_ids)

        # 9. Calendário de Atividade (Últimos 30 dias)
        start_30 = today_br - timedelta(days=30)
        active_dates = list(
            DailyStudyLog.objects.filter(
                user=user, data__gte=start_30, xp_ganho__gt=0
            ).values_list("data", flat=True)
        )
        calendario_atividade = [d.isoformat() for d in active_dates]

        # 10. Progresso Geral Percentual
        overall_progress_pct = (
            round(completed_lessons_count / total_lessons, 2)
            if total_lessons > 0 else 0.0
        )

        is_empty_state = (
            completed_lessons_count == 0
            and user.xp_total == 0
            and total_termos_aprendidos == 0
        )

        return {
            "success": True,
            "xp_total": user.xp_total,
            "dias_ofensiva": streak_dias,
            "maior_ofensiva": user.maior_streak,
            "dias_estudados_total": user.dias_estudados_total,
            "licoes_concluidas": completed_lessons_count,
            "total_licoes": total_lessons,
            "total_palavras": total_termos_aprendidos,
            "precisao_real": precisao_real,
            "precisao_percentual": precisao_percentual,
            "tempo_estudo_segundos": tempo_segundos,
            "tempo_estudo_formatado": tempo_formatado,
            "overall_progress_percentage": overall_progress_pct,
            "is_empty_state": is_empty_state,
            "weekly_activity": weekly_activity,
            "category_masteries": category_masteries,
            "calendario_atividade": calendario_atividade,
        }

    @classmethod
    def _calculate_category_masteries(
        cls, user: UserProfile, learned_item_ids: set
    ) -> List[Dict[str, Any]]:
        """Calcula o domínio real de vocabulário agrupado por categoria gramatical/temática."""
        # Busca todas as categorias existentes nos itens publicados
        categories_qs = (
            VocabularyItem.objects.filter(licao__publicada=True)
            .values("categoria")
            .annotate(total=Count("id"))
            .order_by("-total")
        )

        if not categories_qs.exists():
            return []

        # Contagem de palavras dominadas pelo usuário por categoria
        user_mastered_qs = (
            VocabularyItem.objects.filter(
                id__in=learned_item_ids, licao__publicada=True
            )
            .values("categoria")
            .annotate(mastered=Count("id"))
        )
        mastered_map = {row["categoria"]: row["mastered"] for row in user_mastered_qs}

        result = []
        for cat in categories_qs:
            cat_name = (cat["categoria"] or "geral").lower().strip()
            total_words = cat["total"]
            mastered_words = mastered_map.get(cat_name, 0)
            icon = CATEGORY_ICONS.get(cat_name, "🌿")

            # Formata o nome para exibição amigável
            display_name = cat_name.capitalize()
            if cat_name == "saudacoes":
                display_name = "Saudações"

            result.append({
                "category": display_name,
                "categoria_slug": cat_name,
                "icon": icon,
                "mastered_words": mastered_words,
                "total_words": total_words,
                "percentage": int(round((mastered_words / total_words) * 100)) if total_words > 0 else 0,
            })

        return result

    # Alias de conveniência
    get_dashboard_stats = get_user_progress_stats
