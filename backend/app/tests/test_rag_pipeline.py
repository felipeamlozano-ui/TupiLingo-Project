"""
Testes unitários e de integração para o pipeline RAG otimizado:
- SupabaseService.obter_chunks_rag (RPC e fallback REST)
- Distributed Lock no replenish_quiz_pool_task
- RAGService com ancoragem nos chunks de PDF
"""

import unittest
from unittest.mock import MagicMock, patch

from app.ai.rag_service import _build_prompt
from app.schemas.quiz import EsqueletoItem
from app.services.supabase_service import SupabaseService


class TestRAGPipeline(unittest.TestCase):

    def setUp(self):
        self.svc = SupabaseService.__new__(SupabaseService)
        self.svc._initialized = True
        self.svc._base_url = "https://fake.supabase.co"
        self.svc._headers = {}
        self.mock_client = MagicMock()
        self.svc._client = self.mock_client

    def test_obter_chunks_rag_rpc_success(self):
        """Testa retorno bem-sucedido via chamada RPC."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = [
            {"id": 1, "chunk_id": "c1", "document_text": "Texto histórico 1", "categoria": "História"},
            {"id": 2, "chunk_id": "c2", "document_text": "Texto gramatical 2", "categoria": "Gramática"},
        ]
        self.mock_client.post.return_value = mock_response

        chunks = self.svc.obter_chunks_rag(["História", "Gramática"], limite=2)
        self.assertEqual(len(chunks), 2)
        self.assertEqual(chunks[0]["categoria"], "História")
        self.mock_client.post.assert_called_once()
        # Verifica payload p_categorias
        call_args = self.mock_client.post.call_args
        self.assertEqual(call_args[1]["json"]["p_categorias"], ["História", "Gramática"])

    def test_obter_chunks_rag_fallback_rest(self):
        """Testa acionamento do fallback REST quando a RPC falha."""
        mock_rpc_fail = MagicMock()
        mock_rpc_fail.status_code = 500

        mock_rest_ok = MagicMock()
        mock_rest_ok.status_code = 200
        mock_rest_ok.json.return_value = [
            {"id": 10, "chunk_id": "c10", "document_text": "Fallback Vocab", "categoria": "Vocabulário"}
        ]

        self.mock_client.post.return_value = mock_rpc_fail
        self.mock_client.get.return_value = mock_rest_ok

        chunks = self.svc.obter_chunks_rag("Vocabulário", limite=1)
        self.assertEqual(len(chunks), 1)
        self.assertEqual(chunks[0]["categoria"], "Vocabulário")
        self.mock_client.get.assert_called_once()

    def test_build_prompt_with_rag_chunks(self):
        """Testa injeção de trechos do RAG no prompt com orçamento de tokens preservado."""
        esqueleto = [
            EsqueletoItem(item_id=1, termo_tupi="oka", traducao_correta="casa", distratores=["rio", "sol", "fogo"], categoria="geral")
        ]
        rag_chunks = [
            {"categoria": "Vocabulário", "document_text": "Oka significa a cabana tradicional de sapé dos índios Tupinambás."}
        ]
        prompt = _build_prompt(
            esqueleto=esqueleto,
            variante_nome="Tupinambá",
            tema="habitação",
            tier="iniciante",
            rag_chunks=rag_chunks,
        )

        self.assertIn("TRECHOS HISTÓRICOS / DICIONÁRIOS (FONTE RAG SUPABASE)", prompt)
        self.assertIn("Oka significa a cabana tradicional", prompt)
        self.assertIn('"termo": "oka"', prompt)

    def test_distributed_lock_in_replenish_task(self):
        """Testa se a task aborta silenciosamente quando o lock já está ativo."""
        from app.infra.workers import replenish_quiz_pool_task

        mock_redis = MagicMock()
        mock_redis.set.return_value = False  # Simula lock já existente (NX=True falhou)

        with patch("app.ai.ping_race.get_redis_client", return_value=mock_redis):
            result = replenish_quiz_pool_task.apply(args=["tupinamba", 1, 5]).get()
            self.assertEqual(result["status"], "skipped")
            self.assertEqual(result["reason"], "lock_active")


if __name__ == "__main__":
    unittest.main()
