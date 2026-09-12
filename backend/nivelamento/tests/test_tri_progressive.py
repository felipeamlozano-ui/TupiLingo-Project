"""
Testes unitários do motor progressivo de TRI e prevenção de chutes.
"""

from django.test import TestCase
from nivelamento.services.tri_progressive_service import (
    TRIProgressiveEngine,
    TRIProgressiveSessionManager,
)


class TRIProgressiveEngineTestCase(TestCase):
    def test_level_to_theta_and_back(self):
        # Nível 1 deve dar theta negativo
        t1 = TRIProgressiveEngine.level_to_theta(1)
        self.assertLess(t1, -1.5)
        # Nível 5-6 deve dar theta perto de 0
        t5 = TRIProgressiveEngine.level_to_theta(5)
        self.assertAlmostEqual(t5, -0.28, delta=0.5)
        # Nível 10 deve dar theta alto
        t10 = TRIProgressiveEngine.level_to_theta(10)
        self.assertGreater(t10, 1.5)

    def test_detectar_chute_speedrun(self):
        # Usuário com theta baixo acertando questão difícil em 0.8s
        chute, gamma = TRIProgressiveEngine.detectar_chute_matematico(
            theta_anterior=-1.5,
            a=1.4,
            b=1.8,
            c=0.25,
            is_correct=True,
            time_taken_seconds=0.8,
        )
        self.assertTrue(chute)
        self.assertGreater(gamma, 0.5)

    def test_nao_detectar_chute_resposta_pensada(self):
        # Usuário com theta 0.5 acertando questão moderada b=0.2 em 4.5 segundos
        chute, gamma = TRIProgressiveEngine.detectar_chute_matematico(
            theta_anterior=0.5,
            a=1.2,
            b=0.2,
            c=0.25,
            is_correct=True,
            time_taken_seconds=4.5,
        )
        self.assertFalse(chute)

    def test_recompensas_sem_chute_vs_com_chute(self):
        # Questão moderada b=0.5
        xp_real, conchas_real = TRIProgressiveEngine.calcular_recompensas(
            b=0.5, is_correct=True, suspected_guess=False
        )
        self.assertGreaterEqual(xp_real, 10)
        self.assertGreater(conchas_real, 0)

        # Mesma questão com chute detectado
        xp_chute, conchas_chute = TRIProgressiveEngine.calcular_recompensas(
            b=0.5, is_correct=True, suspected_guess=True
        )
        self.assertLess(xp_chute, xp_real)
        self.assertEqual(conchas_chute, 0)

    def test_update_step_convergencia(self):
        # Sequência de 4 acertos sucessivos deve aumentar theta
        theta = 0.0
        info = 1.0
        for _ in range(4):
            theta, info, sem = TRIProgressiveEngine.update_step(
                current_theta=theta,
                current_info=info,
                a=1.3,
                b=0.5,
                c=0.25,
                is_correct=True,
            )
        self.assertGreater(theta, 0.0)
        self.assertGreater(info, 1.0)
        self.assertLess(sem, 1.0)

    def test_session_manager_flow(self):
        session = TRIProgressiveSessionManager.iniciar_sessao(
            user_id=9999, variante_id=1, nivel_inicial=3
        )
        self.assertIsNotNone(session.session_id)

        # Responde item 1
        res1 = TRIProgressiveSessionManager.processar_item(
            session_id=session.session_id,
            is_correct=True,
            time_taken_seconds=3.2,
            param_a=1.2,
            param_b=0.0,
            param_c=0.25,
            is_last_item=False,
        )
        self.assertEqual(res1["answers_count"], 1)
        self.assertGreater(res1["earned_xp"], 0)
        self.assertLess(res1["server_latency_ms"], 50)  # Menos de 50ms!
