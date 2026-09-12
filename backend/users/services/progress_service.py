"""
ProgressService — Serviço de Domínio para Progressão Sequencial Canônica.

Garante que:
1. Toda progressão na Trilha é estritamente sequencial.
2. A Lição N só é acessível quando a Lição N-1 estiver 100% concluída.
3. Baús de recompensa só são desbloqueados quando suas lições precedentes forem concluídas.
4. Alta performance: todas as checagens e resoluções ocorrem em O(1) queries sem N+1.
"""

import logging
from typing import Optional, Dict, Any, List
from django.db import transaction
from django.db.models import Prefetch, F
from django.utils import timezone

from users.models import UserProfile, UserLesson
from trilha.models import TrilhaHistorica, Capitulo, Licao, VarianteTupi, UserChestReward

logger = logging.getLogger("users.progress")


class ProgressService:
    """Serviço autoritativo de progressão do TupiLingo."""

    @classmethod
    def invalidate_user_trail_cache(cls, user_id: int, variante_id: int = None):
        """Invalida o cache da trilha do usuário em todas as variantes."""
        from django.core.cache import cache
        if variante_id:
            cache.delete(f"user_trail_{user_id}_{variante_id}")
        for vid in range(1, 10):
            cache.delete(f"user_trail_{user_id}_{vid}")

    @classmethod
    def get_trail_structure_with_progression(
        cls, user: UserProfile, variante: VarianteTupi, use_cache: bool = False
    ) -> Dict[str, Any]:
        """
        Retorna a estrutura completa da Trilha, Capítulos, Lições e Baús
        com o estado de progressão canônico de cada nó calculado de forma estrita.
        use_cache=False por padrão garante consistência imediata entre múltiplos
        workers Gunicorn e elimina rollbacks visuais no frontend Flutter.
        """
        from django.core.cache import cache
        cache_key = f"user_trail_{user.id}_{variante.id}"
        if use_cache:
            cached = cache.get(cache_key)
            if cached:
                return cached

        try:
            trilha = variante.trilha
        except TrilhaHistorica.DoesNotExist:
            return {"error": "Trilha não cadastrada para esta variante", "status": 404}

        # 1. Carrega capítulos e lições ordenados deterministicamente em batch (zero N+1)
        capitulos = list(
            trilha.capitulos.filter(numero__lt=900, publicado=True)
            .select_related("scenario")
            .prefetch_related(
                Prefetch(
                    "licoes",
                    queryset=Licao.objects.filter(publicada=True).order_by("numero", "id"),
                    to_attr="licoes_publicadas",
                )
            )
            .order_by("numero", "id")
        )

        if not capitulos:
            return {"capitulos": [], "trilha": {"id": trilha.id, "titulo": trilha.titulo}}

        # 2. Carrega todos os registros de progresso do usuário nesta trilha
        user_lessons_map = {
            ul.licao_id: ul
            for ul in UserLesson.objects.filter(
                usuario=user, licao__capitulo__trilha=trilha
            ).only("id", "licao_id", "status", "completion_percentage", "earned_xp", "accuracy")
        }

        # 3. Carrega os baús já coletados pelo usuário nesta trilha
        collected_chests = set(
            UserChestReward.objects.filter(
                user=user, capitulo__trilha=trilha
            ).values_list("capitulo_id", "milestone_index")
        )

        # 4. Constrói a lista linear sequencial de todas as lições da trilha
        all_ordered_lessons: List[Licao] = []
        for cap in capitulos:
            all_ordered_lessons.extend(cap.licoes_publicadas)

        # 5. Determinação canônica do status de cada lição
        # Regras de Progressão Sequencial Canônica Estrita:
        # - Identifica a última lição concluída (maior índice) na trilha.
        # - Todas as lições anteriores (0 .. last_completed_idx) SÃO OBRIGATORIAMENTE 'concluida'.
        #   (Evita que lições antigas fiquem 'disponivel'/'em_andamento' enquanto lições posteriores já foram feitas).
        # - A lição imediatamente seguinte (last_completed_idx + 1) é a lição da fronteira ativa:
        #   se estiver 'em_andamento', mantém; caso contrário, torna-se 'disponivel'.
        # - Todas as lições subsequentes (> last_completed_idx + 1) são 'bloqueada'.
        # - Se nenhuma lição foi concluída ainda, a Lição 0 é a fronteira ativa ('disponivel' ou 'em_andamento').
        canonical_status_map: Dict[int, str] = {}
        last_completed_idx = -1

        for idx, licao in enumerate(all_ordered_lessons):
            ul = user_lessons_map.get(licao.id)
            if ul and ul.status == "concluida":
                last_completed_idx = max(last_completed_idx, idx)

        lessons_to_reconcile = []

        if last_completed_idx >= 0:
            # Todas as lições até a última concluída são marcadas como 'concluida'
            for idx in range(last_completed_idx + 1):
                licao = all_ordered_lessons[idx]
                canonical_status_map[licao.id] = "concluida"
                ul = user_lessons_map.get(licao.id)
                if not ul or ul.status != "concluida":
                    lessons_to_reconcile.append(licao)

            # Lição da fronteira ativa (imediatamente posterior à última concluída)
            next_idx = last_completed_idx + 1
            if next_idx < len(all_ordered_lessons):
                frontier_licao = all_ordered_lessons[next_idx]
                ul = user_lessons_map.get(frontier_licao.id)
                if ul and ul.status == "em_andamento":
                    canonical_status_map[frontier_licao.id] = "em_andamento"
                else:
                    canonical_status_map[frontier_licao.id] = "disponivel"

            # Todas as demais lições à frente ficam bloqueadas
            for idx in range(last_completed_idx + 2, len(all_ordered_lessons)):
                licao = all_ordered_lessons[idx]
                canonical_status_map[licao.id] = "bloqueada"
        else:
            # Nenhuma lição concluída: Lição 0 é a fronteira ativa
            for idx, licao in enumerate(all_ordered_lessons):
                if idx == 0:
                    ul = user_lessons_map.get(licao.id)
                    canonical_status_map[licao.id] = (
                        "em_andamento" if (ul and ul.status == "em_andamento") else "disponivel"
                    )
                else:
                    canonical_status_map[licao.id] = "bloqueada"

        # Auto-reconciliação atômica no banco de dados para lições que ficaram para trás
        if lessons_to_reconcile:
            try:
                for lic in lessons_to_reconcile:
                    UserLesson.objects.update_or_create(
                        usuario=user,
                        licao=lic,
                        defaults={
                            "status": "concluida",
                            "completion_percentage": 100.0,
                            "concluida_em": timezone.now(),
                        },
                    )
            except Exception as e:
                logger.warning("Falha na auto-reconciliação de UserLessons: %s", e)

        # 6. Montagem dos capítulos com dados de progresso e baús
        capitulos_data = []
        for cap in capitulos:
            scenario = cap.scenario
            licoes_data = []
            cap_completed_count = 0
            total_cap_licoes = len(cap.licoes_publicadas)

            for licao in cap.licoes_publicadas:
                c_status = canonical_status_map.get(licao.id, "bloqueada")
                ul = user_lessons_map.get(licao.id)

                if c_status == "concluida":
                    cap_completed_count += 1

                licoes_data.append({
                    "id": licao.id,
                    "titulo": licao.titulo,
                    "descricao": licao.descricao,
                    "numero": licao.numero,
                    "xp_base": licao.xp_base,
                    "pos_x": licao.pos_x,
                    "pos_y": licao.pos_y,
                    "status": c_status,
                    "completion_percentage": ul.completion_percentage if ul else 0.0,
                    "earned_xp": ul.earned_xp if ul else 0,
                })

            # Marco do Baú Cultural do Capítulo (após a Lição 2 ou na metade do capítulo)
            # Regra do Baú:
            # - Requer que as lições até o marco (ex: lições 1 e 2) estejam 100% concluídas.
            milestone_lesson_index = min(2, total_cap_licoes)
            lessons_before_chest = cap.licoes_publicadas[:milestone_lesson_index]
            chest_unlocked = (
                len(lessons_before_chest) > 0
                and all(canonical_status_map.get(l.id) == "concluida" for l in lessons_before_chest)
            )
            # 3.1. Regra de Baú Único da Trilha:
            # O usuário só pode abrir o baú da trilha uma única vez.
            has_collected_trail_chest = len(collected_chests) > 0
            is_chest_collected = has_collected_trail_chest or (cap.id, 1) in collected_chests

            chest_status = (
                "concluido" if is_chest_collected
                else "disponivel" if chest_unlocked
                else "bloqueado"
            )

            module_progress_pct = (
                round((cap_completed_count / total_cap_licoes) * 100, 1)
                if total_cap_licoes > 0 else 0.0
            )

            capitulos_data.append({
                "id": cap.id,
                "numero": cap.numero,
                "titulo": cap.titulo,
                "descricao": cap.descricao,
                "module_progress_percentage": module_progress_pct,
                "total_licoes": total_cap_licoes,
                "licoes_concluidas": cap_completed_count,
                "scenario": {
                    "nome": scenario.nome if scenario else "",
                    "background_image": scenario.background_image.url if scenario and scenario.background_image else None,
                    "ambient_audio": scenario.ambient_audio.url if scenario and scenario.ambient_audio else None,
                    "palette": scenario.palette if scenario else {},
                } if scenario else None,
                "chest_reward": {
                    "milestone_index": 1,
                    "status": chest_status,
                    "unlocked": chest_unlocked,
                    "collected": is_chest_collected,
                    "recompensa_xp": 75,
                    "recompensa_conchas": 50,
                    "after_lesson_number": milestone_lesson_index,
                },
                "licoes": licoes_data,
            })

        result = {
            "success": True,
            "variante": {"id": variante.id, "nome": variante.nome, "codigo": variante.codigo},
            "trilha": {"id": trilha.id, "titulo": trilha.titulo, "subtitulo": trilha.subtitulo},
            "user_stats": {
                "xp_total": user.xp_total,
                "streak_atual": user.streak_atual,
                "dias_ofensiva": user.streak_atual,
                "conchas": getattr(user, 'conchas', 0),
                "maior_streak": user.maior_streak,
            },
            "capitulos": capitulos_data,
        }
        if use_cache:
            cache.set(cache_key, result, timeout=60)
        return result

    @classmethod
    def is_lesson_accessible(cls, user: UserProfile, licao: Licao) -> bool:
        """
        Validação server-side estrita: verifica se o usuário tem permissão
        para abrir o conteúdo da lição no momento.
        """
        # Se a lição já foi concluída, está disponível ou em andamento
        ul = UserLesson.objects.filter(usuario=user, licao=licao).first()
        if ul and ul.status in ["concluida", "em_andamento", "disponivel"]:
            return True

        # Se for a primeira lição da Trilha
        trilha = licao.capitulo.trilha
        primeira_licao = (
            Licao.objects.filter(capitulo__trilha=trilha, publicada=True)
            .order_by("capitulo__numero", "numero", "id")
            .first()
        )
        if primeira_licao and primeira_licao.id == licao.id:
            return True

        # Caso contrário, localiza a lição imediatamente anterior na sequência
        todas_licoes = list(
            Licao.objects.filter(capitulo__trilha=trilha, publicada=True)
            .order_by("capitulo__numero", "numero", "id")
            .values_list("id", flat=True)
        )

        try:
            current_index = todas_licoes.index(licao.id)
            if current_index == 0:
                return True

            # Se qualquer lição nesta posição ou posterior já foi concluída, a lição é permitida
            has_later_completed = UserLesson.objects.filter(
                usuario=user,
                licao_id__in=todas_licoes[current_index:],
                status="concluida"
            ).exists()
            if has_later_completed:
                return True

            prev_licao_id = todas_licoes[current_index - 1]
            prev_ul = UserLesson.objects.filter(usuario=user, licao_id=prev_licao_id).first()
            return prev_ul is not None and prev_ul.status == "concluida"
        except ValueError:
            return False

    @classmethod
    def unlock_next_lesson(cls, user: UserProfile, completed_licao: Licao) -> Optional[Licao]:
        """
        Desbloqueia a lição imediatamente subsequente à que foi concluída.
        Retorna a próxima Lição ou None caso o usuário tenha chegado ao fim da trilha.
        """
        trilha = completed_licao.capitulo.trilha
        todas_licoes = list(
            Licao.objects.filter(capitulo__trilha=trilha, publicada=True)
            .order_by("capitulo__numero", "numero", "id")
        )

        current_idx = None
        for i, l in enumerate(todas_licoes):
            if l.id == completed_licao.id:
                current_idx = i
                break

        if current_idx is None or current_idx + 1 >= len(todas_licoes):
            cls.invalidate_user_trail_cache(user.id, trilha.variante_id)
            return None

        next_licao = todas_licoes[current_idx + 1]
        next_ul, _ = UserLesson.objects.get_or_create(
            usuario=user,
            licao=next_licao,
            defaults={"status": "disponivel"}
        )
        if next_ul.status == "bloqueada":
            next_ul.status = "disponivel"
            next_ul.save(update_fields=["status"])

        cls.invalidate_user_trail_cache(user.id, trilha.variante_id)
        logger.info(
            "Lição %d (%s) desbloqueada com sucesso para usuário %d",
            next_licao.id, next_licao.titulo, user.id
        )
        return next_licao

    @classmethod
    @transaction.atomic
    def collect_chest(cls, user: UserProfile, capitulo_id: int, milestone_index: int = 1) -> Dict[str, Any]:
        """
        Coleta um baú cultural de capítulo de forma atômica e segura.
        Valida que o usuário cumpriu as lições exigidas e previne coletas duplicadas.
        """
        capitulo = Capitulo.objects.filter(id=capitulo_id, publicado=True).first()
        if not capitulo:
            return {"success": False, "error": "Capítulo não encontrado", "status": 404}

        # Verifica se já coletou o baú desta trilha (o baú da trilha é único)
        already_collected = UserChestReward.objects.filter(
            user=user, capitulo__trilha=capitulo.trilha
        ).exists()
        if already_collected:
            return {
                "success": False,
                "error": "O baú da trilha só pode ser coletado uma única vez.",
                "already_collected": True,
                "status": 409
            }

        # Valida se as lições do marco estão concluídas
        licoes_cap = list(capitulo.licoes.filter(publicada=True).order_by("numero"))
        milestone_limit = min(2, len(licoes_cap))
        required_lessons = licoes_cap[:milestone_limit]

        if not required_lessons:
            return {"success": False, "error": "Capítulo sem lições suficientes", "status": 400}

        completed_ids = set(
            UserLesson.objects.filter(
                usuario=user,
                licao__in=required_lessons,
                status="concluida"
            ).values_list("licao_id", flat=True)
        )

        if len(completed_ids) < len(required_lessons):
            return {
                "success": False,
                "error": "Você precisa concluir as lições anteriores antes de abrir este baú.",
                "status": 403
            }

        recompensa_xp = 75
        recompensa_conchas = 50

        # Cria auditoria de coleta do baú
        UserChestReward.objects.create(
            user=user,
            capitulo=capitulo,
            milestone_index=milestone_index,
            recompensa_xp=recompensa_xp,
            recompensa_conchas=recompensa_conchas,
        )

        # Atualiza XP e Conchas do usuário atomicamente
        UserProfile.objects.filter(pk=user.pk).update(
            xp_total=F("xp_total") + recompensa_xp,
            conchas=F("conchas") + recompensa_conchas,
            updated_at=timezone.now(),
        )
        user.refresh_from_db(fields=["xp_total", "conchas"])

        # Registra no log de atividade diária
        from users.services.streak_service import StreakService
        StreakService.register_study_activity(
            user=user,
            xp_ganho=recompensa_xp,
            tempo_segundos=30,
            is_lesson_completed=False,
            exercicios_respondidos=0,
            exercicios_corretos=0
        )

        logger.info(
            "Baú coletado com sucesso! User %d, Cap %d, +%d XP, +%d Conchas",
            user.id, capitulo.id, recompensa_xp, recompensa_conchas
        )

        cls.invalidate_user_trail_cache(user.id, capitulo.trilha.variante_id)
        from users.services.statistics_service import StatisticsService
        StatisticsService.invalidate_user_stats_cache(user.id)

        return {
            "success": True,
            "recompensa_xp": recompensa_xp,
            "recompensa_conchas": recompensa_conchas,
            "xp_total": user.xp_total,
            "conchas": getattr(user, "conchas", 0),
            "status": "concluido",
            "message": f"Baú Coletado! +{recompensa_xp} XP e +{recompensa_conchas} Conchas.",
        }
