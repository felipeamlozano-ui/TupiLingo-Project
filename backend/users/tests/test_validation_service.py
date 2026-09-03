"""
Testes do validation_service.

Testa:
1. Distância Levenshtein via PostgreSQL (requer banco de dados de teste configurado).
2. Algoritmo de fallback (normalização sem extensão PostgreSQL).
3. Validação de respostas com diferentes tolerâncias.
4. Validação de lista de lacunas (múltiplas respostas).
5. Cálculo de XP.
"""

import unittest
from unittest.mock import patch, MagicMock

from users.services.validation_service import (
    _normalize_fallback,
    ValidationResult,
    validar_resposta_completar,
    validar_lista_lacunas,
    calcular_xp_exercicio,
)


class TestNormalizeFallback(unittest.TestCase):
    """Testa o fallback de normalização sem PostgreSQL."""

    def test_remove_accents(self):
        self.assertEqual(_normalize_fallback("Tupã"), _normalize_fallback("Tupa"))
        self.assertEqual(_normalize_fallback("Nheengatu"), _normalize_fallback("Nheengatu"))
        self.assertEqual(_normalize_fallback("Mboi"), _normalize_fallback("mboi"))

    def test_case_insensitive(self):
        self.assertEqual(_normalize_fallback("KARAI"), _normalize_fallback("karai"))

    def test_strip_whitespace(self):
        self.assertEqual(_normalize_fallback("  tupã  "), _normalize_fallback("tupa"))


class TestValidarRespostaCompletar(unittest.TestCase):
    """Testa a validação de respostas com mock do PostgreSQL."""

    def _mock_levenshtein(self, distancia: int):
        """Helper que faz mock da query do PostgreSQL retornando distância fixa."""
        mock_cursor = MagicMock()
        mock_cursor.__enter__ = MagicMock(return_value=mock_cursor)
        mock_cursor.__exit__ = MagicMock(return_value=False)
        mock_cursor.fetchone.return_value = (distancia,)
        mock_conn = MagicMock()
        mock_conn.cursor.return_value = mock_cursor
        return patch('users.services.validation_service.connection', mock_conn)

    def test_resposta_exata(self):
        with self._mock_levenshtein(0):
            result = validar_resposta_completar("tupã", "tupã", tolerancia=2)
        self.assertEqual(result.status, ValidationResult.CORRETO)

    def test_resposta_quase_certa_dentro_da_tolerancia(self):
        with self._mock_levenshtein(1):
            result = validar_resposta_completar("tupa", "tupã", tolerancia=2)
        self.assertEqual(result.status, ValidationResult.QUASE_CERTO)
        self.assertIn("tupã", result.mensagem)

    def test_resposta_muito_errada(self):
        with self._mock_levenshtein(5):
            result = validar_resposta_completar("banana", "tupã", tolerancia=2)
        self.assertEqual(result.status, ValidationResult.ERRADO)

    def test_resposta_vazia(self):
        result = validar_resposta_completar("", "tupã", tolerancia=2)
        self.assertEqual(result.status, ValidationResult.ERRADO)
        self.assertIn("vazia", result.mensagem.lower())

    def test_tolerancia_zero_exige_exata(self):
        with self._mock_levenshtein(1):
            result = validar_resposta_completar("tupa", "tupã", tolerancia=0)
        self.assertEqual(result.status, ValidationResult.ERRADO)


class TestValidarListaLacunas(unittest.TestCase):
    """Testa a validação de exercícios com múltiplas lacunas."""

    def _mock_levenshtein(self, distancias: list):
        """Mock retorna distâncias em sequência."""
        call_count = [0]
        def side_effect(sql, params):
            i = call_count[0]
            call_count[0] += 1
            return None
        
        cursors = []
        for d in distancias:
            mock_cursor = MagicMock()
            mock_cursor.__enter__ = MagicMock(return_value=mock_cursor)
            mock_cursor.__exit__ = MagicMock(return_value=False)
            mock_cursor.fetchone.return_value = (d,)
            cursors.append(mock_cursor)

        call_idx = [0]
        mock_conn = MagicMock()
        def get_cursor():
            idx = call_idx[0]
            call_idx[0] += 1
            return cursors[idx] if idx < len(cursors) else cursors[-1]
        mock_conn.cursor.side_effect = get_cursor
        return patch('users.services.validation_service.connection', mock_conn)

    def test_todas_corretas(self):
        with self._mock_levenshtein([0, 0]):
            resultado = validar_lista_lacunas(
                respostas_usuario=["tupã", "pajé"],
                respostas_corretas=["tupã", "pajé"],
                tolerancia=2,
            )
        self.assertTrue(resultado['tudo_correto'])
        self.assertEqual(resultado['acertos'], 2)
        self.assertEqual(resultado['total'], 2)

    def test_uma_quase_certa(self):
        with self._mock_levenshtein([0, 1]):
            resultado = validar_lista_lacunas(
                respostas_usuario=["tupã", "paje"],
                respostas_corretas=["tupã", "pajé"],
                tolerancia=2,
            )
        self.assertFalse(resultado['tudo_correto'])
        self.assertTrue(resultado['algum_quase'])
        self.assertEqual(resultado['acertos'], 1)


class TestCalcularXpExercicio(unittest.TestCase):
    """Testa o cálculo de XP após exercícios."""

    def test_correto_primeira_tentativa(self):
        xp = calcular_xp_exercicio(
            pontos_base=10,
            primeira_tentativa=True,
            resultado_status=ValidationResult.CORRETO,
        )
        self.assertEqual(xp, 20)  # 10 base + 10 bônus

    def test_correto_segunda_tentativa(self):
        xp = calcular_xp_exercicio(
            pontos_base=10,
            primeira_tentativa=False,
            resultado_status=ValidationResult.CORRETO,
        )
        self.assertEqual(xp, 10)  # Apenas base

    def test_quase_certo(self):
        xp = calcular_xp_exercicio(
            pontos_base=10,
            primeira_tentativa=True,
            resultado_status=ValidationResult.QUASE_CERTO,
        )
        self.assertEqual(xp, 7)  # 70% do base

    def test_errado(self):
        xp = calcular_xp_exercicio(
            pontos_base=10,
            primeira_tentativa=True,
            resultado_status=ValidationResult.ERRADO,
        )
        self.assertEqual(xp, 0)

    def test_bonus_exploracao_adicionado_mesmo_com_erro(self):
        xp = calcular_xp_exercicio(
            pontos_base=10,
            primeira_tentativa=False,
            resultado_status=ValidationResult.ERRADO,
            bonus_exploracao=5,
        )
        self.assertEqual(xp, 5)  # Apenas bônus de exploração

    def test_nao_negativo(self):
        xp = calcular_xp_exercicio(
            pontos_base=0,
            primeira_tentativa=False,
            resultado_status=ValidationResult.ERRADO,
        )
        self.assertGreaterEqual(xp, 0)


if __name__ == '__main__':
    unittest.main()
