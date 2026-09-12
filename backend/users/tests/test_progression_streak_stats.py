import datetime
from django.test import TestCase
from django.utils import timezone

from users.models import UserProfile, UserLesson, DailyStudyLog
from trilha.models import VarianteTupi, TrilhaHistorica, Capitulo, Licao, UserChestReward
from users.services.progress_service import ProgressService
from users.services.streak_service import StreakService
from users.services.statistics_service import StatisticsService


class ProgressionAndStreakTests(TestCase):
    def setUp(self):
        # 1. Usuário de teste
        self.user = UserProfile.objects.create(
            supabase_uid="00000000-0000-0000-0000-000000000001",
            email="progression.test@tupilingo.com",
            name="Guerreiro Teste",
            xp_total=0,
            streak_atual=0,
            maior_streak=0,
            dias_estudados_total=0,
        )

        # 2. Trilha, capítulos e lições
        self.variante = VarianteTupi.objects.create(
            nome="Tupi Teste",
            codigo="tupi_teste",
            ativo=True,
            ordem=1
        )
        self.trilha = TrilhaHistorica.objects.create(
            variante=self.variante,
            titulo="Trilha Ancestral",
            publicada=True
        )
        self.capitulo = Capitulo.objects.create(
            trilha=self.trilha,
            numero=1,
            titulo="Capítulo 1: Origens",
            publicado=True
        )
        self.licao1 = Licao.objects.create(
            capitulo=self.capitulo,
            numero=1,
            titulo="Lição 1: Saudações",
            xp_base=25,
            publicada=True
        )
        self.licao2 = Licao.objects.create(
            capitulo=self.capitulo,
            numero=2,
            titulo="Lição 2: A Aldeia",
            xp_base=30,
            publicada=True
        )
        self.licao3 = Licao.objects.create(
            capitulo=self.capitulo,
            numero=3,
            titulo="Lição 3: A Floresta",
            xp_base=35,
            publicada=True
        )

    def test_first_lesson_is_accessible_and_subsequent_are_locked(self):
        """Para um novo usuário, a Lição 1 deve ser acessível e a Lição 2 bloqueada."""
        self.assertTrue(ProgressService.is_lesson_accessible(self.user, self.licao1))
        self.assertFalse(ProgressService.is_lesson_accessible(self.user, self.licao2))
        self.assertFalse(ProgressService.is_lesson_accessible(self.user, self.licao3))

    def test_progression_structure_resolves_canonically(self):
        """A estrutura do mapa deve trazer status estrito e baú bloqueado."""
        trail = ProgressService.get_trail_structure_with_progression(self.user, self.variante)
        self.assertTrue(trail["success"])
        cap_data = trail["capitulos"][0]
        self.assertEqual(cap_data["chest_reward"]["status"], "bloqueado")
        self.assertFalse(cap_data["chest_reward"]["unlocked"])
        self.assertEqual(cap_data["licoes"][0]["status"], "disponivel")
        self.assertEqual(cap_data["licoes"][1]["status"], "bloqueada")

    def test_unlock_next_lesson_and_chest_milestone(self):
        """Ao concluir a Lição 1 e 2, a Lição 3 e o Baú devem ser liberados."""
        # Conclui Lição 1
        UserLesson.objects.create(
            usuario=self.user,
            licao=self.licao1,
            status="concluida",
            completion_percentage=100.0,
            earned_xp=25
        )
        prox = ProgressService.unlock_next_lesson(self.user, self.licao1)
        self.assertEqual(prox.id, self.licao2.id)
        self.assertTrue(ProgressService.is_lesson_accessible(self.user, self.licao2))

        # Baú ainda bloqueado (requer Lição 1 e 2)
        res_chest_early = ProgressService.collect_chest(self.user, self.capitulo.id, milestone_index=1)
        self.assertFalse(res_chest_early["success"])
        self.assertEqual(res_chest_early["status"], 403)

        # Conclui Lição 2
        ul2 = UserLesson.objects.get(usuario=self.user, licao=self.licao2)
        ul2.status = "concluida"
        ul2.completion_percentage = 100.0
        ul2.earned_xp = 30
        ul2.save()
        ProgressService.unlock_next_lesson(self.user, self.licao2)
        self.assertTrue(ProgressService.is_lesson_accessible(self.user, self.licao3))

        # Coleta de baú deve ter sucesso
        res_chest = ProgressService.collect_chest(self.user, self.capitulo.id, milestone_index=1)
        self.assertTrue(res_chest["success"])
        self.assertEqual(res_chest["recompensa_xp"], 75)
        self.assertEqual(res_chest["recompensa_conchas"], 50)

        # Coleta duplicada deve retornar erro 409
        res_dup = ProgressService.collect_chest(self.user, self.capitulo.id, milestone_index=1)
        self.assertFalse(res_dup["success"])
        self.assertEqual(res_dup["status"], 409)

    def test_streak_service_and_statistics(self):
        """Registro de atividade diária deve computar streak e estatísticas autênticas."""
        res_streak = StreakService.register_study_activity(
            user=self.user,
            xp_ganho=50,
            tempo_segundos=120,
            is_lesson_completed=True,
            exercicios_respondidos=5,
            exercicios_corretos=5
        )
        self.assertTrue(res_streak["success"])
        self.assertEqual(res_streak["streak_atual"], 1)

        # Verifica estatísticas do dashboard
        stats = StatisticsService.get_dashboard_stats(self.user)
        self.assertTrue(stats["success"])
        self.assertFalse(stats["is_empty_state"])
        self.assertGreaterEqual(stats["xp_total"], 50)
        self.assertEqual(stats["dias_ofensiva"], 1)
        self.assertEqual(len(stats["weekly_activity"]), 7)

    def test_canonical_progression_heals_inconsistent_prior_lessons(self):
        """
        Se o usuário completou uma lição posterior (ex: lição 3),
        todas as lições anteriores (lições 1 e 2) devem ser canonicamente 'concluida'
        tanto na resposta da API quanto no banco de dados, evitando apontar para lições anteriores.
        """
        licao4 = Licao.objects.create(
            capitulo=self.capitulo,
            numero=4,
            titulo="Lição 4: O Teste",
            xp_base=40,
            publicada=True
        )
        licao5 = Licao.objects.create(
            capitulo=self.capitulo,
            numero=5,
            titulo="Lição 5: Conquista",
            xp_base=45,
            publicada=True
        )

        # Simula inconsistência: lição 2 em_andamento, lição 1 sem registro, lição 3 concluída
        UserLesson.objects.create(
            usuario=self.user,
            licao=self.licao2,
            status="em_andamento",
            completion_percentage=50.0
        )
        UserLesson.objects.create(
            usuario=self.user,
            licao=self.licao3,
            status="concluida",
            completion_percentage=100.0,
            earned_xp=35
        )

        trail = ProgressService.get_trail_structure_with_progression(self.user, self.variante)
        self.assertTrue(trail["success"])
        licoes_data = trail["capitulos"][0]["licoes"]
        status_by_id = {l["id"]: l["status"] for l in licoes_data}

        # Lições anteriores e a própria concluída DEVEM ser 'concluida'
        self.assertEqual(status_by_id[self.licao1.id], "concluida")
        self.assertEqual(status_by_id[self.licao2.id], "concluida")
        self.assertEqual(status_by_id[self.licao3.id], "concluida")

        # Lição imediatamente subsequente deve ser 'disponivel'
        self.assertEqual(status_by_id[licao4.id], "disponivel")

        # Lições posteriores devem ser 'bloqueada'
        self.assertEqual(status_by_id[licao5.id], "bloqueada")

        # Verifica auto-reconciliação no banco
        ul1 = UserLesson.objects.get(usuario=self.user, licao=self.licao1)
        self.assertEqual(ul1.status, "concluida")
        self.assertEqual(ul1.completion_percentage, 100.0)

        ul2 = UserLesson.objects.get(usuario=self.user, licao=self.licao2)
        self.assertEqual(ul2.status, "concluida")
        self.assertEqual(ul2.completion_percentage, 100.0)
