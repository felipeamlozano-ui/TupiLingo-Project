"""
Testes unitários para o serviço de heurística de nivelamento.

Cobertura:
- Limites inferiores e superiores do nível
- Acerto e erro em cada extremo
- Seleção de tema por faixa
- Validação de entrada inválida
"""

from django.test import TestCase

from nivelamento.services.heuristica_service import (
    NIVEL_MAXIMO,
    NIVEL_MINIMO,
    TEMAS_POR_FAIXA,
    calcular_nivel,
)


class HeuristicaServiceTest(TestCase):
    """Testes para calcular_nivel()."""

    # ------------------------------------------------------------------
    # Limites inferiores
    # ------------------------------------------------------------------
    def test_nivel_1_erro_permanece_1(self) -> None:
        """Nível 1 + erro → permanece 1 (não pode diminuir abaixo do mínimo)."""
        novo_nivel, tema = calcular_nivel(nivel_atual=1, acertou_anterior=False)
        self.assertEqual(novo_nivel, NIVEL_MINIMO)

    def test_nivel_1_acerto_sobe_para_2(self) -> None:
        """Nível 1 + acerto → nível 2."""
        novo_nivel, tema = calcular_nivel(nivel_atual=1, acertou_anterior=True)
        self.assertEqual(novo_nivel, 2)

    # ------------------------------------------------------------------
    # Limites superiores
    # ------------------------------------------------------------------
    def test_nivel_10_acerto_permanece_10(self) -> None:
        """Nível 10 + acerto → permanece 10 (não pode ultrapassar máximo)."""
        novo_nivel, tema = calcular_nivel(nivel_atual=10, acertou_anterior=True)
        self.assertEqual(novo_nivel, NIVEL_MAXIMO)

    def test_nivel_10_erro_desce_para_9(self) -> None:
        """Nível 10 + erro → nível 9."""
        novo_nivel, tema = calcular_nivel(nivel_atual=10, acertou_anterior=False)
        self.assertEqual(novo_nivel, 9)

    # ------------------------------------------------------------------
    # Comportamento intermediário
    # ------------------------------------------------------------------
    def test_nivel_5_acerto_sobe_para_6(self) -> None:
        """Nível 5 + acerto → nível 6."""
        novo_nivel, _ = calcular_nivel(nivel_atual=5, acertou_anterior=True)
        self.assertEqual(novo_nivel, 6)

    def test_nivel_5_erro_desce_para_4(self) -> None:
        """Nível 5 + erro → nível 4."""
        novo_nivel, _ = calcular_nivel(nivel_atual=5, acertou_anterior=False)
        self.assertEqual(novo_nivel, 4)

    # ------------------------------------------------------------------
    # Seleção de tema por faixa
    # ------------------------------------------------------------------
    def test_tema_nivel_1_pertence_faixa_1_2(self) -> None:
        """Tema do nível 1 (após erro do nível 1) deve pertencer à faixa 1-2."""
        _, tema = calcular_nivel(nivel_atual=1, acertou_anterior=False)
        temas_validos = TEMAS_POR_FAIXA[(1, 2)]
        self.assertIn(tema, temas_validos)

    def test_tema_nivel_2_acerto_pertence_faixa_3_4(self) -> None:
        """Nível 2 + acerto → nível 3, tema deve pertencer à faixa 3-4."""
        novo_nivel, tema = calcular_nivel(nivel_atual=2, acertou_anterior=True)
        self.assertEqual(novo_nivel, 3)
        temas_validos = TEMAS_POR_FAIXA[(3, 4)]
        self.assertIn(tema, temas_validos)

    def test_tema_nivel_6_acerto_pertence_faixa_7_8(self) -> None:
        """Nível 6 + acerto → nível 7, tema deve pertencer à faixa 7-8."""
        novo_nivel, tema = calcular_nivel(nivel_atual=6, acertou_anterior=True)
        self.assertEqual(novo_nivel, 7)
        temas_validos = TEMAS_POR_FAIXA[(7, 8)]
        self.assertIn(tema, temas_validos)

    def test_tema_nivel_9_acerto_pertence_faixa_9_10(self) -> None:
        """Nível 9 + acerto → nível 10, tema deve pertencer à faixa 9-10."""
        novo_nivel, tema = calcular_nivel(nivel_atual=9, acertou_anterior=True)
        self.assertEqual(novo_nivel, 10)
        temas_validos = TEMAS_POR_FAIXA[(9, 10)]
        self.assertIn(tema, temas_validos)

    # ------------------------------------------------------------------
    # Validação de entrada
    # ------------------------------------------------------------------
    def test_nivel_0_levanta_value_error(self) -> None:
        """Nível 0 deve levantar ValueError."""
        with self.assertRaises(ValueError):
            calcular_nivel(nivel_atual=0, acertou_anterior=True)

    def test_nivel_11_levanta_value_error(self) -> None:
        """Nível 11 deve levantar ValueError."""
        with self.assertRaises(ValueError):
            calcular_nivel(nivel_atual=11, acertou_anterior=True)

    def test_nivel_negativo_levanta_value_error(self) -> None:
        """Nível negativo deve levantar ValueError."""
        with self.assertRaises(ValueError):
            calcular_nivel(nivel_atual=-1, acertou_anterior=False)

    def test_nivel_string_levanta_value_error(self) -> None:
        """Nível como string deve levantar ValueError."""
        with self.assertRaises(ValueError):
            calcular_nivel(nivel_atual="abc", acertou_anterior=True)  # type: ignore[arg-type]

    # ------------------------------------------------------------------
    # Todos os níveis de 1 a 10 retornam resultado válido
    # ------------------------------------------------------------------
    def test_todos_niveis_validos_acerto(self) -> None:
        """Todos os níveis de 1 a 10 devem retornar resultado válido com acerto."""
        for nivel in range(NIVEL_MINIMO, NIVEL_MAXIMO + 1):
            novo_nivel, tema = calcular_nivel(nivel_atual=nivel, acertou_anterior=True)
            self.assertGreaterEqual(novo_nivel, NIVEL_MINIMO)
            self.assertLessEqual(novo_nivel, NIVEL_MAXIMO)
            self.assertIsInstance(tema, str)
            self.assertTrue(len(tema) > 0)

    def test_todos_niveis_validos_erro(self) -> None:
        """Todos os níveis de 1 a 10 devem retornar resultado válido com erro."""
        for nivel in range(NIVEL_MINIMO, NIVEL_MAXIMO + 1):
            novo_nivel, tema = calcular_nivel(nivel_atual=nivel, acertou_anterior=False)
            self.assertGreaterEqual(novo_nivel, NIVEL_MINIMO)
            self.assertLessEqual(novo_nivel, NIVEL_MAXIMO)
            self.assertIsInstance(tema, str)
            self.assertTrue(len(tema) > 0)
