"""
Validation Service — Tolerância a Erros via PostgreSQL Extensions.

Utiliza as extensões do Supabase/PostgreSQL:
- unaccent: Remove acentos para comparação normalizda.
  Ex: "Tupã" == "Tupa" (após unaccent).
- fuzzystrmatch (levenshtein): Calcula a distância de edição entre duas strings.
  Ex: levenshtein("karai", "karia") → 2 (dois caracteres diferentes).

Regras de validação para ExercicioCompletar:
- Distância 0: ✅ CORRETO — resposta exata.
- Distância 1 (palavras curtas <= 4 chars) ou
  Distância 1-2 (palavras médias 5-8 chars): ⚠️ QUASE_CERTO — "Quase lá! Faltou uma letra."
- Acima da tolerância: ❌ ERRADO.

A tolerância exata por exercício é configurável via `ExercicioCompletar.tolerancia_levenshtein`.
"""

import logging
from django.db import connection

logger = logging.getLogger(__name__)


def _run_levenshtein_query(resposta_usuario: str, resposta_correta: str) -> int:
    """
    Executa a query de cálculo de distância de Levenshtein via PostgreSQL.
    Aplica unaccent e lower em ambas as strings antes de comparar.

    Retorna a distância (int). Menor = mais próximo. 0 = idêntico.
    """
    sql = """
        SELECT levenshtein(
            unaccent(lower(%s)),
            unaccent(lower(%s))
        )
    """
    try:
        with connection.cursor() as cursor:
            cursor.execute(sql, [resposta_usuario.strip(), resposta_correta.strip()])
            row = cursor.fetchone()
            return row[0] if row else 999
    except Exception as exc:
        # Fallback: se a extensão não estiver disponível, usa comparação simples
        logger.warning(
            "levenshtein/unaccent não disponível no banco. Usando fallback simples. Erro: %s",
            exc
        )
        return 0 if _normalize_fallback(resposta_usuario) == _normalize_fallback(resposta_correta) else 999


def _normalize_fallback(text: str) -> str:
    """Normalização básica sem extensão PostgreSQL (fallback de emergência)."""
    import unicodedata
    text = text.strip().lower()
    # Remove diacríticos manualmente
    return ''.join(
        c for c in unicodedata.normalize('NFD', text)
        if unicodedata.category(c) != 'Mn'
    )


class ValidationResult:
    """Resultado da validação de uma resposta."""
    CORRETO = 'correct'
    QUASE_CERTO = 'almost'
    ERRADO = 'wrong'

    def __init__(
        self,
        status: str,
        distancia: int,
        resposta_correta: str,
        mensagem: str = '',
    ):
        self.status = status
        self.distancia = distancia
        self.resposta_correta = resposta_correta
        self.mensagem = mensagem

    def to_dict(self) -> dict:
        return {
            'status': self.status,
            'distancia_levenshtein': self.distancia,
            'resposta_correta': self.resposta_correta,
            'mensagem': self.mensagem,
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
        usuario = respostas_usuario[i] if i < len(respostas_usuario) else ''
        correta = respostas_corretas[i] if i < len(respostas_corretas) else ''

        resultado = validar_resposta_completar(usuario, correta, tolerancia)
        resultados.append(resultado.to_dict())

        if resultado.status == ValidationResult.CORRETO:
            acertos += 1
        elif resultado.status == ValidationResult.QUASE_CERTO:
            algum_quase = True

    return {
        'resultados': resultados,
        'tudo_correto': acertos == total and total > 0,
        'algum_quase': algum_quase,
        'acertos': acertos,
        'total': total,
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
