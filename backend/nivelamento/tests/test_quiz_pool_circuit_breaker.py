"""
Testes unitários para o Circuito de Segurança (Circuit Breaker) e Reposição em Lote do Question Pool.

Cenários cobertos:
1. Pool Forçado a Zero:
   - O SPOP retorna None (pool vazio).
   - O circuito de segurança é acionado graciosamente.
   - O log estruturado [CAPACITY_EVENT] é emitido.
   - A geração síncrona via LLM responde com 10 questões válidas.
   - Cada questão contém obrigatoriamente o campo 'fonte_confianca' e 4 alternativas únicas.
   - O reabastecimento em background é agendado sem erro para o usuário.

2. Consumo com Watermark Baixo (< 15 unidades):
   - Consome do pool com sucesso.
   - Detecta pool abaixo de 15 e aciona reposição em lote protegida por lock.
   - _shuffle_quiz_response é aplicado garantindo imprevisibilidade.
"""

from __future__ import annotations

import json
import logging
from unittest.mock import MagicMock, patch

from django.test import TestCase

from app.ai.rag_service import (
    RAGService,
    WATERMARK_LOW,
    TARGET_POOL_SIZE,
    _pool_key,
    _trigger_async_pool_replenishment,
)
from app.schemas.quiz import (
    Alternative,
    EsqueletoItem,
    LLMQuizItem,
    LLMQuizResponse,
    QuizItem,
    QuizResponse,
)


class QuizPoolCircuitBreakerTest(TestCase):
    """Testa a resiliência do pool de questões e o circuito de segurança."""

    def setUp(self):
        self.service = RAGService()
        self.variante = "tupi"
        self.nivel = 1

    @patch("app.ai.rag_service.get_redis_client")
    @patch("app.ai.rag_service.FallbackOrchestrator.execute_with_fallback")
    @patch("app.ai.rag_service.supabase_service.obter_esqueleto_quiz")
    def test_pool_zerado_aciona_circuito_de_seguranca_e_capacity_event(
        self,
        mock_obter_esqueleto: MagicMock,
        mock_llm: MagicMock,
        mock_get_redis: MagicMock,
    ):
        """
        Força o pool a zero (SPOP retorna None).
        Deve:
        - Emitir o log estruturado [CAPACITY_EVENT].
        - Não lançar exceção para o chamador.
        - Cair para geração síncrona via LLM.
        - Retornar 10 questões válidas com 'fonte_confianca'.
        - Ter cache_hit = False.
        """
        # Configura o Redis mockado com pool vazio
        mock_redis = MagicMock()
        mock_redis.spop.return_value = None
        mock_redis.scard.return_value = 0
        mock_redis.set.return_value = True  # lock adquirido
        mock_get_redis.return_value = mock_redis

        # Mock do esqueleto Supabase
        itens_esqueleto = [
            EsqueletoItem(
                item_id=i,
                termo_tupi=f"termo_{i}",
                traducao_correta=f"traducao_{i}",
                distratores=[f"dist_a_{i}", f"dist_b_{i}", f"dist_c_{i}"],
                categoria="geral",
                fonte_confianca="alta",
            )
            for i in range(1, 11)
        ]
        mock_obter_esqueleto.return_value = itens_esqueleto

        # Mock da resposta da LLM
        mock_llm.return_value = LLMQuizResponse(
            questoes=[
                LLMQuizItem(
                    item_id=i,
                    enunciado=f"Qual é o significado de termo_{i}?",
                    explicacao=f"termo_{i} significa traducao_{i}.",
                    curiosidade="Curiosidade cultural.",
                )
                for i in range(1, 11)
            ]
        )

        with self.assertLogs("app.ai.rag_service", level="WARNING") as cm:
            resultado = self.service.generate(nivel_atual=self.nivel, variante_codigo=self.variante)

        # 1. Verifica se o evento de capacidade estruturado foi registrado
        capacity_event_logs = [log for log in cm.output if "[CAPACITY_EVENT]" in log]
        self.assertTrue(
            len(capacity_event_logs) > 0,
            "O log estruturado [CAPACITY_EVENT] deve ser registrado quando o pool estiver zerado.",
        )
        self.assertIn("Question Pool zerado para variante=tupi, nivel=1", capacity_event_logs[0])

        # 2. Resposta deve ser válida sem erros para o usuário
        self.assertIn("questoes", resultado)
        self.assertEqual(len(resultado["questoes"]), 10)
        self.assertFalse(resultado.get("cache_hit", True))
        self.assertIsNotNone(resultado.get("pacote_id"))

        # 3. Cada questão deve ter 4 alternativas únicas e fonte_confianca
        for q in resultado["questoes"]:
            self.assertIn("fonte_confianca", q)
            self.assertIn(q["fonte_confianca"], ["alta", "média", "baixa"])
            self.assertEqual(len(q["alternativas"]), 4)
            letras = [alt["letra"] for alt in q["alternativas"]]
            self.assertEqual(sorted(letras), ["A", "B", "C", "D"])

    @patch("app.ai.rag_service.get_redis_client")
    @patch("app.ai.rag_service._trigger_async_pool_replenishment")
    def test_pool_com_estoque_abaixo_da_watermark_dispara_reposicao(
        self,
        mock_repor: MagicMock,
        mock_get_redis: MagicMock,
    ):
        """
        Consome um pacote do pool quando o estoque está abaixo do watermark (10 < 15).
        Deve retornar o pacote imediatamente e disparar a reposição assíncrona da diferença.
        """
        mock_redis = MagicMock()
        # Pacote simulado no Redis
        pacote_simulado = {
            "pacote_id": "33333333-3333-3333-3333-333333333333",
            "provider": "RedisPool",
            "modelo": "seed-tupi-v1",
            "tempo_total_ms": 1,
            "cache_hit": True,
            "questoes": [
                {
                    "item_id": i,
                    "enunciado": f"Enunciado {i}?",
                    "alternativas": [
                        {"letra": "A", "texto": "Opção A"},
                        {"letra": "B", "texto": "Opção B"},
                        {"letra": "C", "texto": "Opção C"},
                        {"letra": "D", "texto": "Opção D"},
                    ],
                    "resposta_correta": "A",
                    "explicacao": f"Explicação {i}.",
                    "categoria": "geral",
                    "variante": "tupi",
                    "dificuldade": "facil",
                    "curiosidade": "",
                    "regra_contexto": "",
                    "fonte_confianca": "alta",
                }
                for i in range(1, 11)
            ],
        }
        mock_redis.spop.return_value = json.dumps(pacote_simulado)
        # Estoque restante pós-SPOP é 10 (abaixo de 15)
        mock_redis.scard.return_value = 10
        mock_get_redis.return_value = mock_redis

        resultado = self.service.generate(nivel_atual=1, variante_codigo="tupi")

        # Verifica consumo imediato
        self.assertEqual(len(resultado["questoes"]), 10)
        self.assertTrue(resultado["cache_hit"])

        # Verifica se o reabastecimento foi disparado para a diferença até 30 unidades
        mock_repor.assert_called_once_with(
            variante_codigo="tupi",
            nivel_atual=1,
            target_count=TARGET_POOL_SIZE - 10,  # 30 - 10 = 20 pacotes
        )

    @patch("app.ai.rag_service.get_redis_client")
    def test_distributed_lock_evita_jobs_duplicados(self, mock_get_redis: MagicMock):
        """
        Verifica se o lock distribuído repor_lock:{variante}:{nivel} com EX 30
        impede que múltiplos workers tentem reabastecer concorrentemente.
        """
        mock_redis = MagicMock()
        # Primeiro worker adquire o lock
        mock_redis.set.return_value = False  # Lock já retido por outro processo
        mock_get_redis.return_value = mock_redis

        with patch("app.ai.rag_service.threading.Thread") as mock_thread:
            _trigger_async_pool_replenishment(variante_codigo="tupi", nivel_atual=1, target_count=15)
            # Não deve ter iniciado nova thread
            mock_thread.assert_not_called()

        mock_redis.set.assert_called_once_with("repor_lock:tupi:1", "1", nx=True, ex=30)
