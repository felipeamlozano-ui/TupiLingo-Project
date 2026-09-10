"""
Testes automatizados para o achievement_service e recalibração de nível.
"""

import uuid

from django.test import TestCase
from django.utils import timezone
from nivelamento.models import UserVarianteLevel
from trilha.models import Capitulo, Licao, TrilhaHistorica, VarianteTupi
from trilha.views import _recalibrar_nivel

from users.models import UserLesson, UserProfile
from users.services.achievement_service import (
    check_and_grant_lesson_achievements,
    check_and_grant_xp_achievements,
)


class AchievementServiceTests(TestCase):
    def setUp(self):
        self.user = UserProfile.objects.create(
            supabase_uid=uuid.uuid4(),
            email="teste.guerreiro@tupilingo.com",
            name="Guerreiro Teste",
            xp_total=0,
        )
        self.variante = VarianteTupi.objects.create(
            nome="Tupi Antigo Teste",
            codigo="tupi_teste",
            ordem=1,
            ativo=True,
        )
        self.trilha = TrilhaHistorica.objects.create(
            variante=self.variante,
            titulo="Trilha de Teste",
            publicada=True,
        )
        self.capitulo = Capitulo.objects.create(
            trilha=self.trilha,
            numero=1,
            titulo="Capítulo 1",
            publicado=True,
        )
        self.licao1 = Licao.objects.create(
            capitulo=self.capitulo,
            numero=1,
            titulo="Lição 1",
            xp_base=25,
            publicada=True,
        )
        self.licao2 = Licao.objects.create(
            capitulo=self.capitulo,
            numero=2,
            titulo="Lição 2",
            xp_base=25,
            publicada=True,
        )
        self.licao3 = Licao.objects.create(
            capitulo=self.capitulo,
            numero=3,
            titulo="Lição 3",
            xp_base=25,
            publicada=True,
        )

    def test_xp_achievements_granting(self):
        """Testa concessão automática de conquistas por limiar de XP."""
        # Inicialmente a 0 XP deve conceder 'xp_semente'
        novas = check_and_grant_xp_achievements(self.user)
        codigos = [a.codigo for a in novas]
        self.assertIn("xp_semente", codigos)
        self.assertNotIn("xp_folha", codigos)

        # Não concede duplicado
        repetidas = check_and_grant_xp_achievements(self.user)
        self.assertEqual(len(repetidas), 0)

        # Ao atingir 500 XP, deve conceder 'xp_folha'
        self.user.xp_total = 550
        self.user.save()
        novas_500 = check_and_grant_xp_achievements(self.user)
        codigos_500 = [a.codigo for a in novas_500]
        self.assertIn("xp_folha", codigos_500)

    def test_lesson_achievements(self):
        """Testa conquistas por conclusão de lição e acurácia perfeita."""
        novas = check_and_grant_lesson_achievements(
            self.user, self.licao1, accuracy=1.0
        )
        codigos = [a.codigo for a in novas]
        self.assertIn("cultural_primeira_licao", codigos)
        self.assertIn("cultural_perfeicao", codigos)

    def test_nivel_recalibration_promotion(self):
        """Testa calibração positiva do nível ao acertar >= 85% nas últimas 3 lições."""
        lvl_obj, _ = UserVarianteLevel.objects.get_or_create(
            user=self.user, variante=self.variante, defaults={"nivel": 2}
        )
        self.assertEqual(lvl_obj.nivel, 2)

        # Conclui 3 lições com 90% de acerto
        for licao in [self.licao1, self.licao2, self.licao3]:
            UserLesson.objects.create(
                usuario=self.user,
                licao=licao,
                status="concluida",
                accuracy=0.90,
                concluida_em=timezone.now(),
            )

        novo_nivel = _recalibrar_nivel(self.user, self.variante)
        self.assertEqual(novo_nivel, 3)

    def test_nivel_recalibration_demotion(self):
        """Testa calibração negativa do nível ao ter <= 40% nas últimas 3 lições."""
        lvl_obj, _ = UserVarianteLevel.objects.get_or_create(
            user=self.user, variante=self.variante, defaults={"nivel": 4}
        )
        self.assertEqual(lvl_obj.nivel, 4)

        for licao in [self.licao1, self.licao2, self.licao3]:
            UserLesson.objects.create(
                usuario=self.user,
                licao=licao,
                status="concluida",
                accuracy=0.30,
                concluida_em=timezone.now(),
            )

        novo_nivel = _recalibrar_nivel(self.user, self.variante)
        self.assertEqual(novo_nivel, 3)
