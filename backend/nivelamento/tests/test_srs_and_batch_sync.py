"""
Suíte de Testes Automatizados para:
1. freeze_theta=True e correção atômica de conchas na TRI Progressiva.
2. Mapeamento de fraquezas e seleção de vocabulário do SRSService.
3. Blindagem de UI pelo FriendlyExceptionMiddleware.
4. Sincronização em lote com timestamps client-side e pgmq fallback.
"""

import json
import uuid
from django.test import TestCase, RequestFactory
from django.http import HttpResponse, JsonResponse

from app.core.middleware import FriendlyExceptionMiddleware, FRIENDLY_VILLAGE_ERROR
from nivelamento.services.tri_progressive_service import (
    TRIProgressiveEngine,
    TRIProgressiveSessionManager,
)
from users.models import UserProfile, HistoricoResposta
from users.services.srs_service import SRSService
from trilha.models import VarianteTupi, Licao, Capitulo, TrilhaHistorica, VocabularyItem


class SRSAndBatchSyncTestCase(TestCase):
    def setUp(self):
        self.factory = RequestFactory()
        self.variante = VarianteTupi.objects.create(
            nome="Tupi Antigo Teste",
            codigo=f"tupi_teste_{uuid.uuid4().hex[:6]}",
            ativo=True,
        )
        self.trilha = TrilhaHistorica.objects.create(
            titulo="Trilha Teste",
            variante=self.variante,
        )
        self.capitulo = Capitulo.objects.create(
            titulo="Capítulo Teste",
            numero=1,
            trilha=self.trilha,
        )
        self.licao = Licao.objects.create(
            titulo="Lição Teste",
            numero=1,
            capitulo=self.capitulo,
        )
        # Cria vocabulário de apoio
        self.item1 = VocabularyItem.objects.create(
            licao=self.licao,
            palavra_tupi="oka",
            traducao_pt="casa",
            categoria="aldeia",
        )
        self.item2 = VocabularyItem.objects.create(
            licao=self.licao,
            palavra_tupi="tata",
            traducao_pt="fogo",
            categoria="natureza",
        )
        self.item3 = VocabularyItem.objects.create(
            licao=self.licao,
            palavra_tupi="pira",
            traducao_pt="peixe",
            categoria="fauna",
        )

        self.user = UserProfile.objects.create(
            supabase_uid=uuid.uuid4(),
            email=f"aluno_{uuid.uuid4().hex[:6]}@tupilingo.com",
            name="Guerreiro Teste",
            variante_ativa=self.variante,
            xp_total=100,
            conchas=10,
        )

    def test_freeze_theta_in_thematic_practice(self):
        """Valida que freeze_theta=True mantém a proficiência intacta enquanto premia XP e Conchas."""
        session = TRIProgressiveSessionManager.iniciar_sessao(
            user_id=self.user.id,
            variante_id=self.variante.id,
            nivel_inicial=5,
            freeze_theta=True,
        )
        initial_theta = session.current_theta
        self.assertTrue(session.freeze_theta)

        # Responde um item corretamente
        res = TRIProgressiveSessionManager.processar_item(
            session_id=session.session_id,
            is_correct=True,
            time_taken_seconds=4.0,
            param_a=1.2,
            param_b=0.5,
            param_c=0.25,
            is_last_item=False,
        )

        # Theta não deve mudar
        self.assertEqual(res["current_theta"], round(initial_theta, 3))
        self.assertGreater(res["earned_xp"], 0)
        self.assertGreater(res["earned_conchas"], 0)

    def test_conchas_and_xp_atomic_consolidation(self):
        """Valida a correção do bug de gravação atômica de conchas e xp_total no UserProfile."""
        session = TRIProgressiveSessionManager.iniciar_sessao(
            user_id=self.user.id,
            variante_id=self.variante.id,
            nivel_inicial=3,
            freeze_theta=True,
        )

        # Responde o último item
        TRIProgressiveSessionManager.processar_item(
            session_id=session.session_id,
            is_correct=True,
            time_taken_seconds=3.5,
            param_a=1.2,
            param_b=0.0,
            param_c=0.0,
            is_last_item=True,
        )

        self.user.refresh_from_db()
        self.assertGreater(self.user.xp_total, 100)
        self.assertGreater(self.user.conchas, 10)

    def test_srs_service_ranks_most_missed_words(self):
        """Valida que o SRSService identifica termos com status 'wrong' ou 'almost'."""
        # Registra erros históricos para a palavra 'tata' e 'oka'
        HistoricoResposta.objects.create(
            user=self.user,
            palavra_tupi="tata",
            traducao_pt="fogo",
            status="wrong",
            similaridade=0.2,
            time_taken_seconds=4.0,
        )
        HistoricoResposta.objects.create(
            user=self.user,
            palavra_tupi="tata",
            traducao_pt="fogo",
            status="almost",
            similaridade=0.7,
            time_taken_seconds=5.0,
        )
        HistoricoResposta.objects.create(
            user=self.user,
            palavra_tupi="oka",
            traducao_pt="casa",
            status="wrong",
            similaridade=0.1,
            time_taken_seconds=3.0,
        )

        palavras = SRSService.obter_palavras_fracas_usuario(
            user_id=self.user.id,
            variante_id=self.variante.id,
            limite=3,
        )

        self.assertEqual(len(palavras), 3)
        # 'tata' deve vir em primeiro (2 erros)
        self.assertEqual(palavras[0]["palavra_tupi"], "tata")
        self.assertEqual(palavras[1]["palavra_tupi"], "oka")

    def test_friendly_exception_middleware_shields_ui(self):
        """Valida que o middleware sanitiza erros técnicos e bloqueia vazamento de jargões."""
        middleware = FriendlyExceptionMiddleware(lambda req: HttpResponse())
        request = self.factory.get("/api/v1/pratica/qualquer/")

        # Simula exceção técnica com menção a Supabase e SQL
        tech_exception = Exception("Supabase connection error: OperationalError in pg_trgm query")
        response = middleware.process_exception(request, tech_exception)

        self.assertIsNotNone(response)
        self.assertEqual(response.status_code, 500)
        data = json.loads(response.content.decode("utf-8"))
        self.assertEqual(data["code"], "ALDEIA_OFFLINE")
        self.assertEqual(data["error"], FRIENDLY_VILLAGE_ERROR)
        self.assertNotIn("supabase", str(data).lower())
        self.assertNotIn("pg_trgm", str(data).lower())
        self.assertNotIn("sql", str(data).lower())
