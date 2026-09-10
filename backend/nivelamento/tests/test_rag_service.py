"""
Testes unitários para o RAGService.

Todos os serviços externos são mockados:
- ChromaDB
- DuckDuckGo
- Gemini
- Supabase
"""

from __future__ import annotations

import json
from unittest.mock import MagicMock, patch

from app.ai.rag_service import RAGService
from django.test import TestCase

from nivelamento.schemas import QuestionData

# Resposta válida padrão do Gemini
VALID_GEMINI_RESPONSE = json.dumps({
    "enunciado": "Qual é a tradução de 'jaguar' na língua Tupi?",
    "opcoes": ["Jaguara", "Tapira", "Arara", "Piranha"],
    "resposta_correta": "Jaguara",
    "explicacao": "Porque Jaguara é jaguar.",
})

VALID_AUDIT_RESPONSE = json.dumps({
    "is_valid": True
})

# Documentos ChromaDB mockados
MOCK_DOCUMENTS = [
    "Jaguara - onça, jaguar (felino grande)",
    "Tapira - anta (mamífero)",
    "Arara - arara (ave colorida)",
    "Piranha - piranha (peixe de rio)",
]


class RetrieveContextTest(TestCase):
    """Testes para RAGService.retrieve_context()."""

    @patch("nivelamento.services.rag_service._get_chroma_collection")
    def test_recuperacao_normal(self, mock_collection_fn: MagicMock) -> None:
        """Deve retornar documentos do ChromaDB quando disponíveis."""
        mock_collection = MagicMock()
        mock_collection.query.return_value = {
            "documents": [MOCK_DOCUMENTS],
            "ids": [["1", "2", "3", "4"]],
        }
        mock_collection_fn.return_value = mock_collection

        service = RAGService()
        docs = service.retrieve_context("fauna")

        self.assertEqual(len(docs), 4)
        self.assertIn("Jaguara", docs[0])
        mock_collection.query.assert_called_once()

    @patch("nivelamento.services.rag_service._get_chroma_collection")
    def test_contexto_vazio_levanta_erro(self, mock_collection_fn: MagicMock) -> None:
        """Deve levantar RuntimeError se nenhum documento for encontrado."""
        mock_collection = MagicMock()
        mock_collection.query.return_value = {"documents": [[]], "ids": [[]]}
        mock_collection_fn.return_value = mock_collection

        service = RAGService()
        with self.assertRaises(RuntimeError) as ctx:
            service.retrieve_context("tema_inexistente")

        self.assertIn("Nenhum documento", str(ctx.exception))

    @patch("nivelamento.services.rag_service._get_chroma_collection")
    def test_chromadb_falha_levanta_erro(self, mock_collection_fn: MagicMock) -> None:
        """Deve levantar RuntimeError se o ChromaDB falhar."""
        mock_collection = MagicMock()
        mock_collection.query.side_effect = Exception("ChromaDB offline")
        mock_collection_fn.return_value = mock_collection

        service = RAGService()
        with self.assertRaises(RuntimeError) as ctx:
            service.retrieve_context("fauna")

        self.assertIn("ChromaDB", str(ctx.exception))


class FetchCuriosityTest(TestCase):
    """Testes para RAGService.fetch_curiosity()."""

    @patch("duckduckgo_search.DDGS")
    def test_curiosidade_obtida_com_sucesso(self, mock_ddgs_cls: MagicMock) -> None:
        """Deve retornar a curiosidade quando DuckDuckGo responde."""
        mock_ddgs = MagicMock()
        mock_ddgs.__enter__ = MagicMock(return_value=mock_ddgs)
        mock_ddgs.__exit__ = MagicMock(return_value=False)
        mock_ddgs.text.return_value = [
            {"body": "A onça-pintada era reverenciada pelos povos Tupi."}
        ]
        mock_ddgs_cls.return_value = mock_ddgs

        service = RAGService()
        curiosity = service.fetch_curiosity("fauna")

        self.assertIsNotNone(curiosity)
        self.assertIn("onça-pintada", curiosity)

    @patch("duckduckgo_search.DDGS")
    def test_duckduckgo_falha_retorna_none(self, mock_ddgs_cls: MagicMock) -> None:
        """Deve retornar None se DuckDuckGo falhar (não impede geração)."""
        mock_ddgs_cls.side_effect = Exception("Timeout")

        service = RAGService()
        curiosity = service.fetch_curiosity("fauna")

        self.assertIsNone(curiosity)

    @patch("duckduckgo_search.DDGS")
    def test_duckduckgo_sem_resultado_retorna_none(self, mock_ddgs_cls: MagicMock) -> None:
        """Deve retornar None se DuckDuckGo não retornar resultados."""
        mock_ddgs = MagicMock()
        mock_ddgs.__enter__ = MagicMock(return_value=mock_ddgs)
        mock_ddgs.__exit__ = MagicMock(return_value=False)
        mock_ddgs.text.return_value = []
        mock_ddgs_cls.return_value = mock_ddgs

        service = RAGService()
        curiosity = service.fetch_curiosity("tema_obscuro")

        self.assertIsNone(curiosity)


class GenerateQuestionTest(TestCase):
    """Testes para RAGService.generate_question()."""

    @patch("nivelamento.services.rag_service.genai")
    def test_geracao_valida(self, mock_genai: MagicMock) -> None:
        """Deve retornar QuestionData quando Gemini responde corretamente."""
        mock_client = MagicMock()
        mock_response = MagicMock()
        mock_response.text = VALID_GEMINI_RESPONSE
        mock_client.models.generate_content.return_value = mock_response
        mock_genai.Client.return_value = mock_client

        service = RAGService()
        question = service.generate_question(
            nivel=3,
            tema="fauna",
            context=MOCK_DOCUMENTS,
            curiosity=None,
        )

        self.assertIsInstance(question, QuestionData)
        self.assertEqual(len(question.opcoes), 4)
        self.assertIn(question.resposta_correta, question.opcoes)

    @patch("nivelamento.services.rag_service.genai")
    def test_gemini_retorna_json_invalido(self, mock_genai: MagicMock) -> None:
        """Deve levantar RuntimeError se o Gemini retornar JSON inválido."""
        mock_client = MagicMock()
        mock_response = MagicMock()
        mock_response.text = "isto não é JSON"
        mock_client.models.generate_content.return_value = mock_response
        mock_genai.Client.return_value = mock_client

        service = RAGService()
        with self.assertRaises(RuntimeError) as ctx:
            service.generate_question(
                nivel=3,
                tema="fauna",
                context=MOCK_DOCUMENTS,
                curiosity=None,
            )

        self.assertIn("JSON inválido", str(ctx.exception))

    @patch("nivelamento.services.rag_service.genai")
    def test_gemini_retorna_3_alternativas(self, mock_genai: MagicMock) -> None:
        """Deve levantar RuntimeError se o Gemini retornar menos de 4 alternativas."""
        mock_client = MagicMock()
        mock_response = MagicMock()
        mock_response.text = json.dumps({
            "enunciado": "Pergunta?",
            "opcoes": ["A", "B", "C"],
            "resposta_correta": "A",
        })
        mock_client.models.generate_content.return_value = mock_response
        mock_genai.Client.return_value = mock_client

        service = RAGService()
        with self.assertRaises(RuntimeError) as ctx:
            service.generate_question(
                nivel=3,
                tema="fauna",
                context=MOCK_DOCUMENTS,
                curiosity=None,
            )

        self.assertIn("contrato", str(ctx.exception))

    @patch("nivelamento.services.rag_service.genai")
    def test_gemini_resposta_correta_fora_das_opcoes(self, mock_genai: MagicMock) -> None:
        """Deve levantar RuntimeError se resposta_correta não estiver nas opções."""
        mock_client = MagicMock()
        mock_response = MagicMock()
        mock_response.text = json.dumps({
            "enunciado": "Pergunta?",
            "opcoes": ["A", "B", "C", "D"],
            "resposta_correta": "E",
        })
        mock_client.models.generate_content.return_value = mock_response
        mock_genai.Client.return_value = mock_client

        service = RAGService()
        with self.assertRaises(RuntimeError) as ctx:
            service.generate_question(
                nivel=3,
                tema="fauna",
                context=MOCK_DOCUMENTS,
                curiosity=None,
            )

        self.assertIn("contrato", str(ctx.exception))

    @patch("nivelamento.services.rag_service.genai")
    def test_gemini_falha_levanta_erro(self, mock_genai: MagicMock) -> None:
        """Deve levantar RuntimeError se o Gemini estiver indisponível."""
        mock_client = MagicMock()
        mock_client.models.generate_content.side_effect = Exception("API Error")
        mock_genai.Client.return_value = mock_client

        service = RAGService()
        with self.assertRaises(RuntimeError) as ctx:
            service.generate_question(
                nivel=3,
                tema="fauna",
                context=MOCK_DOCUMENTS,
                curiosity=None,
            )

        self.assertIn("Gemini", str(ctx.exception))

    @patch("nivelamento.services.rag_service.genai")
    def test_gemini_resposta_vazia(self, mock_genai: MagicMock) -> None:
        """Deve levantar RuntimeError se o Gemini retornar resposta vazia."""
        mock_client = MagicMock()
        mock_response = MagicMock()
        mock_response.text = None
        mock_client.models.generate_content.return_value = mock_response
        mock_genai.Client.return_value = mock_client

        service = RAGService()
        with self.assertRaises(RuntimeError) as ctx:
            service.generate_question(
                nivel=3,
                tema="fauna",
                context=MOCK_DOCUMENTS,
                curiosity=None,
            )

        self.assertIn("vazia", str(ctx.exception))


class PersistQuestionTest(TestCase):
    """Testes para RAGService.persist_question()."""

    @patch("nivelamento.services.rag_service._get_supabase_client")
    def test_persistencia_sucesso(self, mock_supabase_fn: MagicMock) -> None:
        """Deve persistir no Supabase e retornar o registro."""
        mock_client = MagicMock()
        mock_client.table.return_value.insert.return_value.execute.return_value = MagicMock(
            data=[{"id": "test-id"}]
        )
        mock_supabase_fn.return_value = mock_client

        question = QuestionData(
            enunciado="Pergunta?",
            opcoes=["A", "B", "C", "D"],
            resposta_correta="A",
            explicacao="mock",
        )

        service = RAGService()
        result = service.persist_question(
            supabase_uid="12345678-1234-1234-1234-123456789abc",
            nivel=3,
            tema="fauna",
            question=question,
        )

        self.assertEqual(result["nivel"], 3)
        mock_client.table.assert_called_once_with("questoes_nivelamento")

    @patch("nivelamento.services.rag_service._get_supabase_client")
    def test_supabase_falha_levanta_erro(self, mock_supabase_fn: MagicMock) -> None:
        """Deve levantar RuntimeError se o Supabase falhar."""
        mock_client = MagicMock()
        mock_client.table.return_value.insert.return_value.execute.side_effect = Exception(
            "DB Error"
        )
        mock_supabase_fn.return_value = mock_client

        question = QuestionData(
            enunciado="Pergunta?",
            opcoes=["A", "B", "C", "D"],
            resposta_correta="A",
            explicacao="mock",
        )

        service = RAGService()
        with self.assertRaises(RuntimeError) as ctx:
            service.persist_question(
                supabase_uid="12345678-1234-1234-1234-123456789abc",
                nivel=3,
                tema="fauna",
                question=question,
            )

        self.assertIn("Supabase", str(ctx.exception))


class FullPipelineTest(TestCase):
    """Testes para RAGService.generate() — pipeline completa."""

    @patch("nivelamento.services.rag_service._get_supabase_client")
    @patch("nivelamento.services.rag_service.genai")
    @patch("duckduckgo_search.DDGS")
    @patch("nivelamento.services.rag_service._get_chroma_collection")
    def test_pipeline_completa_sucesso(
        self,
        mock_collection_fn: MagicMock,
        mock_ddgs_cls: MagicMock,
        mock_genai: MagicMock,
        mock_supabase_fn: MagicMock,
    ) -> None:
        """Pipeline completa deve funcionar com todos os mocks."""
        # ChromaDB
        mock_collection = MagicMock()
        mock_collection.query.return_value = {
            "documents": [MOCK_DOCUMENTS],
            "ids": [["1", "2", "3", "4"]],
        }
        mock_collection_fn.return_value = mock_collection

        # DuckDuckGo
        mock_ddgs = MagicMock()
        mock_ddgs.__enter__ = MagicMock(return_value=mock_ddgs)
        mock_ddgs.__exit__ = MagicMock(return_value=False)
        mock_ddgs.text.return_value = [
            {"body": "A onça-pintada era reverenciada pelos Tupi."}
        ]
        mock_ddgs_cls.return_value = mock_ddgs

        # Gemini
        mock_client = MagicMock()
        mock_resp_1 = MagicMock()
        mock_resp_1.text = VALID_GEMINI_RESPONSE
        mock_resp_2 = MagicMock()
        mock_resp_2.text = VALID_AUDIT_RESPONSE
        mock_client.models.generate_content.side_effect = [mock_resp_1, mock_resp_2]
        mock_genai.Client.return_value = mock_client

        # Supabase
        mock_sb_client = MagicMock()
        mock_sb_client.table.return_value.insert.return_value.execute.return_value = MagicMock(
            data=[{"id": "new-id"}]
        )
        mock_supabase_fn.return_value = mock_sb_client

        service = RAGService()
        result = service.generate(
            supabase_uid="12345678-1234-1234-1234-123456789abc",
            nivel_atual=3,
            acertou_anterior=True,
        )

        self.assertIn("questao", result)
        self.assertEqual(result["nivel"], 4)  # 3 + acerto = 4
        self.assertEqual(len(result["questao"]["opcoes"]), 4)

    @patch("nivelamento.services.rag_service._get_chroma_collection")
    def test_pipeline_chromadb_falha(self, mock_collection_fn: MagicMock) -> None:
        """Pipeline deve falhar se ChromaDB falhar (sem gerar questão inventada)."""
        mock_collection = MagicMock()
        mock_collection.query.side_effect = Exception("ChromaDB offline")
        mock_collection_fn.return_value = mock_collection

        service = RAGService()
        with self.assertRaises(RuntimeError):
            service.generate(
                supabase_uid="12345678-1234-1234-1234-123456789abc",
                nivel_atual=3,
                acertou_anterior=True,
            )

    @patch("nivelamento.services.rag_service._get_supabase_client")
    @patch("nivelamento.services.rag_service.genai")
    @patch("duckduckgo_search.DDGS")
    @patch("nivelamento.services.rag_service._get_chroma_collection")
    def test_pipeline_sem_duckduckgo(
        self,
        mock_collection_fn: MagicMock,
        mock_ddgs_cls: MagicMock,
        mock_genai: MagicMock,
        mock_supabase_fn: MagicMock,
    ) -> None:
        """Pipeline deve funcionar mesmo se DuckDuckGo falhar."""
        # ChromaDB
        mock_collection = MagicMock()
        mock_collection.query.return_value = {
            "documents": [MOCK_DOCUMENTS],
            "ids": [["1", "2", "3", "4"]],
        }
        mock_collection_fn.return_value = mock_collection

        # DuckDuckGo — falha
        mock_ddgs_cls.side_effect = Exception("DDG timeout")

        # Gemini
        mock_client = MagicMock()
        mock_resp_1 = MagicMock()
        mock_resp_1.text = VALID_GEMINI_RESPONSE
        mock_resp_2 = MagicMock()
        mock_resp_2.text = VALID_AUDIT_RESPONSE
        mock_client.models.generate_content.side_effect = [mock_resp_1, mock_resp_2]
        mock_genai.Client.return_value = mock_client

        # Supabase
        mock_sb_client = MagicMock()
        mock_sb_client.table.return_value.insert.return_value.execute.return_value = MagicMock(
            data=[{"id": "new-id"}]
        )
        mock_supabase_fn.return_value = mock_sb_client

        service = RAGService()
        result = service.generate(
            supabase_uid="12345678-1234-1234-1234-123456789abc",
            nivel_atual=5,
            acertou_anterior=False,
        )

        # Deve funcionar sem DuckDuckGo
        self.assertIn("questao", result)
        self.assertEqual(result["nivel"], 4)  # 5 - erro = 4
