"""
Testes do endpoint/view da API REST de nivelamento.

Testa:
- Payload válido → 200
- Payload inválido → 400
- Método GET → 405
- Auth ausente/inválida → 401
- Erro interno → 500
"""

from __future__ import annotations

import json
from unittest.mock import MagicMock, patch

from django.test import TestCase, override_settings
from trilha.models import VarianteTupi
from users.models import UserProfile

VALID_PAYLOAD = {
    "nivel_atual": 3,
    "variante_id": 1,
    "acertou_anterior": True,
}

ENDPOINT = "/api/v1/nivelamento/gerar-questao/"

# Mocks para o decorator de autenticação JWT
MOCK_JWT_PAYLOAD = {"sub": "12345678-1234-1234-1234-123456789abc"}


@override_settings(RATELIMIT_ENABLE=False)
class WebhookViewTest(TestCase):
    """Testes para o endpoint gerar_questao_nivelamento via API Auth."""

    def setUp(self) -> None:
        super().setUp()
        self.user = UserProfile.objects.create(
            supabase_uid="12345678-1234-1234-1234-123456789abc",
            email="teste@tupilingo.com",
            name="Tester",
        )
        self.variante = VarianteTupi.objects.create(
            id=1,
            codigo="tupi",
            nome="Tupi Antigo",
            ativo=True,
        )

    # Método HTTP (Sem Autenticação)
    def test_get_sem_auth_retorna_401(self) -> None:
        """GET sem token deve retornar 401 Unauthorized."""
        response = self.client.get(ENDPOINT)
        self.assertEqual(response.status_code, 401)

    def test_put_sem_auth_retorna_401(self) -> None:
        """PUT sem token deve retornar 401 Unauthorized."""
        response = self.client.put(
            ENDPOINT,
            data=json.dumps(VALID_PAYLOAD),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 401)

    # Método HTTP (Com Autenticação)
    @patch("users.decorators.jwt.decode", return_value=MOCK_JWT_PAYLOAD)
    @patch("users.decorators.jwks_client.get_signing_key_from_jwt")
    def test_get_com_auth_retorna_405(self, mock_get_key: MagicMock, mock_decode: MagicMock) -> None:
        """GET com token válido deve passar do decorator e retornar 405 Method Not Allowed."""
        response = self.client.get(ENDPOINT, HTTP_AUTHORIZATION="Bearer token_valido")
        self.assertEqual(response.status_code, 405)

    @patch("users.decorators.jwt.decode", return_value=MOCK_JWT_PAYLOAD)
    @patch("users.decorators.jwks_client.get_signing_key_from_jwt")
    def test_put_com_auth_retorna_405(self, mock_get_key: MagicMock, mock_decode: MagicMock) -> None:
        """PUT com token válido deve passar do decorator e retornar 405 Method Not Allowed."""
        response = self.client.put(
            ENDPOINT,
            data=json.dumps(VALID_PAYLOAD),
            content_type="application/json",
            HTTP_AUTHORIZATION="Bearer token_valido"
        )
        self.assertEqual(response.status_code, 405)

    # Autenticação JWT (Supabase)
    def test_auth_ausente_retorna_401(self) -> None:
        """POST sem header Authorization deve retornar 401."""
        response = self.client.post(
            ENDPOINT,
            data=json.dumps(VALID_PAYLOAD),
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 401)
        data = response.json()
        self.assertEqual(data["error"], "Token ausente")

    @patch("users.decorators.jwt.decode", side_effect=Exception("Expirado"))
    @patch("users.decorators.jwks_client.get_signing_key_from_jwt")
    def test_auth_invalida_retorna_401(self, mock_get_key: MagicMock, mock_decode: MagicMock) -> None:
        """POST com token inválido deve retornar 401."""
        response = self.client.post(
            ENDPOINT,
            data=json.dumps(VALID_PAYLOAD),
            content_type="application/json",
            HTTP_AUTHORIZATION="Bearer token_invalido",
        )
        self.assertEqual(response.status_code, 401)
        data = response.json()
        self.assertEqual(data["error"], "Token inválido ou expirado")

    @patch("users.decorators.jwt.decode", return_value={"algum_dado": "mas_sem_sub"})
    @patch("users.decorators.jwks_client.get_signing_key_from_jwt")
    def test_auth_sem_sub_retorna_401(self, mock_get_key: MagicMock, mock_decode: MagicMock) -> None:
        """POST com token válido mas sem 'sub' deve retornar 401 estruturado pela view."""
        response = self.client.post(
            ENDPOINT,
            data=json.dumps(VALID_PAYLOAD),
            content_type="application/json",
            HTTP_AUTHORIZATION="Bearer token_valido",
        )
        self.assertEqual(response.status_code, 401)
        data = response.json()
        self.assertEqual(data["error"]["code"], "UNAUTHORIZED")

    # Payload inválido
    @patch("users.decorators.jwt.decode", return_value=MOCK_JWT_PAYLOAD)
    @patch("users.decorators.jwks_client.get_signing_key_from_jwt")
    def test_body_nao_json_retorna_400(self, mock_get_key: MagicMock, mock_decode: MagicMock) -> None:
        """Body não-JSON deve retornar 400."""
        response = self.client.post(
            ENDPOINT,
            data="isto não é json",
            content_type="application/json",
            HTTP_AUTHORIZATION="Bearer token_valido",
        )
        self.assertEqual(response.status_code, 400)
        data = response.json()
        self.assertEqual(data["error"]["code"], "INVALID_JSON")

    @patch("users.decorators.jwt.decode", return_value=MOCK_JWT_PAYLOAD)
    @patch("users.decorators.jwks_client.get_signing_key_from_jwt")
    def test_campos_faltando_retorna_400(self, mock_get_key: MagicMock, mock_decode: MagicMock) -> None:
        """Payload sem campos obrigatórios deve retornar 400."""
        response = self.client.post(
            ENDPOINT,
            data=json.dumps({"acertou_anterior": True}),  # Faltando nivel_atual
            content_type="application/json",
            HTTP_AUTHORIZATION="Bearer token_valido",
        )
        self.assertEqual(response.status_code, 400)
        data = response.json()
        self.assertEqual(data["error"]["code"], "INVALID_PAYLOAD")

    @patch("users.decorators.jwt.decode", return_value=MOCK_JWT_PAYLOAD)
    @patch("users.decorators.jwks_client.get_signing_key_from_jwt")
    def test_nivel_fora_do_range_retorna_400(self, mock_get_key: MagicMock, mock_decode: MagicMock) -> None:
        """Nível fora do range 1-10 deve retornar 400."""
        payload = {
            "nivel_atual": 15,
            "acertou_anterior": True,
        }
        response = self.client.post(
            ENDPOINT,
            data=json.dumps(payload),
            content_type="application/json",
            HTTP_AUTHORIZATION="Bearer token_valido",
        )
        self.assertEqual(response.status_code, 400)

    @patch("users.decorators.jwt.decode", return_value=MOCK_JWT_PAYLOAD)
    @patch("users.decorators.jwks_client.get_signing_key_from_jwt")
    def test_acertou_anterior_nao_bool_retorna_400(self, mock_get_key: MagicMock, mock_decode: MagicMock) -> None:
        """acertou_anterior não booleano deve retornar 400."""
        payload = {
            "nivel_atual": 3,
            "acertou_anterior": "sim",
        }
        response = self.client.post(
            ENDPOINT,
            data=json.dumps(payload),
            content_type="application/json",
            HTTP_AUTHORIZATION="Bearer token_valido",
        )
        self.assertEqual(response.status_code, 400)

    # Pipeline de sucesso
    @patch("nivelamento.views.RAGService")
    @patch("users.decorators.jwt.decode", return_value=MOCK_JWT_PAYLOAD)
    @patch("users.decorators.jwks_client.get_signing_key_from_jwt")
    def test_sucesso_completo(self, mock_get_key: MagicMock, mock_decode: MagicMock, mock_service_cls: MagicMock) -> None:
        """Payload válido com pipeline mockada deve retornar 200."""
        mock_service = MagicMock()
        mock_service.generate.return_value = {
            "nivel": 4,
            "tema": "fauna",
            "questoes": [
                {
                    "id": "q1",
                    "enunciado": "Qual a tradução de jaguar?",
                    "alternativas": [
                        {"letra": "A", "texto": "Jaguara"},
                        {"letra": "B", "texto": "Tapira"},
                        {"letra": "C", "texto": "Arara"},
                        {"letra": "D", "texto": "Piranha"},
                    ],
                    "resposta_correta": "A",
                    "explicacao": "Jaguar significa Jaguara em Tupi.",
                }
            ],
        }
        mock_service_cls.return_value = mock_service

        response = self.client.post(
            ENDPOINT,
            data=json.dumps(VALID_PAYLOAD),
            content_type="application/json",
            HTTP_AUTHORIZATION="Bearer token_valido",
        )

        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertTrue(data["success"])
        self.assertIn("questoes", data)
        self.assertEqual(len(data["questoes"]), 1)
        self.assertEqual(len(data["questoes"][0]["alternativas"]), 4)

    # Erro interno
    @patch("nivelamento.views.RAGService")
    @patch("users.decorators.jwt.decode", return_value=MOCK_JWT_PAYLOAD)
    @patch("users.decorators.jwks_client.get_signing_key_from_jwt")
    def test_erro_runtime_retorna_500(self, mock_get_key: MagicMock, mock_decode: MagicMock, mock_service_cls: MagicMock) -> None:
        """RuntimeError na pipeline deve retornar 500 sem expor detalhes."""
        mock_service = MagicMock()
        mock_service.generate.side_effect = RuntimeError("ChromaDB offline")
        mock_service_cls.return_value = mock_service

        response = self.client.post(
            ENDPOINT,
            data=json.dumps(VALID_PAYLOAD),
            content_type="application/json",
            HTTP_AUTHORIZATION="Bearer token_valido",
        )

        self.assertEqual(response.status_code, 500)
        data = response.json()
        self.assertFalse(data["success"])
        self.assertEqual(data["error"]["code"], "QUESTION_GENERATION_FAILED")
        # Não deve conter detalhes técnicos na resposta
        self.assertNotIn("ChromaDB", data["error"]["message"])

    @patch("nivelamento.views.RAGService")
    @patch("users.decorators.jwt.decode", return_value=MOCK_JWT_PAYLOAD)
    @patch("users.decorators.jwks_client.get_signing_key_from_jwt")
    def test_erro_inesperado_retorna_500(self, mock_get_key: MagicMock, mock_decode: MagicMock, mock_service_cls: MagicMock) -> None:
        """Exceção inesperada deve retornar 500 genérico."""
        mock_service = MagicMock()
        mock_service.generate.side_effect = TypeError("erro bizarro")
        mock_service_cls.return_value = mock_service

        response = self.client.post(
            ENDPOINT,
            data=json.dumps(VALID_PAYLOAD),
            content_type="application/json",
            HTTP_AUTHORIZATION="Bearer token_valido",
        )

        self.assertEqual(response.status_code, 500)
        data = response.json()
        self.assertEqual(data["error"]["code"], "INTERNAL_ERROR")
