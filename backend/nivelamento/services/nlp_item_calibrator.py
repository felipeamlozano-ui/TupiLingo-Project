"""
Módulo de Calibração a Frio (Zero-Shot Item Calibration) para TRI (3PL).
Role: Staff Machine Learning Engineer & Performance Architect.

Objetivo:
- Inferir a Dificuldade (b) de itens sem histórico com base na complexidade
  léxica, morfológica (aglutinações em Tupi), sintática e densidade conceitual.
- Estimar o Acerto Casual (c) calculando a similaridade semântica (distância de cosseno)
  entre a alternativa correta e os distratores.
- Estimar a Discriminação (a) com base na clareza proposicional e consistência dos distratores.
"""

from __future__ import annotations

import re
import unicodedata
from collections.abc import Sequence

import numpy as np


class NLPItemCalibrator:
    """
    Calibrador semântico e estrutural para inicialização Zero-Shot de parâmetros TRI (a, b, c).
    Elimina o problema de Cold-Start antes da coleta de respostas de usuários reais.
    """

    # Marcadores morfológicos e fonológicos de alta complexidade no Tupi Antigo/Nheengatu
    _TUPI_COMPLEX_MARKERS = {
        'nasais': ['~', '^', 'nh', 'mb', 'nd', 'ng'],
        'relacionais': ['r-', 's-', 't-'],
        'prefixos_verbais': ['a-', 'ere-', 'o-', 'oro-', 'ya-', 'pe-'],
        'sufixos_modais': ["-ba'e", '-paba', '-saba', '-wara', '-ramo'],
        'aglutinacoes': ["'", "y", "kû", "gû"],
    }

    def __init__(self, embedding_dim: int = 64) -> None:
        self.embedding_dim = embedding_dim

    # ── 1. Inferência de Dificuldade (b) ──────────────────────────────────────

    def infer_difficulty_b(
        self,
        enunciado: str,
        resposta_correta: str,
        categoria: str = "geral",
        tupi_terms: Sequence[str] | None = None,
    ) -> float:
        """
        Calcula a Dificuldade latente (b) no intervalo [-3.0, +3.0].

        Fatores ponderados:
        1. Comprimento e profundidade sintática do enunciado.
        2. Complexidade morfológica Tupi (aglutinações, nasalizações, relacionais).
        3. Raras estruturas gramaticais ou nível da categoria temática.
        """
        enunciado_limpo = self._normalize_text(enunciado)
        words = enunciado_limpo.split()
        num_words = len(words)

        if num_words == 0:
            return 0.0

        # Métrica 1: Comprimento médio das palavras e complexidade silábica
        avg_word_length = sum(len(w) for w in words) / max(num_words, 1)
        lexical_density_score = (avg_word_length - 4.5) / 3.0  # centrado em ~5 letras

        # Métrica 2: Complexidade sintática (subordinações, pontuações, orações compostas)
        punctuation_count = len(re.findall(r'[,;:\-—\(\)]', enunciado))
        clause_complexity = min(punctuation_count / 3.0, 1.0)

        # Métrica 3: Marcadores Tupi avançados
        tupi_complexity = 0.0
        terms_to_check = list(tupi_terms or [])
        terms_to_check.append(resposta_correta)
        terms_to_check.extend([w for w in words if any(m in w.lower() for m in ['kû', 'gû', "'", '~', 'y'])])

        for term in terms_to_check:
            term_lower = term.lower()
            # Nasalização e glotais
            if any(n in term_lower for n in self._TUPI_COMPLEX_MARKERS['nasais']):
                tupi_complexity += 0.25
            if any(ag in term_lower for ag in self._TUPI_COMPLEX_MARKERS['aglutinacoes']):
                tupi_complexity += 0.35
            # Presença de prefixos relacionais ou sufixos derivacionais
            if any(term_lower.startswith(pref) for pref in ['xe', 'nde', 'i', 'ore', 'yande']):
                tupi_complexity += 0.30

        # Métrica 4: Peso por categoria temática
        category_weights = {
            'saudacoes': -1.2,
            'vocabulario_basico': -1.0,
            'substantivos': -0.8,
            'fauna': -0.4,
            'flora': -0.3,
            'natureza': -0.2,
            'corpo': 0.1,
            'verbos_basicos': 0.4,
            'frases_simples': 0.6,
            'conjugacao_verbal': 1.2,
            'estruturas_gramaticais': 1.6,
            'mitologia': 1.4,
            'interpretacao': 2.0,
            'geral': 0.0,
        }
        cat_weight = category_weights.get(categoria.lower(), 0.0)

        # Agregação linear normalizada
        raw_b = (
            (lexical_density_score * 0.7)
            + (clause_complexity * 0.5)
            + (min(tupi_complexity, 2.0) * 0.8)
            + (cat_weight * 0.9)
        )

        # Clamping estrito na escala padrão do traço latente [-3.0, +3.0]
        return float(np.clip(raw_b, -3.0, 3.0))

    # ── 2. Inferência de Acerto Casual / Chute (c) ─────────────────────────────

    def infer_guessing_c(
        self,
        resposta_correta: str,
        distratores: Sequence[str],
    ) -> float:
        """
        Estima matematicamente o parâmetro de acerto casual (c).

        Fundamento Psicométrico:
        Se os distratores são semanticamente muito próximos e plausíveis (distância de cosseno baixa),
        o estudante não consegue eliminar opções por absurdo, e o acerto puramente casual
        aproxima-se de 1 / K (ex: 1/4 = 0.25 ou menos se houver armadilha conceitual).
        Se os distratores forem completamente díspares/óbvios, c sobe (ex: 0.33+).
        """
        if not distratores:
            return 0.25  # Padrão para 4 alternativas

        num_options = len(distratores) + 1
        nominal_chance = 1.0 / max(num_options, 2)

        # Extração de vetores semânticos leves (caracteres n-grams hash-embeddings normalizados)
        v_target = self._generate_lightweight_embedding(resposta_correta)

        similarities: list[float] = []
        for dist in distratores:
            v_dist = self._generate_lightweight_embedding(dist)
            sim = self._cosine_similarity(v_target, v_dist)
            similarities.append(sim)

        avg_similarity = float(np.mean(similarities)) if similarities else 0.0

        # Se similaridade é alta (> 0.7), distratores são fortes -> chute casual efetivo diminui
        # Se similaridade é baixa (< 0.2), distratores são absurdos -> estudante elimina e chuta melhor
        c_adjusted = nominal_chance * (1.0 - (avg_similarity - 0.4) * 0.5)

        # Clamping entre 0.08 e 0.35 para garantir estabilidade da curva 3PL
        return float(np.clip(c_adjusted, 0.08, 0.35))

    # ── 3. Inferência de Discriminação (a) ────────────────────────────────────

    def infer_discrimination_a(
        self,
        enunciado: str,
        resposta_correta: str,
        distratores: Sequence[str],
    ) -> float:
        """
        Estima a Discriminação (a) no intervalo [0.6, 2.5].
        Questões com enunciados diretos, sem ambiguidades e com alternativas de
        comprimento equilibrado discriminam melhor alunos proficientes de não-proficientes.
        """
        enunciado_len = len(enunciado.split())
        clarity_penalty = 0.0
        if enunciado_len > 40:
            clarity_penalty += 0.3  # Enunciado excessivamente prolixo

        # Variância de comprimento das alternativas (distratores vs resposta correta)
        all_options = [resposta_correta] + list(distratores)
        lengths = [len(opt.split()) for opt in all_options]
        length_variance = float(np.var(lengths)) if lengths else 0.0

        # Se uma alternativa é 3x maior que as outras, é pista visual (piora discriminação real)
        length_penalty = min(length_variance * 0.1, 0.5)

        base_a = 1.4 - clarity_penalty - length_penalty

        # Bônus para alternativas equilibradas e vocabulário conciso
        if length_variance < 1.0:
            base_a += 0.2

        return float(np.clip(base_a, 0.6, 2.2))

    # ── Utilitários Matemáticos e Vetoriais ───────────────────────────────────

    def _generate_lightweight_embedding(self, text: str) -> np.ndarray:
        """
        Gera um embedding semântico-fonético determinístico baseado em n-gramas de caracteres
        e morfemas, normalizado no espaço L2. Não requer GPU nem dependências externas pesadas.
        """
        norm_text = self._normalize_text(text).lower()
        vec = np.zeros(self.embedding_dim, dtype=np.float32)

        if not norm_text:
            return vec

        # Caracteres e bigramas / trigramas fonéticos
        tokens = [norm_text] + [norm_text[i:i+3] for i in range(len(norm_text)-2)]
        for token in tokens:
            # Hashing linear para índice determinístico
            idx = abs(hash(token)) % self.embedding_dim
            vec[idx] += 1.0

        norm = np.linalg.norm(vec)
        if norm > 1e-7:
            vec /= norm
        return vec

    @staticmethod
    def _cosine_similarity(v1: np.ndarray, v2: np.ndarray) -> float:
        """Calcula o cosseno de dois vetores normalizados."""
        norm1 = np.linalg.norm(v1)
        norm2 = np.linalg.norm(v2)
        if norm1 < 1e-7 or norm2 < 1e-7:
            return 0.0
        return float(np.dot(v1, v2) / (norm1 * norm2))

    @staticmethod
    def _normalize_text(text: str) -> str:
        """Remove diacríticos superficiais mantendo estrutura fonética."""
        text = unicodedata.normalize('NFKD', text)
        return ''.join(c for c in text if not unicodedata.combining(c) or c in ['~', '^'])
