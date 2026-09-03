import pytest
from unittest.mock import patch, MagicMock
from app.ai.registry import ProviderRegistry
from app.ai.providers.base import BaseProvider
from app.ai.fallback import FallbackOrchestrator
from app.ai.router import ModelRouter
from app.ai.schemas import QuestaoSchema
from app.ai.exceptions import ProviderNotFoundError, RateLimitError, StructuredOutputError

# Mock de um Provider Base para Testes
class MockProvider(BaseProvider):
    def generate_structured(self, prompt, schema, model_name, **kwargs):
        if "rate_limit" in model_name:
            raise RateLimitError("Rate limited")
        elif "invalid_json" in model_name:
            raise StructuredOutputError("Invalid JSON")
        
        # Simula resposta de sucesso mockada
        return schema(
            enunciado="Teste",
            resposta_correta="A",
            explicacao="Explicacao",
            dificuldade="A1",
            categoria="Geral",
            alternativas=[
                {"letra": "A", "texto": "1"},
                {"letra": "B", "texto": "2"},
                {"letra": "C", "texto": "3"},
                {"letra": "D", "texto": "4"}
            ]
        )

    def generate_text(self, prompt, model_name, **kwargs):
        return "Success"

@pytest.fixture(autouse=True)
def setup_registry():
    # Setup
    ProviderRegistry.clear()
    ProviderRegistry.register("mock", MockProvider())
    yield
    # Teardown
    ProviderRegistry.clear()

def test_registry_registration_and_retrieval():
    provider = ProviderRegistry.get_provider("mock")
    assert isinstance(provider, MockProvider)

def test_registry_raises_on_not_found():
    with pytest.raises(ProviderNotFoundError):
        ProviderRegistry.get_provider("inexistente")

def test_router_selects_fast_chain():
    chain = ModelRouter.get_chain_for_task(task_type="fast", context_length=100)
    assert any("groq" in item for item in chain)

def test_router_selects_heavy_chain_for_large_context():
    chain = ModelRouter.get_chain_for_task(context_length=50000)
    assert any("gemini-2.5-flash" in item for item in chain)

@patch("app.ai.fallback.wait_exponential_jitter", return_value=MagicMock())
def test_fallback_orchestrator_success(mock_jitter):
    chain = ["mock/success_model"]
    result = FallbackOrchestrator.execute_with_fallback(
        prompt="Gerar questão",
        schema=QuestaoSchema,
        chain=chain
    )
    assert result.enunciado == "Teste"

@patch("app.ai.fallback.wait_exponential_jitter", return_value=MagicMock())
def test_fallback_orchestrator_skips_failed_model(mock_jitter):
    # O primeiro modelo falha e o Fallback pula para o próximo válido da cadeia
    chain = ["mock/rate_limit", "mock/success_model"]
    
    result = FallbackOrchestrator.execute_with_fallback(
        prompt="Gerar questão",
        schema=QuestaoSchema,
        chain=chain
    )
    assert result.enunciado == "Teste"
