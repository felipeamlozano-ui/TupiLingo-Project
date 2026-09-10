"""
Testes unitários para Pydantic schemas do nivelamento.

Cobertura: GenerateQuestionPayload, QuestionData, validações cruzadas.
"""

import pytest
from pydantic import ValidationError
from nivelamento.schemas import GenerateQuestionPayload, QuestionData


class TestGenerateQuestionPayload:
    def test_nivel_valido_limites(self):
        for nivel in range(1, 11):
            payload = GenerateQuestionPayload(nivel_atual=nivel)
            assert payload.nivel_atual == nivel

    def test_nivel_zero_invalido(self):
        with pytest.raises(ValidationError):
            GenerateQuestionPayload(nivel_atual=0)

    def test_nivel_11_invalido(self):
        with pytest.raises(ValidationError):
            GenerateQuestionPayload(nivel_atual=11)

    def test_nivel_negativo_invalido(self):
        with pytest.raises(ValidationError):
            GenerateQuestionPayload(nivel_atual=-5)

    def test_acertou_anterior_none_padrao(self):
        payload = GenerateQuestionPayload(nivel_atual=5)
        assert payload.acertou_anterior is None

    def test_acertou_anterior_true(self):
        payload = GenerateQuestionPayload(nivel_atual=3, acertou_anterior=True)
        assert payload.acertou_anterior is True

    def test_acertou_anterior_false(self):
        payload = GenerateQuestionPayload(nivel_atual=3, acertou_anterior=False)
        assert payload.acertou_anterior is False


class TestQuestionData:
    def _make_valid(self, **overrides):
        defaults = {
            "enunciado": "Qual o significado de 'y' em Tupi?",
            "opcoes": ["Água", "Fogo", "Terra", "Ar"],
            "resposta_correta": "Água",
            "explicacao": "'Y' significa água em Tupi Antigo.",
        }
        defaults.update(overrides)
        return QuestionData(**defaults)

    def test_questao_valida(self):
        q = self._make_valid()
        assert q.enunciado
        assert len(q.opcoes) == 4
        assert q.resposta_correta in q.opcoes

    def test_resposta_deve_estar_nas_opcoes(self):
        with pytest.raises(ValidationError):
            self._make_valid(resposta_correta="Vento")

    def test_exatamente_4_opcoes(self):
        with pytest.raises(ValidationError):
            self._make_valid(opcoes=["Água", "Fogo", "Terra"])

    def test_opcao_vazia_invalida(self):
        with pytest.raises(ValidationError):
            self._make_valid(opcoes=["Água", "", "Terra", "Ar"])

    def test_enunciado_vazio_invalido(self):
        with pytest.raises(ValidationError):
            self._make_valid(enunciado="  ")

    def test_explicacao_vazia_invalida(self):
        with pytest.raises(ValidationError):
            self._make_valid(explicacao="")

    def test_opcoes_com_espacos_sao_limpos(self):
        q = self._make_valid(
            opcoes=["  Água  ", "Fogo", "Terra", "Ar"],
            resposta_correta="Água",
        )
        assert q.opcoes[0] == "Água"
