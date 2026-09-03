

from __future__ import annotations

from pydantic import BaseModel, field_validator, model_validator


class GenerateQuestionPayload(BaseModel):
    """Validação do payload recebido na API de nivelamento."""

    nivel_atual: int
    variante_id: int  # NOVO: obrigatório — isola o teste por língua
    acertou_anterior: bool | None = None

    @field_validator("nivel_atual", check_fields=False)
    @classmethod
    def validar_nivel(cls, v: int) -> int:
        """Garante que o nível está entre 1 e 10."""
        if not (1 <= v <= 10):
            raise ValueError(f"nivel_atual deve estar entre 1 e 10, recebido: {v}")
        return v

    @field_validator("variante_id", check_fields=False)
    @classmethod
    def validar_variante(cls, v: int) -> int:
        if v <= 0:
            raise ValueError("variante_id deve ser um inteiro positivo.")
        return v


class QuestionData(BaseModel):
    """
    Validação da questão gerada pelo Gemini.

    Regras:
    - Exatamente 4 alternativas.
    - Nenhuma alternativa vazia.
    - resposta_correta deve ser uma das alternativas.
    - Enunciado não pode ser vazio.
    """

    enunciado: str
    opcoes: list[str]
    resposta_correta: str
    explicacao: str

    @field_validator("enunciado", "explicacao", check_fields=False)
    @classmethod
    def campo_nao_vazio(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("O campo não pode ser vazio.")
        return v

    @field_validator("opcoes", check_fields=False)
    @classmethod
    def validar_opcoes(cls, v: list[str]) -> list[str]:
        if len(v) != 4:
            raise ValueError(f"Deve haver exatamente 4 alternativas, recebidas: {len(v)}")
        for i, opcao in enumerate(v):
            if not opcao or not opcao.strip():
                raise ValueError(f"A alternativa {i + 1} não pode ser vazia.")
        return [o.strip() for o in v]

    @model_validator(mode="after")
    def resposta_deve_estar_nas_opcoes(self) -> QuestionData:
        """Garante que resposta_correta é uma das opções."""
        if self.resposta_correta not in self.opcoes:
            raise ValueError(
                f"resposta_correta '{self.resposta_correta}' não está entre as opções: {self.opcoes}"
            )
        return self
