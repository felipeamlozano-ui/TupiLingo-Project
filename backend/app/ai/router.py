from typing import List
from app.core.config import settings

class ModelRouter:
    """
    Roteador inteligente para selecionar dinamicamente a cadeia de fallback
    baseado em critérios de custo, latência e tamanho do contexto.
    """
    
    @classmethod
    def get_chain_for_task(cls, task_type: str = "balanced", context_length: int = 0) -> List[str]:
        """
        Retorna a melhor cadeia de fallback para a tarefa.
        
        Args:
            task_type (str): 'fast', 'cheap', 'reasoning', ou 'balanced'
            context_length (int): Quantidade estimada de tokens do contexto
        """
        
        # Se contexto for imenso, forçamos modelos grandes primeiro
        if context_length > 30000:
            return [
                "gemini/gemini-2.5-pro",
                "openai/gpt-4o",
                "cerebras/llama3.1-70b"
            ]

        # Roteamento baseado em prioridade
        if task_type == "fast":
            return [
                "gemini/gemini-2.5-flash",
                "cerebras/gpt-oss-120b",
                "openai/gpt-4o-mini"
            ]
        elif task_type == "cheap":
            return [
                "gemini/gemini-2.5-flash",
                "cerebras/gpt-oss-120b",
                "openai/gpt-4o-mini"
            ]
        elif task_type == "reasoning":
            return [
                "gemini/gemini-2.5-pro",
                "openai/gpt-4o",
                "gemini/gemini-2.5-flash"
            ]
            
        # Padrão
        return settings.FALLBACK_CHAIN
