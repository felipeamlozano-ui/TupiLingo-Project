"""
Serviço de heurística para o nivelamento adaptativo.

Responsabilidade exclusiva: determinar o próximo nível e o tema
apropriado com base no desempenho do usuário.

Não deve acessar serviços externos (Gemini, ChromaDB, Supabase, etc.).
"""

import logging
import random

logger = logging.getLogger("nivelamento.heuristica")

# Limites do nível
NIVEL_MINIMO: int = 1
NIVEL_MAXIMO: int = 10

# Mapeamento de faixas de nível → lista de temas possíveis.
# Estrutura extensível: basta adicionar novos temas à lista da faixa.
TEMAS_POR_FAIXA: dict[tuple[int, int], list[str]] = {
    (1, 2): [
        "vocabulário básico",
        "substantivos",
        "saudações",
        "números",
    ],
    (3, 4): [
        "fauna",
        "flora",
        "cores",
        "elementos da natureza",
    ],
    (5, 6): [
        "verbos básicos",
        "frases simples",
        "partes do corpo",
        "alimentos",
    ],
    (7, 8): [
        "estruturas gramaticais",
        "conjugação verbal",
        "frases compostas",
    ],
    (9, 10): [
        "interpretação",
        "estruturas avançadas",
        "expressões idiomáticas",
    ],
}


def calcular_nivel(
    nivel_atual: int,
    acertou_anterior: bool | None,
) -> tuple[int, str]:
    """
    Calcula o próximo nível e seleciona um tema adequado.

    Args:
        nivel_atual: Nível atual do usuário (1 a 10).
        acertou_anterior: Se o usuário acertou a questão anterior. Se None, mantém o nível.

    Returns:
        Tupla (novo_nivel, tema_escolhido).

    Raises:
        ValueError: Se o nivel_atual estiver fora do intervalo permitido.
    """
    if not isinstance(nivel_atual, int) or not (NIVEL_MINIMO <= nivel_atual <= NIVEL_MAXIMO):
        raise ValueError(
            f"nivel_atual deve ser um inteiro entre {NIVEL_MINIMO} e {NIVEL_MAXIMO}, "
            f"recebido: {nivel_atual!r}"
        )

    # Calcular novo nível com clamping
    if acertou_anterior is None:
        novo_nivel = nivel_atual
    elif acertou_anterior:
        novo_nivel = min(nivel_atual + 1, NIVEL_MAXIMO)
    else:
        novo_nivel = max(nivel_atual - 1, NIVEL_MINIMO)

    # Selecionar tema adequado à faixa do novo nível
    tema = _selecionar_tema(novo_nivel)

    logger.info(
        "[HEURISTIC] nivel_atual=%d acertou=%s → novo_nivel=%d tema='%s'",
        nivel_atual,
        acertou_anterior,
        novo_nivel,
        tema,
    )

    return novo_nivel, tema


def _selecionar_tema(nivel: int) -> str:
    """
    Seleciona um tema aleatório da faixa correspondente ao nível.

    Args:
        nivel: Nível do usuário (1 a 10).

    Returns:
        Tema selecionado.
    """
    for (faixa_min, faixa_max), temas in TEMAS_POR_FAIXA.items():
        if faixa_min <= nivel <= faixa_max:
            return random.choice(temas)

    # Fallback seguro (não deveria acontecer com nível validado)
    logger.warning("[HEURISTIC] Nível %d não mapeado a nenhuma faixa, usando fallback", nivel)
    return "vocabulário básico"
