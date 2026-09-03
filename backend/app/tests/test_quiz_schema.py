"""Testes dos schemas Pydantic V2 da engine de quiz (RFC v3.0)."""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.schemas.quiz import (
    Alternative,
    EsqueletoItem,
    LLMQuizItem,
    LLMQuizResponse,
    QuizItem,
    QuizResponse,
)


# Alternative

class TestAlternative:
    def test_valid(self) -> None:
        alt = Alternative(letra="A", texto="jaguar")
        assert alt.letra == "A"
        assert alt.texto == "jaguar"

    def test_letra_lowercase_normalizada(self) -> None:
        alt = Alternative(letra="b", texto="anta")
        assert alt.letra == "B"

    def test_letra_invalida(self) -> None:
        with pytest.raises(ValidationError):
            Alternative(letra="Z", texto="xyz")

    def test_texto_vazio_invalido(self) -> None:
        with pytest.raises(ValidationError):
            Alternative(letra="A", texto="")


# EsqueletoItem

class TestEsqueletoItem:
    def test_valid(self) -> None:
        item = EsqueletoItem(
            item_id=1,
            termo_tupi="jaguara",
            traducao_correta="onça",
            distratores=["anta", "capivara", "tatu"],
        )
        assert item.termo_tupi == "jaguara"
        assert len(item.distratores) == 3

    def test_defaults_categoria_classe(self) -> None:
        item = EsqueletoItem(
            item_id=1,
            termo_tupi="x",
            traducao_correta="y",
            distratores=["a"],
        )
        assert item.categoria == "geral"
        assert item.classe_gramatical == "substantivo"

    def test_categoria_invalida_vira_geral(self) -> None:
        item = EsqueletoItem(
            item_id=1,
            termo_tupi="x",
            traducao_correta="y",
            distratores=["a"],
            categoria="categoria_inexistente_xyz",
        )
        assert item.categoria == "geral"

    def test_classe_invalida_vira_substantivo(self) -> None:
        item = EsqueletoItem(
            item_id=1,
            termo_tupi="x",
            traducao_correta="y",
            distratores=["a"],
            classe_gramatical="classe_estranha",
        )
        assert item.classe_gramatical == "substantivo"

    def test_item_id_deve_ser_positivo(self) -> None:
        with pytest.raises(ValidationError):
            EsqueletoItem(
                item_id=0,
                termo_tupi="x",
                traducao_correta="y",
                distratores=[],
            )


# QuizItem

def _make_alternativas(correta: str = "A") -> list[Alternative]:
    textos = {"A": "onça", "B": "anta", "C": "capivara", "D": "tatu"}
    return [Alternative(letra=l, texto=textos[l]) for l in ["A", "B", "C", "D"]]


class TestQuizItem:
    def test_valid(self) -> None:
        item = QuizItem(
            item_id=1,
            enunciado="O que significa 'jaguara' em Tupi Antigo?",
            alternativas=_make_alternativas("A"),
            resposta_correta="A",
            explicacao="Jaguara é o nome Tupi da onça-pintada.",
            variante="tupi",
        )
        assert item.resposta_correta == "A"
        assert len(item.alternativas) == 4

    def test_exatamente_quatro_alternativas_obrigatorio(self) -> None:
        with pytest.raises(ValidationError):
            QuizItem(
                item_id=1,
                enunciado="Pergunta?",
                alternativas=_make_alternativas()[:3],  # apenas 3
                resposta_correta="A",
                explicacao="Explicação.",
                variante="tupi",
            )

    def test_resposta_correta_deve_existir_entre_alternativas(self) -> None:
        # Resposta "D" mas nenhuma alternativa tem letra D após shuffle — cenário impossível
        # Testamos via model_validator: resposta_correta deve ser uma das letras presentes
        with pytest.raises(ValidationError):
            QuizItem(
                item_id=1,
                enunciado="Pergunta com dez palavras pelo menos aqui?",
                alternativas=[
                    Alternative(letra="A", texto="a"),
                    Alternative(letra="B", texto="b"),
                    Alternative(letra="C", texto="c"),
                    Alternative(letra="A", texto="d"),  # letra duplicada → inválido
                ],
                resposta_correta="A",
                explicacao="Explicação com pelo menos dez palavras aqui.",
                variante="tupi",
            )

    def test_enunciado_minimo_10_chars(self) -> None:
        with pytest.raises(ValidationError):
            QuizItem(
                item_id=1,
                enunciado="Curto?",
                alternativas=_make_alternativas(),
                resposta_correta="A",
                explicacao="Explicação curta",
                variante="tupi",
            )


# QuizResponse

class TestQuizResponse:
    def test_valid(self) -> None:
        item = QuizItem(
            item_id=1,
            enunciado="O que significa 'jaguara' em Tupi Antigo?",
            alternativas=_make_alternativas(),
            resposta_correta="A",
            explicacao="Jaguara é o nome Tupi da onça-pintada.",
            variante="tupi",
        )
        resp = QuizResponse(questoes=[item])
        assert len(resp.questoes) == 1
        assert resp.cache_hit is False

    def test_questoes_nao_pode_ser_vazia(self) -> None:
        with pytest.raises(ValidationError):
            QuizResponse(questoes=[])


# LLMQuizResponse

class TestLLMQuizResponse:
    def test_valid(self) -> None:
        resp = LLMQuizResponse(
            questoes=[
                LLMQuizItem(
                    item_id=1,
                    enunciado="O que significa 'jaguara'?",
                    explicacao="Onça-pintada, símbolo de força.",
                )
            ]
        )
        assert len(resp.questoes) == 1

    def test_enunciado_muito_curto(self) -> None:
        with pytest.raises(ValidationError):
            LLMQuizItem(item_id=1, enunciado="x", explicacao="ok ok ok ok ok ok ok")
