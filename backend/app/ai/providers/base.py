import abc
from typing import Any, Dict, Type
from pydantic import BaseModel

class BaseProvider(abc.ABC):
    """
    Interface base para todos os provedores de LLM.
    Utiliza o padrão Strategy.
    """
    
    @abc.abstractmethod
    def generate_structured(self, prompt: str, schema: Type[BaseModel], model_name: str, **kwargs) -> BaseModel:
        """
        Gera uma resposta estruturada de acordo com o schema Pydantic fornecido.
        
        Args:
            prompt (str): O prompt a ser enviado ao modelo.
            schema (Type[BaseModel]): A classe Pydantic que define a estrutura de saída.
            model_name (str): O nome do modelo a ser utilizado (ex: 'gemini-2.5-flash').
            **kwargs: Parâmetros adicionais (ex: temperature, max_tokens).
            
        Returns:
            BaseModel: Uma instância da classe schema preenchida.
        """
        pass

    @abc.abstractmethod
    def generate_text(self, prompt: str, model_name: str, **kwargs) -> str:
        """
        Gera texto puro.
        """
        pass
