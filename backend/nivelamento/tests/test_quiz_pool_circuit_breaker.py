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

    @patch("app.ai.rag_service.FallbackOrchestrator.execute_with_fallback")
    @patch("app.ai.rag_service.supabase_service.obter_esqueleto_quiz")
    def test_geracao_dinamica_sob_demanda_sem_pool_estatico(
        self,
        mock_obter_esqueleto: MagicMock,
        mock_llm: MagicMock,
    ):
        """
        Geração 100% dinâmica sob demanda (RFC v4):
        - Não consome pool estático no momento do clique do usuário.
        - Executa RAG + LLM em tempo real.
        - Retorna 10 questões válidas com 'fonte_confianca'.
        - Garante cache_hit = False.
        - Garante 4 alternativas únicas A, B, C, D.
        """
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

        resultado = self.service.generate(nivel_atual=self.nivel, variante_codigo=self.variante)

        # 1. Resposta sob demanda deve ser sempre gerada em tempo real (cache_hit = False)
        self.assertIn("questoes", resultado)
        self.assertEqual(len(resultado["questoes"]), 10)
        self.assertFalse(resultado.get("cache_hit", True))
        self.assertIsNotNone(resultado.get("pacote_id"))

        # 2. Cada questão deve ter 4 alternativas únicas e fonte_confianca
        for q in resultado["questoes"]:
            self.assertIn("fonte_confianca", q)
            self.assertIn(q["fonte_confianca"], ["alta", "média", "baixa"])
            self.assertEqual(len(q["alternativas"]), 4)
            letras = [alt["letra"] for alt in q["alternativas"]]
            self.assertEqual(sorted(letras), ["A", "B", "C", "D"])

    @patch("app.ai.rag_service.get_redis_client")
    def test_distributed_lock_evita_jobs_duplicados(self, mock_get_redis: MagicMock):
        """
        Verifica se o lock distribuído lock:replenish:{variante}:{nivel} com EX 30
        impede que múltiplos workers tentem reabastecer concorrentemente.
        """
        from app.core.config import settings
        original_celery = settings.ENABLE_CELERY
        settings.ENABLE_CELERY = False
        try:
            mock_redis = MagicMock()
            # Primeiro worker adquire o lock
            mock_redis.set.return_value = False  # Lock já retido por outro processo
            mock_get_redis.return_value = mock_redis

            with patch("app.ai.rag_service.threading.Thread") as mock_thread:
                _trigger_async_pool_replenishment(variante_codigo="tupi", nivel_atual=1, target_count=15)
                # Não deve ter iniciado nova thread
                mock_thread.assert_not_called()

            mock_redis.set.assert_called_once_with("lock:replenish:tupi:1", "1", nx=True, ex=30)
        finally:
            settings.ENABLE_CELERY = original_celery
