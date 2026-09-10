"""
Validation Service — Tolerância a Erros via Python Puro.

Utiliza normalização unicode (unicodedata) e Levenshtein em Python puro para
calcular a distância de edição entre strings sem depender de extensões PostgreSQL.

Vantagens sobre a implementação anterior (fuzzystrmatch + unaccent):
- Sem round-trip SQL por validação (melhor latência, menos conexões ao banco).
- Testável sem banco de dados.
- Sem dependência de extensões externas no PostgreSQL.

Regras de validação para ExercicioCompletar:
- Distância 0: ✅ correct — resposta exata.
- Distância 1 (palavras curtas <= 4 chars) ou
  Distância 1-2 (palavras médias 5-8 chars): ⚠️ almost — "Quase lá! Faltou uma letra."
- Acima da tolerância: ❌ wrong.

A tolerância exata por exercício é configurável via `ExercicioCompletar.tolerancia_levenshtein`.
"""

import logging
import unicodedata

logger = logging.getLogger(__name__)


def _normalize(text: str) -> str:
    """
    Normaliza texto para comparação:
    - Strip de espaços
    - Lowercase
    - Remove diacríticos (acentos) via decomposição unicode NFD + filtro de Mn
    """
    text = text.strip().lower()
    return "".join(
        c for c in unicodedata.normalize("NFD", text) if unicodedata.category(c) != "Mn"
    )


def _levenshtein(s1: str, s2: str) -> int:
    """
    Calcula a distância de Levenshtein entre duas strings em Python puro.
    Complexidade: O(m*n) tempo e O(min(m,n)) espaço.
    """
    if s1 == s2:
        return 0
    len1, len2 = len(s1), len(s2)
    # Garante que s2 seja a string mais curta para economizar memória
    if len1 < len2:
        s1, s2 = s2, s1
        len1, len2 = len2, len1

    row = list(range(len2 + 1))
    for i, c1 in enumerate(s1, 1):
        prev = i
        for j, c2 in enumerate(s2, 1):
            current = row[j - 1] if c1 == c2 else 1 + min(row[j - 1], row[j], prev)
            row[j - 1] = prev
            prev = current
        row[len2] = prev
    return row[len2]


def _run_levenshtein_query(resposta_usuario: str, resposta_correta: str) -> int:
    """
    Calcula a distância de Levenshtein entre as duas respostas usando Python puro.
    Aplica normalização (sem acentos, lowercase) antes de comparar.

    Retorna a distância (int). Menor = mais próximo. 0 = idêntico.
    """
    return _levenshtein(_normalize(resposta_usuario), _normalize(resposta_correta))


def _normalize_fallback(text: str) -> str:
    """Alias mantido por compatibilidade com código legado que possa usar este helper."""
    return _normalize(text)


class ValidationResult:
    """Resultado da validação de uma resposta."""

    CORRETO = "correct"
    QUASE_CERTO = "almost"
    ERRADO = "wrong"

    def __init__(
        self,
        status: str,
        distancia: int,
        resposta_correta: str,
        mensagem: str = "",
    ):
        self.status = status
        self.distancia = distancia
        self.resposta_correta = resposta_correta
        self.mensagem = mensagem

    def to_dict(self) -> dict:
        return {
            "status": self.status,
            "distancia_levenshtein": self.distancia,
            "resposta_correta": self.resposta_correta,
            "mensagem": self.mensagem,
        }


def validar_resposta_completar(
    resposta_usuario: str,
    resposta_correta: str,
    tolerancia: int = 2,
) -> ValidationResult:
    """
    Valida a resposta de um ExercicioCompletar.

    Args:
        resposta_usuario: O que o usuário digitou.
        resposta_correta: A resposta esperada (armazenada no banco).
        tolerancia: Distância máxima de Levenshtein permitida para "Quase lá".
                    Configurável por exercício via ExercicioCompletar.tolerancia_levenshtein.

    Returns:
        ValidationResult com status, distância e mensagem de feedback.
    """
    if not resposta_usuario or not resposta_correta:
        return ValidationResult(
            status=ValidationResult.ERRADO,
            distancia=999,
            resposta_correta=resposta_correta,
            mensagem="Resposta vazia.",
        )

    distancia = _run_levenshtein_query(resposta_usuario, resposta_correta)

    if distancia == 0:
        return ValidationResult(
            status=ValidationResult.CORRETO,
            distancia=0,
            resposta_correta=resposta_correta,
            mensagem="Correto! 🎉",
        )

    if 0 < distancia <= tolerancia:
        return ValidationResult(
            status=ValidationResult.QUASE_CERTO,
            distancia=distancia,
            resposta_correta=resposta_correta,
            mensagem=(
                f"Quase lá! Verifique a escrita de '{resposta_correta}'. "
                f"Você digitou '{resposta_usuario}'."
            ),
        )

    return ValidationResult(
        status=ValidationResult.ERRADO,
        distancia=distancia,
        resposta_correta=resposta_correta,
        mensagem=f"Incorreto. A resposta correta era '{resposta_correta}'.",
    )


def validar_lista_lacunas(
    respostas_usuario: list[str],
    respostas_corretas: list[str],
    tolerancia: int = 2,
) -> dict:
    """
    Valida todas as lacunas de um ExercicioCompletar com múltiplas lacunas.

    Args:
        respostas_usuario: Lista com o que o usuário digitou em cada lacuna.
        respostas_corretas: Lista com as respostas esperadas para cada lacuna.
        tolerancia: Distância máxima de Levenshtein permitida.

    Returns:
        Dict com:
        - 'resultados': lista de ValidationResult.to_dict() por lacuna.
        - 'tudo_correto': True se todas as lacunas estão corretas.
        - 'algum_quase': True se alguma lacuna está "quase certa".
        - 'acertos': número de lacunas totalmente corretas.
        - 'total': total de lacunas.
    """
    resultados = []
    acertos = 0
    algum_quase = False

    # Garante que as listas têm o mesmo tamanho
    total = max(len(respostas_corretas), len(respostas_usuario))
    for i in range(total):
        usuario = respostas_usuario[i] if i < len(respostas_usuario) else ""
        correta = respostas_corretas[i] if i < len(respostas_corretas) else ""

        resultado = validar_resposta_completar(usuario, correta, tolerancia)
        resultados.append(resultado.to_dict())

        if resultado.status == ValidationResult.CORRETO:
            acertos += 1
        elif resultado.status == ValidationResult.QUASE_CERTO:
            algum_quase = True

    return {
        "resultados": resultados,
        "tudo_correto": acertos == total and total > 0,
        "algum_quase": algum_quase,
        "acertos": acertos,
        "total": total,
    }


def calcular_xp_exercicio(
    pontos_base: int,
    primeira_tentativa: bool,
    resultado_status: str,
    bonus_exploracao: int = 0,
) -> int:
    """
    Calcula o XP concedido ao usuário após completar um exercício.

    Fórmula: XP = base + bonus_primeira_tentativa + bonus_acerto_total + bonus_exploracao

    Args:
        pontos_base: XP base do exercício (configurado no modelo).
        primeira_tentativa: True se o usuário acertou na primeira tentativa.
        resultado_status: 'correct', 'almost' ou 'wrong'.
        bonus_exploracao: XP bônus por ter explorado StoryBlocks de curiosidade.

    Returns:
        XP total a ser creditado (int).
    """
    xp = 0

    if resultado_status == ValidationResult.CORRETO:
        xp += pontos_base
        if primeira_tentativa:
            xp += 10  # Bônus por primeira tentativa
    elif resultado_status == ValidationResult.QUASE_CERTO:
        xp += int(pontos_base * 0.7)  # 70% do XP base por "quase certo"
    # 'wrong': 0 XP base, mas mantém o bônus de exploração

    xp += bonus_exploracao
    return max(0, xp)
