"""
Engine de Votação e Alinhamento de Tokens — TupiLingo OCR Forense v3.0
Implementa alinhamento por programação dinâmica (Needleman-Wunsch), distância de Levenshtein,
e votação ponderada por motor com salvaguarda de diacríticos Tupi.
"""
import re
from typing import Any

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
                    dp[i - 1, j] + 1,      # Deleção
                    dp[i, j - 1] + 1,      # Inserção
                    dp[i - 1, j - 1] + cost # Substituição
                )
        return int(dp[m, n])

    @staticmethod
    def needleman_wunsch_align(s1: str, s2: str, match: int = 2, mismatch: int = -1, gap: int = -2) -> tuple[str, str, int]:
        """Alinha duas sequências de caracteres globalmente via Needleman-Wunsch."""
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

    def vote_on_candidates(
        self,
        candidates: list[dict[str, Any]]
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
            "rapidocr": 1.35, # Superior no papel escaneado
            "tesseract_psm6": 1.0,
            "tesseract_psm4": 0.95,
            "tesseract": 0.90
        }

        scored_candidates = []
        texts = [c["text"] for c in candidates]

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
            scored_candidates.append((total_score, text, conf, engine))

        scored_candidates.sort(key=lambda x: x[0], reverse=True)
        winner_score, winner_text, winner_conf, winner_engine = scored_candidates[0]

        # Calcular concordância média com outros candidatos (Jaccard sobre caracteres)
        agreements = []
        winner_chars = set(winner_text)
        for _, other_text, _, _ in scored_candidates[1:]:
            other_chars = set(other_text)
            inter = len(winner_chars.intersection(other_chars))
            union = len(winner_chars.union(other_chars))
            agreements.append(inter / max(union, 1))

        mean_agree = float(np.mean(agreements)) if agreements else 1.0
        return winner_text, winner_conf, winner_engine, round(mean_agree * 100.0, 2)
