"""
Testes automatizados para os endpoints administrativos de Trilha
(Capítulos, Lições e Exercícios).
"""

import json
from unittest.mock import patch

from django.contrib.auth.models import User
from django.test import RequestFactory, TestCase

from trilha.admin_views import (
    admin_criar_capitulo,
    admin_criar_exercicio,
    admin_criar_licao,
    admin_gerenciar_capitulo,
    admin_listar_dados,
)
from trilha.models import Capitulo, Exercicio, Licao, TrilhaHistorica, VarianteTupi


class TrilhaAdminViewsTests(TestCase):
    def setUp(self):
        self.factory = RequestFactory()
        self.admin_user = User.objects.create(
            username="admin_teste",
            email="admin@tupilingo.com",
            is_staff=True,
            is_superuser=True,
        )
        self.variante = VarianteTupi.objects.create(
            nome="Tupi Antigo Teste",
            codigo="tupi_antigo_teste",
            ordem=1,
            ativo=True,
        )
        self.trilha = TrilhaHistorica.objects.create(
            variante=self.variante,
            titulo="Trilha Teste",
            publicada=True,
        )

    def _auth_request(self, request, email="admin@tupilingo.com"):
        request.user_data = {
            "sub": "00000000-0000-0000-0000-000000000001",
            "email": email,
        }
        return request

    @patch("users.decorators.jwks_client")
    def test_bloqueio_sem_permissao_staff(self, mock_jwks):
        """Usuário comum sem staff deve receber 403 ao tentar criar capítulo."""
        request = self.factory.post(
            "/api/v1/admin/trilha/capitulos/",
            data=json.dumps({"titulo": "Novo Cap"}),
            content_type="application/json",
            HTTP_AUTHORIZATION="Bearer token_invalido",
        )
        request = self._auth_request(request, email="aluno@tupilingo.com")
        response = admin_criar_capitulo(request)
        self.assertEqual(response.status_code, 403)

    @patch("users.decorators.jwks_client")
    def test_crud_capitulo(self, mock_jwks):
        """Testa criação, edição e exclusão de capítulo pelo admin."""
        # 1. Criar
        create_data = {
            "trilha_id": self.trilha.id,
            "numero": 1,
            "titulo": "Capítulo Ancestral 1",
            "descricao": "História inicial",
            "publicado": True,
        }
        request = self.factory.post(
            "/api/v1/admin/trilha/capitulos/",
            data=json.dumps(create_data),
            content_type="application/json",
            HTTP_AUTHORIZATION="Bearer valid_token",
        )
        request = self._auth_request(request)
        response = admin_criar_capitulo(request)
        self.assertEqual(response.status_code, 201)
        cap_id = json.loads(response.content)["capitulo"]["id"]

        # 2. Editar
        edit_data = {"titulo": "Capítulo Ancestral 1 (Modificado)"}
        request = self.factory.put(
            f"/api/v1/admin/trilha/capitulos/{cap_id}/",
            data=json.dumps(edit_data),
            content_type="application/json",
            HTTP_AUTHORIZATION="Bearer valid_token",
        )
        request = self._auth_request(request)
        response = admin_gerenciar_capitulo(request, capitulo_id=cap_id)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(Capitulo.objects.get(id=cap_id).titulo, "Capítulo Ancestral 1 (Modificado)")

        # 3. Excluir
        request = self.factory.delete(
            f"/api/v1/admin/trilha/capitulos/{cap_id}/",
            HTTP_AUTHORIZATION="Bearer valid_token",
        )
        request = self._auth_request(request)
        response = admin_gerenciar_capitulo(request, capitulo_id=cap_id)
        self.assertEqual(response.status_code, 200)
        self.assertFalse(Capitulo.objects.filter(id=cap_id).exists())

    @patch("users.decorators.jwks_client")
    def test_crud_licao_e_exercicio(self, mock_jwks):
        """Testa criação de lição e exercício unificado de múltipla escolha."""
        cap = Capitulo.objects.create(trilha=self.trilha, numero=1, titulo="Cap 1", publicado=True)

        # 1. Criar Lição
        lic_data = {
            "capitulo_id": cap.id,
            "numero": 1,
            "titulo": "Lição das Árvores",
            "descricao": "Primeiras palavras",
            "xp_base": 30,
            "publicada": True,
        }
        request = self.factory.post(
            "/api/v1/admin/trilha/licoes/",
            data=json.dumps(lic_data),
            content_type="application/json",
            HTTP_AUTHORIZATION="Bearer valid_token",
        )
        request = self._auth_request(request)
        response = admin_criar_licao(request)
        self.assertEqual(response.status_code, 201)
        lic_id = json.loads(response.content)["licao"]["id"]

        # 2. Criar Exercício Múltipla Escolha
        ex_data = {
            "licao_id": lic_id,
            "tipo": "escolha_multipla",
            "enunciado": "O que significa Y?",
            "explicacao": "Y significa água ou rio.",
            "opcoes": ["Água", "Fogo", "Terra", "Vento"],
            "resposta_correta": 0,
            "pontos_base": 15,
        }
        request = self.factory.post(
            "/api/v1/admin/trilha/exercicios/",
            data=json.dumps(ex_data),
            content_type="application/json",
            HTTP_AUTHORIZATION="Bearer valid_token",
        )
        request = self._auth_request(request)
        response = admin_criar_exercicio(request)
        self.assertEqual(response.status_code, 201)
        ex_id = json.loads(response.content)["exercicio"]["id"]

        # 3. Verificar listagem geral
        request = self.factory.get("/api/v1/admin/trilha/dados/", HTTP_AUTHORIZATION="Bearer valid_token")
        request = self._auth_request(request)
        response = admin_listar_dados(request)
        self.assertEqual(response.status_code, 200)
        dados = json.loads(response.content)
        self.assertTrue(dados["success"])
        self.assertTrue(len(dados["variantes"]) > 0)


class TrilhaProgressionEndToEndTests(TestCase):
    def setUp(self):
        self.factory = RequestFactory()
        import uuid

        from users.models import UserProfile

        from trilha.models import Capitulo, TrilhaHistorica, VarianteTupi

        self.student = UserProfile.objects.create(
            supabase_uid=uuid.uuid4(),
            email="aluno_teste@tupilingo.com",
            name="Aluno Teste",
        )
        self.variante = VarianteTupi.objects.create(
            nome="Tupi Antigo Teste",
            codigo="tupi_antigo_teste",
            ordem=1,
            ativo=True,
        )
        self.trilha = TrilhaHistorica.objects.create(
            variante=self.variante,
            titulo="Trilha Teste",
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
        self.ex1 = Exercicio.objects.create(
            licao=self.licao1,
            tipo="escolha_multipla",
            enunciado="Questão 1",
            ordem=1,
            pontos_base=10,
        )

    def _auth_request(self, request):
        request.user_data = {
            "sub": str(self.student.supabase_uid),
            "email": self.student.email,
        }
        return request

    @patch("users.decorators.jwks_client")
    def test_progression_flow_non_admin_no_403(self, mock_jwks):
        """
        Garante que o aluno não-admin:
        1. Acessa a primeira lição sem erro 403.
        2. Conclui a lição e desbloqueia a próxima de forma persistida.
        3. A listagem de capítulos reflete a lição 2 disponível sem rollback.
        """
        from users.models import UserLesson

        from trilha.views import concluir_licao, detalhe_licao, listar_capitulos_mapa

        # 1. Acessar Lição 1
        req1 = self.factory.get(f"/api/v1/trilha/licao/{self.licao1.id}/", HTTP_AUTHORIZATION="Bearer token")
        req1 = self._auth_request(req1)
        res1 = detalhe_licao(req1, licao_id=self.licao1.id)
        self.assertEqual(res1.status_code, 200, "Aluno comum não deve receber 403 ao acessar a lição inicial.")

        ul1 = UserLesson.objects.get(usuario=self.student, licao=self.licao1)
        self.assertEqual(ul1.status, "em_andamento")

        # 2. Concluir Lição 1
        payload = {
            "acertos": 1,
            "total_exercicios": 1,
            "tempo_segundos": 45,
            "primeira_tentativa": True,
        }
        req2 = self.factory.post(
            f"/api/v1/trilha/licao/{self.licao1.id}/concluir/",
            data=json.dumps(payload),
            content_type="application/json",
            HTTP_AUTHORIZATION="Bearer token",
        )
        req2 = self._auth_request(req2)
        res2 = concluir_licao(req2, licao_id=self.licao1.id)
        self.assertEqual(res2.status_code, 200)
        data2 = json.loads(res2.content)
        self.assertTrue(data2["success"])
        self.assertEqual(data2["proxima_licao_id"], self.licao2.id)
        self.assertTrue(data2["proxima_licao_desbloqueada"])

        ul1.refresh_from_db()
        self.assertEqual(ul1.status, "concluida")

        ul2 = UserLesson.objects.get(usuario=self.student, licao=self.licao2)
        self.assertEqual(ul2.status, "disponivel")

        # 3. Listar capítulos do mapa (sem cache desatualizado)
        req3 = self.factory.get(f"/api/v1/trilha/{self.variante.id}/capitulos/", HTTP_AUTHORIZATION="Bearer token")
        req3 = self._auth_request(req3)
        res3 = listar_capitulos_mapa(req3, variante_id=self.variante.id)
        self.assertEqual(res3.status_code, 200)
        data3 = json.loads(res3.content)
        licoes_retornadas = data3["capitulos"][0]["licoes"]
        self.assertEqual(licoes_retornadas[0]["status"], "concluida")
        self.assertEqual(licoes_retornadas[1]["status"], "disponivel")

