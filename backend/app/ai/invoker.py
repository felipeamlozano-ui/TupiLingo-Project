import logging
from typing import Type
from pydantic import BaseModel

from app.ai.registry import registry
from app.ai.exceptions import ProviderNotFoundError, AIProviderError
from app.core.config import settings

logger = logging.getLogger(__name__)

class AIInvoker:
    """
    Camada de invocação. Isola a execução de um provider.
    Ponto central para injeção de segurança (Prompt Guard) e logging estruturado.
    """
    
    @classmethod
    def invoke_structured(
        cls, 
        provider_name: str, 
        model_name: str, 
        prompt: str, 
        schema: Type[BaseModel],
        **kwargs
    ) -> BaseModel:
        """
        Executa a geração estruturada em um provider específico.
        """
        provider_name = provider_name.lower()
        provider = registry.get_provider(provider_name)
        
        # 1. Segurança: Prompt Injection Guard (simplificado)
        if cls._contains_injection_attempt(prompt):
            raise AIProviderError("Prompt rejeitado por violação de segurança.")
        
        # 2. Execução
        logger.info(f"Invoking {provider_name} with model {model_name}")
        try:
            return provider.generate_structured(prompt, schema, model_name, **kwargs)
        except Exception as e:
            logger.error(f"Error in {provider_name} ({model_name}): {e}")
            raise e

    @classmethod
    def _contains_injection_attempt(cls, prompt: str) -> bool:
        """
        Simulação de verificação de segurança.
        Em produção real pode-se utilizar um modelo pequeno local ou regras heurísticas.
        """
        blacklist = ["ignore all previous instructions", "system prompt", "you are now"]
        prompt_lower = prompt.lower()
        for term in blacklist:
            if term in prompt_lower:
                return True
        return False
