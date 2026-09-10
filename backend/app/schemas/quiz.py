"""
TupiLingo — Quiz Schemas (RFC v3.0)

Modelos Pydantic V2 para validação de entrada e saída da Engine Heurística.
Todos os contratos JSON consumidos pelo Flutter são preservados integralmente.
"""

from __future__ import annotations

from typing import Annotated, Literal

from pydantic import BaseModel, Field, field_validator, model_validator

# Constantes de domínio

CATEGORIAS_VALIDAS: frozenset[str] = frozenset(
    {"fauna", "flora", "natureza", "mitologia", "corpo", "gramatica", "historia", "geral"}
)

# Códigos reais de VarianteTupi.codigo no banco de dados.
# Atualizar aqui quando novas variantes forem cadastradas.
VARIANTES_VALIDAS: frozenset[str] = frozenset(
    {"tupi", "tupi_contemporaneo", "tupinamba"}
)

CLASSES_GRAMATICAIS_VALIDAS: frozenset[str] = frozenset(
    {"substantivo", "verbo", "adjetivo", "adverbio", "pronome", "numeral", "interjeicao"}
)


# Modelos de Extração (ETL com LLM)

class ExtractedTerm(BaseModel):
    """
    Termo de vocabulário extraído pela IA a partir de texto bruto (PDF/RAG).
    """
    palavra_tupi: Annotated[str, Field(..., description="A palavra ou termo na língua indígena (ex: jagûara).")]
    traducao_pt: Annotated[str, Field(..., description="A tradução ou significado em português (ex: onça).")]
    classe_gramatical: Annotated[
        str,
        Field(..., description=f"Uma das classes: {', '.join(CLASSES_GRAMATICAIS_VALIDAS)}")
    ]
    categoria: Annotated[
        str, 
        Field(..., description=f"Tema principal. Opções: {', '.join(CATEGORIAS_VALIDAS)}")
    ]
    variante: Annotated[
        str, 
        Field(..., description=f"A qual língua este termo pertence. Opções: {', '.join(VARIANTES_VALIDAS)}")
    ]
    transliteracao: Annotated[str, Field(default="", description="Guia de pronúncia se houver no texto original.")]
    exemplo_tupi: Annotated[str, Field(default="", description="Frase de exemplo em tupi, caso o texto contenha.")]
    trecho_fonte: Annotated[str, Field(..., description="Trecho EXATO (citação literal) do texto original onde a palavra aparece.")]

    @field_validator("classe_gramatical", mode="before")
    @classmethod
    def normalizar_classe(cls, v: str) -> str:
        val = str(v).lower().strip()
        if val not in CLASSES_GRAMATICAIS_VALIDAS:
            return "substantivo" # fallback
        return val

    @field_validator("categoria", mode="before")
    @classmethod
    def normalizar_categoria(cls, v: str) -> str:
        val = str(v).lower().strip()
        if val not in CATEGORIAS_VALIDAS:
            return "geral" # fallback
        return val

    @field_validator("variante", mode="before")
    @classmethod
    def normalizar_variante(cls, v: str) -> str:
        val = str(v).lower().strip()
        if val not in VARIANTES_VALIDAS:
            return "tupi" # fallback
        return val


class ExtractedVocabularyList(BaseModel):
    """
    Lista de termos extraídos de um único chunk de texto.
    """
    termos: list[ExtractedTerm]


# Modelos de entrada (RPC / Supabase)


class EsqueletoItem(BaseModel):
    """
    Item retornado pela RPC ``gerar_esqueleto_quiz``.
    Representa o dado lexical determinístico — zero alucinação.
    """

    item_id: int = Field(..., ge=1, description="Identificador sequencial do item.")
    termo_tupi: str = Field(..., min_length=1, description="Palavra em Tupi Antigo ou variante.")
    traducao_correta: str = Field(..., min_length=1, description="Tradução canônica em português.")
    distratores: list[str] = Field(
        ...,
        min_length=1,
        description="Alternativas incorretas semanticamente plausíveis.",
    )
    classe_gramatical: str = Field(default="substantivo")
    categoria: str = Field(default="geral")
    regra_contexto: str = Field(default="", description="Exemplo de uso ou transliteração.")
    fonte: str = Field(default="Base Lexical Oficial TupiLingo")
    fonte_confianca: Literal["alta", "média", "baixa"] = Field(
        default="alta",
        description="Grau de certeza linguística sobre a tradução/vocabulário."
    )

    @field_validator("classe_gramatical")
    @classmethod
    def validate_classe(cls, v: str) -> str:
        normalized = v.lower().strip()
        if normalized not in CLASSES_GRAMATICAIS_VALIDAS:
            return "substantivo"  # degradação graciosa
        return normalized

    @field_validator("categoria")
    @classmethod
    def validate_categoria(cls, v: str) -> str:
        normalized = v.lower().strip()
        if normalized not in CATEGORIAS_VALIDAS:
            return "geral"  # degradação graciosa
        return normalized


# Modelos de saída (Flutter API contract)


class Alternative(BaseModel):
    """
    Alternativa individual de uma questão de múltipla escolha.
    Contrato mantido compatível com o Flutter existente.
    """

    letra: str = Field(..., description="Letra da alternativa: A, B, C ou D.")
    texto: str = Field(..., min_length=1, description="Texto da alternativa.")

    @field_validator("letra")
    @classmethod
    def validate_letra(cls, v: str) -> str:
        upper = v.upper().strip()
        if upper not in {"A", "B", "C", "D"}:
            raise ValueError(f"Letra inválida: '{v}'. Deve ser A, B, C ou D.")
        return upper


class QuizItem(BaseModel):
    """
    Uma questão completa de múltipla escolha no formato consumido pelo Flutter.
    Contrato de saída preservado integralmente.
    """

    item_id: int = Field(..., ge=1)
    enunciado: str = Field(..., min_length=10, description="Pergunta em português natural.")
    alternativas: Annotated[list[Alternative], Field(min_length=4, max_length=4)]
    resposta_correta: Literal["A", "B", "C", "D"] = Field(
        ..., description="Letra da alternativa correta."
    )
    explicacao: str = Field(..., min_length=10, description="Explicação pedagógica pós-resposta.")
    categoria: str = Field(default="geral")
    variante: str = Field(..., description="Código da variante Tupi.")
    dificuldade: Literal["facil", "media", "dificil"] = Field(default="facil")
    curiosidade: str = Field(default="", description="Fato cultural opcional.")
    regra_contexto: str = Field(default="")
    fonte_confianca: Literal["alta", "média", "baixa"] = Field(
        default="alta",
        description="Grau de certeza linguística sobre a tradução/vocabulário (alta / média / baixa)."
    )

    @model_validator(mode="after")
    def validate_exatamente_uma_correta(self) -> QuizItem:
        corretas = [a for a in self.alternativas if a.letra == self.resposta_correta]
        if len(corretas) != 1:
            raise ValueError(
                f"Exatamente 1 alternativa deve ser correta. "
                f"Encontradas: {len(corretas)} para resposta_correta='{self.resposta_correta}'."
            )
        letras = [a.letra for a in self.alternativas]
        if len(set(letras)) != 4:
            raise ValueError(f"As 4 alternativas devem ter letras únicas. Encontrado: {letras}.")
        return self

    @field_validator("variante")
    @classmethod
    def validate_variante(cls, v: str) -> str:
        if v not in VARIANTES_VALIDAS:
            # Aceita variantes desconhecidas com aviso (compatibilidade futura)
            return v
        return v


class QuizResponse(BaseModel):
    """
    Resposta completa da engine de quiz.
    Envelope externo retornado pelo endpoint /gerar-questao/.
    Compatível com o contrato Flutter existente.
    """

    pacote_id: str | None = Field(default=None, description="UUID do pacote no Question Pool.")
    questoes: Annotated[list[QuizItem], Field(min_length=1, max_length=50)]
    provider: str = Field(default="", description="Provedor de IA utilizado.")
    modelo: str = Field(default="", description="Modelo de IA utilizado.")
    tempo_total_ms: int = Field(default=0, ge=0, description="Latência total em milissegundos.")
    cache_hit: bool = Field(default=False, description="True se a resposta veio do cache Redis.")


# Schema intermediário (saída esperada da LLM)


class LLMQuizItem(BaseModel):
    """
    Schema de saída esperado da LLM após redação pedagógica.
    A LLM apenas escreve enunciado, explicacao e curiosidade.
    Todos os dados lexicais são injetados pelo PromptBuilder.
    """

    item_id: int = Field(default=1, description="ID numérico correspondente do item")
    enunciado: str = Field(default="", description="Pergunta em português natural")
    explicacao: str = Field(default="", description="Explicação pedagógica pós-resposta")
    curiosidade: str = Field(default="", description="Fato cultural ou etimológico opcional")


class LLMQuizResponse(BaseModel):
    """Envelope de saída da LLM contendo a lista de itens redigidos."""

    questoes: list[LLMQuizItem] = Field(default_factory=list, description="Lista de itens redigidos")
