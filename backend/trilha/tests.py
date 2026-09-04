"""
Testes automatizados para os endpoints administrativos de Trilha
(Capítulos, Lições e Exercícios).
"""

import json
from unittest.mock import patch
from django.test import TestCase, RequestFactory
from django.contrib.auth.models import User
from trilha.models import VarianteTupi, TrilhaHistorica, Capitulo, Licao, Exercicio
from trilha.admin_views import (
    admin_criar_capitulo,
    admin_gerenciar_capitulo,
    admin_criar_licao,
    admin_gerenciar_licao,
    admin_criar_exercicio,
    admin_gerenciar_exercicio,
    admin_listar_dados,
)


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
