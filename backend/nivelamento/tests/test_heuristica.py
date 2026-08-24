"""
Testes unitários para HeuristicaService.

Cobertura: calcular_nivel, _selecionar_tema, limites de nível, valores de borda.
"""

import pytest
from nivelamento.services.heuristica_service import calcular_nivel, NIVEL_MINIMO, NIVEL_MAXIMO


class TestCalcularNivel:
    def test_acerto_aumenta_nivel(self):
        nivel, _ = calcular_nivel(3, True)
        assert nivel == 4

    def test_erro_diminui_nivel(self):
        nivel, _ = calcular_nivel(3, False)
        assert nivel == 2

    def test_nivel_maximo_nao_ultrapassa_10(self):
        nivel, _ = calcular_nivel(10, True)
        assert nivel == NIVEL_MAXIMO

    def test_nivel_minimo_nao_vai_abaixo_1(self):
        nivel, _ = calcular_nivel(1, False)
        assert nivel == NIVEL_MINIMO

    def test_acertou_none_mantem_nivel(self):
        nivel, _ = calcular_nivel(5, None)
        assert nivel == 5

    def test_nivel_invalido_zero_levanta_value_error(self):
        with pytest.raises(ValueError):
            calcular_nivel(0, True)

    def test_nivel_invalido_11_levanta_value_error(self):
        with pytest.raises(ValueError):
            calcular_nivel(11, True)

    def test_nivel_invalido_negativo_levanta_value_error(self):
        with pytest.raises(ValueError):
            calcular_nivel(-1, True)

    def test_retorna_tema_string_nao_vazio(self):
        for nivel in range(NIVEL_MINIMO, NIVEL_MAXIMO + 1):
            _, tema = calcular_nivel(nivel, None)
            assert isinstance(tema, str)
            assert len(tema) > 0

    def test_todos_os_niveis_tem_tema(self):
        """Garante que nenhum nível retorna fallback vazio."""
        for nivel in range(1, 11):
            _, tema = calcular_nivel(nivel, None)
            assert tema != ""

    def test_nivel_1_nao_aceita_string(self):
        with pytest.raises((ValueError, TypeError)):
            calcular_nivel("1", True)  # type: ignore
