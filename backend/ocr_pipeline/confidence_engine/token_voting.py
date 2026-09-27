"""
Engine de Votação e Alinhamento Científico de Tokens — Capítulo 8
Implementa alinhamento global (Needleman-Wunsch), alinhamento local (Smith-Waterman),
distância de Levenshtein, e Beam Search consensus entre 3+ motores do ensemble,
com preservação de diacríticos autênticos Tupi.
"""
import re
from typing import Any, Optional

import numpy as np


class ForensicTokenVotingEngine:
    @staticmethod
    def levenshtein_distance(s1: str, s2: str) -> int:
        """Calcula a distância de edição de Levenshtein."""
        m, n = len(s1), len(s2)
        dp = np.zeros((m + 1, n + 1), dtype=int)
        for i in range(m + 1):
            dp[i, 0] = i
        for j in range(n + 1):
            dp[0, j] = j

        for i in range(1, m + 1):
            for j in range(1, n + 1):
                cost = 0 if s1[i - 1] == s2[j - 1] else 1
                dp[i, j] = min(
                    dp[i - 1, j] + 1,        # Deleção
                    dp[i, j - 1] + 1,        # Inserção
                    dp[i - 1, j - 1] + cost, # Substituição
                )
        return int(dp[m, n])

    @staticmethod
    def needleman_wunsch_align(
        s1: str, s2: str, match: int = 2, mismatch: int = -1, gap: int = -2
    ) -> tuple[str, str, int]:
        """Alinha duas sequências globalmente via Needleman-Wunsch."""
        m, n = len(s1), len(s2)
        score = np.zeros((m + 1, n + 1), dtype=int)

        for i in range(m + 1):
            score[i, 0] = i * gap
        for j in range(n + 1):
            score[0, j] = j * gap

        for i in range(1, m + 1):
            for j in range(1, n + 1):
                diag = score[i - 1, j - 1] + (match if s1[i - 1] == s2[j - 1] else mismatch)
                up = score[i - 1, j] + gap
                left = score[i, j - 1] + gap
                score[i, j] = max(diag, up, left)

        align1, align2 = [], []
        i, j = m, n
        while i > 0 and j > 0:
            current = score[i, j]
            diag = score[i - 1, j - 1]
            if current == diag + (match if s1[i - 1] == s2[j - 1] else mismatch):
                align1.append(s1[i - 1])
                align2.append(s2[j - 1])
                i -= 1
                j -= 1
            elif current == score[i - 1, j] + gap:
                align1.append(s1[i - 1])
                align2.append("-")
                i -= 1
            else:
                align1.append("-")
                align2.append(s2[j - 1])
                j -= 1

        while i > 0:
            align1.append(s1[i - 1])
            align2.append("-")
            i -= 1
        while j > 0:
            align1.append("-")
            align2.append(s2[j - 1])
            j -= 1

        return "".join(reversed(align1)), "".join(reversed(align2)), int(score[m, n])

    @staticmethod
    def smith_waterman_align(
        s1: str, s2: str, match: int = 2, mismatch: int = -1, gap: int = -2
    ) -> tuple[str, str, int]:
        """
        Alinha localmente duas sequências via Smith-Waterman.
        Essencial para trechos parcialmente corrompidos ou fragmentados.
        """
        m, n = len(s1), len(s2)
        score = np.zeros((m + 1, n + 1), dtype=int)
        max_score = 0
        max_pos = (0, 0)

        for i in range(1, m + 1):
            for j in range(1, n + 1):
                diag = score[i - 1, j - 1] + (match if s1[i - 1] == s2[j - 1] else mismatch)
                up = score[i - 1, j] + gap
                left = score[i, j - 1] + gap
                val = max(0, diag, up, left)
                score[i, j] = val
                if val > max_score:
                    max_score = val
                    max_pos = (i, j)

        # Rastreamento a partir da pontuação máxima até encontrar 0
        align1, align2 = [], []
        i, j = max_pos
        while i > 0 and j > 0 and score[i, j] > 0:
            current = score[i, j]
            diag = score[i - 1, j - 1]
            if current == diag + (match if s1[i - 1] == s2[j - 1] else mismatch):
                align1.append(s1[i - 1])
                align2.append(s2[j - 1])
                i -= 1
                j -= 1
            elif current == score[i - 1, j] + gap:
                align1.append(s1[i - 1])
                align2.append("-")
                i -= 1
            else:
                align1.append("-")
                align2.append(s2[j - 1])
                j -= 1

        return "".join(reversed(align1)), "".join(reversed(align2)), int(max_score)

    def beam_search_consensus(
        self,
        candidate_strings: list[str],
        candidate_weights: Optional[list[float]] = None,
        beam_width: int = 4,
    ) -> tuple[str, float]:
        """
        Executa Beam Search sobre alinhamento múltiplo de strings
        para selecionar a sequência mais provável sob divergência de 3+ motores.
        """
        if not candidate_strings:
            return "", 0.0
        if len(candidate_strings) == 1:
            return candidate_strings[0], 100.0

        weights = candidate_weights or [1.0] * len(candidate_strings)
        total_w = sum(weights)
        norm_weights = [w / total_w for w in weights]

        # Alinhamento progressivo baseado na string mais longa
        base_str = max(candidate_strings, key=len)
        max_len = len(base_str)

        # Beam: lista de tuplas (prefixo, score_acumulado)
        beam = [("", 0.0)]

        for pos in range(max_len):
            new_beam = []
            # Contagem ponderada de caracteres nesta posição
            char_votes: dict[str, float] = {}
            for s, w in zip(candidate_strings, norm_weights):
                c = s[pos] if pos < len(s) else ""
                char_votes[c] = char_votes.get(c, 0.0) + w

            for prefix, score in beam:
                for char, weight in char_votes.items():
                    # Ignora transição vazia se a base ainda tiver caracteres
                    if not char and pos < max_len - 1:
                        continue
                    new_beam.append((prefix + char, score + weight))

            # Podar para os top-K da largura de feixe
            new_beam.sort(key=lambda x: x[1], reverse=True)
            beam = new_beam[:beam_width]

        best_seq, best_score = beam[0]
        consensus_ratio = (best_score / max(max_len, 1)) * 100.0
        return best_seq, min(100.0, round(consensus_ratio, 2))

    def vote_on_candidates(
        self,
        candidates: list[dict[str, Any]],
    ) -> tuple[str, float, str, float]:
        """
        Realiza votação ponderada entre múltiplos candidatos OCR.
        Retorna: (winner_text, winner_conf, winner_engine, agreement_score)
        """
        if not candidates:
            return "", 0.0, "none", 0.0

        if len(candidates) == 1:
            c = candidates[0]
            return c["text"], c["confidence"], c["engine"], 100.0

        # Pesos base por motor
        engine_weights = {
            "rapidocr_gpu": 1.40,
            "rapidocr": 1.35,
            "tesseract_psm6": 1.05,
            "tesseract_psm3": 1.00,
            "tesseract_psm11": 0.98,
            "tesseract_psm4": 0.95,
            "tesseract": 0.90,
        }

        scored_candidates = []
        for c in candidates:
            text = c["text"]
            conf = c["confidence"]
            engine = c["engine"]
            base_w = engine_weights.get(engine, 1.0)

            # Bônus para diacríticos nasais autênticos Tupi
            tupi_diacritic_bonus = 1.25 if re.search(r"[ẽĩỹõãẽẼĨỸÕÃ]", text) else 1.0

            # Penalidade se o texto for ruído isolado de caracteres não alfanuméricos
            alpha_ratio = len(re.findall(r"[a-zA-ZáéíóúÁÉÍÓÚãõÃÕâêîôûÂÊÎÔÛẽĩỹẼĨỸçÇ]", text)) / max(len(text), 1)
            alpha_penalty = 0.5 if alpha_ratio < 0.3 else 1.0

            total_score = conf * base_w * tupi_diacritic_bonus * alpha_penalty
            scored_candidates.append((total_score, text, conf, engine, base_w))

        scored_candidates.sort(key=lambda x: x[0], reverse=True)
        winner_score, winner_text, winner_conf, winner_engine, _ = scored_candidates[0]

        # Se houver 3+ candidatos divergentes, aplicar beam search consensus para refinamento
        if len(candidates) >= 3:
            texts = [c["text"] for c in candidates]
            weights = [engine_weights.get(c["engine"], 1.0) for c in candidates]
            consensus_text, consensus_score = self.beam_search_consensus(texts, weights)
            # Se o consensus do beam search for idêntico ou muito próximo, valida a concordância
            agree_score = consensus_score
        else:
            # Calcular concordância média com outros candidatos (Jaccard sobre caracteres)
            agreements = []
            winner_chars = set(winner_text)
            for _, other_text, _, _, _ in scored_candidates[1:]:
                other_chars = set(other_text)
                inter = len(winner_chars.intersection(other_chars))
                union = len(winner_chars.union(other_chars))
                agreements.append(inter / max(union, 1))
            mean_agree = float(np.mean(agreements)) if agreements else 1.0
            agree_score = round(mean_agree * 100.0, 2)

        return winner_text, winner_conf, winner_engine, agree_score
