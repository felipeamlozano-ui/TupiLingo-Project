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


def _normalize_tupi(text: str, ignore_glottal: bool = False) -> str:
    """
    Normalização avançada e fonético-ortográfica para a língua Tupi e variantes:
    - Normalização Unicode NFKC para uniformizar caracteres especiais e compatibilidade.
    - Remove pontuação periférica (. , ! ? " ' ` ; :) que o usuário possa ter digitado por hábito.
    - Unifica apóstrofos/cortes de voz (' ’ ‘ ʻ ʼ ` ´ ′) para apóstrofo padrão ASCII '.
    - Converte 'ç' para 's' (variação entre ortografia jesuítica colonial e Navarro moderno).
    - Remove diacríticos via NFD + descarte de marcas 'Mn' (á, é, í, ó, ú, â, ê, î, ô, û, ŷ, ã, ẽ, ĩ, õ, ũ, ỹ).
    - Opcionalmente ignora o corte de voz / hífen para tolerar omissões (ex: nhe'engatu == nheengatu).
    """
    if not text:
        return ""
    text = unicodedata.normalize('NFKC', text.strip()).strip(' .,!?:;"\'`´~^')
    for apo in ('’', '‘', 'ʻ', 'ʼ', '`', '´', '′'):
        text = text.replace(apo, "'")
    text = text.lower()
    text = text.replace('ç', 's')
    text = ''.join(c for c in unicodedata.normalize('NFD', text) if unicodedata.category(c) != 'Mn')
    if ignore_glottal:
        text = text.replace("'", "").replace("-", "")
    return text


def _normalize(text: str) -> str:
    """Compatibilidade retroativa com código existente."""
    return _normalize_tupi(text, ignore_glottal=False)


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
    Aplica normalização fonético-ortográfica Tupi antes de comparar.
    """
    return _levenshtein(_normalize_tupi(resposta_usuario), _normalize_tupi(resposta_correta))


def _normalize_fallback(text: str) -> str:
    """Alias mantido por compatibilidade com código legado que possa usar este helper."""
    return _normalize_tupi(text)




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
        similaridade: float = 1.0,
    ):
        self.status = status
        self.distancia = distancia
        self.resposta_correta = resposta_correta
        self.mensagem = mensagem
        self.similaridade = similaridade

    def to_dict(self) -> dict:
        return {
            'status': self.status,
            'distancia_levenshtein': self.distancia,
            'similaridade': round(self.similaridade, 3),
            'resposta_correta': self.resposta_correta,
            'mensagem': self.mensagem,
        }


def validar_resposta_fuzzy_global(
    resposta_usuario: str,
    resposta_correta: str,
    limiar_correto: float = 0.90,
    limiar_quase: float = 0.65,
    tolerancia_levenshtein: int = 2,
) -> ValidationResult:
    """
    Validação global unificada com tolerância a pequenos erros de digitação e acentuação Tupi.
    Executa verificação local em Python puro de alta precisão (sub-milissegundo).
    """
    u_raw = (resposta_usuario or '').strip()
    c_raw = (resposta_correta or '').strip()

    if not u_raw or not c_raw:
        return ValidationResult(
            status=ValidationResult.ERRADO,
            distancia=999,
            resposta_correta=c_raw,
            mensagem="Resposta vazia.",
            similaridade=0.0,
        )

    # 1. Verificação fonético-ortográfica Tupi (sem diacríticos, unificando ç/s e apóstrofos)
    u_norm = _normalize_tupi(u_raw)
    c_norm = _normalize_tupi(c_raw)

    # Se normalizado for idêntico (ex: Tataguâsu vs Tatagûasu vs Tataguaçu vs Tataguasu)
    if u_norm == c_norm:
        return ValidationResult(
            status=ValidationResult.CORRETO,
            distancia=0,
            resposta_correta=c_raw,
            mensagem="Correto! 🎉",
            similaridade=1.0,
        )

    # Tolerância a omissão de apóstrofo/corte de voz (ex: tembiu vs tembi'u, nheengatu vs nhe'engatu)
    u_no_glottal = _normalize_tupi(u_raw, ignore_glottal=True)
    c_no_glottal = _normalize_tupi(c_raw, ignore_glottal=True)
    if u_no_glottal == c_no_glottal:
        return ValidationResult(
            status=ValidationResult.CORRETO,
            distancia=0,
            resposta_correta=c_raw,
            mensagem="Correto! 🎉",
            similaridade=0.98,
        )

    # 2. Distância de Levenshtein entre as formas normalizadas
    distancia = _levenshtein(u_norm, c_norm)
    max_len = max(len(u_norm), len(c_norm), 1)
    sim_estimada = max(0.0, 1.0 - (distancia / max_len))

    # Regras dinâmicas de tolerância:
    if distancia <= 1 and max_len >= 4:
        return ValidationResult(
            status=ValidationResult.QUASE_CERTO,
            distancia=distancia,
            resposta_correta=c_raw,
            mensagem=f"Quase lá! Verifique a escrita de '{c_raw}'. Você digitou '{u_raw}'.",
            similaridade=sim_estimada,
        )
    elif distancia <= tolerancia_levenshtein and max_len >= 6:
        return ValidationResult(
            status=ValidationResult.QUASE_CERTO,
            distancia=distancia,
            resposta_correta=c_raw,
            mensagem=f"Quase lá! Verifique a escrita de '{c_raw}'. Você digitou '{u_raw}'.",
            similaridade=sim_estimada,
        )

    return ValidationResult(
        status=ValidationResult.ERRADO,
        distancia=distancia,
        resposta_correta=c_raw,
        mensagem=f"Incorreto. A resposta certa era: '{c_raw}'.",
        similaridade=sim_estimada,
    )


def validar_resposta_completar(
    resposta_usuario: str,
    resposta_correta: str,
    tolerancia: int = 2,
) -> ValidationResult:
    """
    Compatibilidade retroativa: valida a resposta de um ExercicioCompletar
    ou questão temática usando pg_trgm com fallback para Levenshtein.
    """
    return validar_resposta_fuzzy_global(
        resposta_usuario=resposta_usuario,
        resposta_correta=resposta_correta,
        tolerancia_levenshtein=tolerancia,
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

    corretas_validas = [c for c in (respostas_corretas or []) if (c or '').strip()]
    if not corretas_validas:
        return {
            'resultados': [],
            'tudo_correto': False,
            'algum_quase': False,
            'acertos': 0,
            'total': 0,
        }

    # Garante que as listas têm o mesmo tamanho baseando-se nas respostas válidas
    total = max(len(corretas_validas), len(respostas_usuario))
    for i in range(total):
        usuario = respostas_usuario[i] if i < len(respostas_usuario) else ''
        correta = corretas_validas[i] if i < len(corretas_validas) else corretas_validas[0]

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
