import logging
from typing import Type, List, Optional
from pydantic import BaseModel
from tenacity import (
    retry,
    stop_after_attempt,
    wait_exponential_jitter,
    retry_if_exception_type
)

from app.core.config import settings
from app.ai.invoker import AIInvoker
from app.ai.exceptions import (
    AIProviderError, RateLimitError, TimeoutError, 
    NetworkError, ServiceUnavailableError, ProviderNotFoundError
)

logger = logging.getLogger(__name__)

# Exceções que podem engatilhar um retry imediato no MESMO provedor
RETRYABLE_EXCEPTIONS = (RateLimitError, TimeoutError, NetworkError, ServiceUnavailableError)

class FallbackOrchestrator:
    """
    Orquestrador que gerencia o fluxo de fallback entre modelos e provedores.
    Implementa retries locais antes de pular para o próximo modelo na cadeia.
    """
    
    @classmethod
    def execute_with_fallback(
        cls, 
        prompt: str, 
        schema: Type[BaseModel], 
        chain: Optional[List[str]] = None,
        **kwargs
    ) -> BaseModel:
        """
        Tenta gerar a resposta usando uma cadeia de modelos.
        Exemplo de item na cadeia: "groq/llama-3.1-8b-instant"
        """
        model_chain = chain or settings.FALLBACK_CHAIN
        
        last_exception = None

        for target in model_chain:
            try:
                provider_name, model_name = target.split("/", 1)
            except ValueError:
                logger.error(f"Formato de alvo inválido: {target}. Esperado 'provider/modelo'. Ignorando.")
                continue
            
            try:
                # Tenta executar com retries
                return cls._execute_single_target(provider_name, model_name, prompt, schema, **kwargs)
            
            except ProviderNotFoundError:
                logger.warning(f"Provedor {provider_name} não ativado ou inexistente. Pulando {target}.")
                continue
            
            except RETRYABLE_EXCEPTIONS as e:
                logger.warning(f"Alvo {target} falhou após retries ({type(e).__name__}). Tentando o próximo...")
                last_exception = e
                continue
                
            except AIProviderError as e:
                # Erros fatais do provedor
                logger.error(f"Erro no provedor {target}: {e}. Pulando para o próximo...")
                last_exception = e
                continue

            except Exception as e:
                # Qualquer outra exceção não mapeada (ex: 404 da OpenAI/Groq) NÃO deve derrubar a cadeia!
                logger.error(f"Erro inesperado em {target}: {e}. Pulando para o próximo...")
                last_exception = e
                continue
        
        # Se esgotou a lista inteira
        raise Exception(f"Todos os provedores da cadeia falharam. Último erro: {last_exception}")

    @classmethod
    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential_jitter(initial=1, max=10),
        retry=retry_if_exception_type(RETRYABLE_EXCEPTIONS),
        reraise=True
    )
    def _execute_single_target(
        cls, 
        provider_name: str, 
        model_name: str, 
        prompt: str, 
        schema: Type[BaseModel], 
        **kwargs
    ) -> BaseModel:
        """
        Executa um único provedor, com backoff exponencial e jitter caso encontre 
        erros transitórios (RateLimit, Timeout).
        """
        return AIInvoker.invoke_structured(provider_name, model_name, prompt, schema, **kwargs)
