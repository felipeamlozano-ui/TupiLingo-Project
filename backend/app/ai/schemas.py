from pydantic import BaseModel, Field
from typing import List, Optional

class Alternativa(BaseModel):
    letra: str = Field(description="Letra da alternativa, ex: A, B, C, D")
    texto: str = Field(description="Texto da alternativa em Tupi ou Português")

class QuestaoSchema(BaseModel):
    enunciado: str = Field(description="Enunciado da questão")
    contexto: Optional[str] = Field(None, description="Contexto extra ou trecho base")
    alternativas: List[Alternativa] = Field(description="Lista de alternativas da questão")
    resposta_correta: str = Field(description="Letra correspondente à resposta correta")
    explicacao: str = Field(description="Explicação da resposta")
    dificuldade: str = Field(description="Dificuldade da questão")
    categoria: str = Field(description="Categoria gramatical ou semântica (ex: Verbos, Vocabulário)")
    idioma: str = Field(default="tupi", description="Idioma alvo da questão")
