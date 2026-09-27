"""
Worker de Correção Léxica Restrita e Salvaguarda Tupi (Etapa 8 da Fase 1).
Utiliza SymSpell para correção de ruído de OCR preservando estritamente
o vocabulário Tupi autêntico contra aportuguesamento indevido.
Salva auditoria com texto antes e depois de cada correção.
"""
import re
from pathlib import Path
from typing import Any

import symspellpy

# Palavras frequentes de português histórico / gramatical verificáveis em dicionários coloniais
HISTORICAL_PORTUGUESE_LEXICON = [
    "dicionario", "dicionário", "vocabulario", "vocabulário", "antigo", "lingua", "língua",
    "geral", "gramatica", "gramática", "capitulo", "capítulo", "homem", "mulher", "menino",
    "aldeia", "flecha", "canoa", "roca", "roça", "farinha", "peixe", "floresta", "mata",
    "rio", "substantivo", "adjetivo", "verbo", "pronome", "posposicao", "posposição",
    "significado", "traducao", "tradução", "exemplo", "dialeto", "tupinamba", "tupinambá",
    "tupiniquim", "guarani", "nheengatu", "brasiliensis", "jesuita", "jesuíta", "seculo", "século"
]

class LexiconWorker:
    def __init__(
        self,
        tupi_words_file: Path | None = None,
        lexicon_data_path: Path | None = None,
        max_edit_distance: int = 2
    ):
        self.max_edit_distance = max_edit_distance
        self.sym_spell = symspellpy.SymSpell(
            max_dictionary_edit_distance=max_edit_distance,
            prefix_length=7
        )
        self.tupi_vocab: set[str] = set()
        self.tupi_vocab_lower: set[str] = set()
        self.tupi_case_map: dict[str, str] = {}
        
        self._load_lexicons(tupi_words_file, lexicon_data_path)

    def _load_lexicons(
        self,
        tupi_words_file: Path | None,
        lexicon_data_path: Path | None
    ):
        # 1. Carregar tupi_user_words.txt
        if tupi_words_file and tupi_words_file.exists():
            for line in tupi_words_file.read_text(encoding="utf-8").splitlines():
                w = line.strip()
                if w and not w.startswith("#"):
                    self.tupi_vocab.add(w)
                    w_lower = w.lower()
                    self.tupi_vocab_lower.add(w_lower)
                    self.tupi_case_map[w_lower] = w
                    # Peso prioritário máximo para vocabulário Tupi
                    self.sym_spell.create_dictionary_entry(w_lower, 10000)

        # 2. Carregar termos do lexicon_data.py
        if lexicon_data_path and lexicon_data_path.exists():
            try:
                import importlib.util
                spec = importlib.util.spec_from_file_location("lexicon_data", str(lexicon_data_path))
                mod = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(mod)
                lex_dict = getattr(mod, "LEXICON_BY_VARIANT_CHAPTER", {})
                for variant, chapters in lex_dict.items():
                    for ch, items in chapters.items():
                        for item in items:
                            pal = item.get("palavra", "").strip()
                            if pal:
                                for token in pal.split():
                                    t_clean = re.sub(r"[^\w'-]", "", token)
                                    if t_clean:
                                        self.tupi_vocab.add(t_clean)
                                        t_lower = t_clean.lower()
                                        self.tupi_vocab_lower.add(t_lower)
                                        self.tupi_case_map[t_lower] = t_clean
                                        self.sym_spell.create_dictionary_entry(t_lower, 10000)
            except Exception:
                pass

        # 3. Carregar léxico de apoio em português histórico com peso intermediário
        for pt_word in HISTORICAL_PORTUGUESE_LEXICON:
            pt_lower = pt_word.lower()
            if pt_lower not in self.tupi_vocab_lower:
                self.sym_spell.create_dictionary_entry(pt_lower, 500)

    def is_tupi_word(self, word: str) -> bool:
        """Verifica se a palavra pertence ao léxico Tupi mapeado."""
        return word.lower() in self.tupi_vocab_lower

    def correct_text(self, text: str) -> tuple[str, str, list[dict[str, Any]]]:
        """
        Aplica correção léxica restrita com salvaguarda estrita contra aportuguesamento.
        Retorna: (texto_original, texto_corrigido, lista_de_correcoes)
        """
        if not text:
            return "", "", []

        corrections_applied = []
        lines = text.splitlines()
        corrected_lines = []

        for line_idx, line in enumerate(lines):
            # Tokenizar preservando pontuação e apóstrofos (ex: ka'a, 'y)
            tokens = re.findall(r"\b[\w'-]+\b|[^\w\s]", line, flags=re.UNICODE)
            new_line_parts = []

            for token in tokens:
                # Se não for palavra alfanumérica, mantém pontuação
                if not re.match(r"^[\w'-]+$", token):
                    new_line_parts.append(token)
                    continue

                t_lower = token.lower()

                # SALVAGUARDA 1: Se já for uma palavra Tupi legítima, NUNCA altere!
                if t_lower in self.tupi_vocab_lower:
                    new_line_parts.append(token)
                    continue

                # Se a palavra for muito curta (<= 2 caracteres) e não for Tupi conhecida, não altere
                if len(token) <= 2:
                    new_line_parts.append(token)
                    continue

                # Buscar candidatos de correção
                suggestions = self.sym_spell.lookup(
                    t_lower,
                    symspellpy.Verbosity.CLOSEST,
                    max_edit_distance=self.max_edit_distance
                )

                if suggestions:
                    best = suggestions[0]
                    cand_lower = best.term

                    # SALVAGUARDA 2: Se a sugestão for Tupi, priorize imediatamente!
                    if cand_lower in self.tupi_vocab_lower:
                        # Preservar rigorosamente a caixa do token original da fonte (Regra 1.4)
                        if token.islower():
                            canonical = cand_lower.lower()
                        elif token.isupper():
                            canonical = cand_lower.upper()
                        elif token.istitle():
                            canonical = cand_lower.capitalize()
                        else:
                            canonical = self.tupi_case_map.get(cand_lower, cand_lower)
                        
                        if canonical != token:
                            corrections_applied.append({
                                "line": line_idx + 1,
                                "original": token,
                                "corrected": canonical,
                                "distance": best.distance,
                                "type": "tupi_restoration"
                            })
                            new_line_parts.append(canonical)
                        else:
                            new_line_parts.append(token)
                        continue

                    # Se a sugestão for portuguesa, só aplica se houver erro claro de OCR
                    # e NÃO colidir com termos Tupi próximos
                    if best.distance == 1 and cand_lower in HISTORICAL_PORTUGUESE_LEXICON:
                        if token.islower():
                            replacement = cand_lower.lower()
                        elif token.isupper():
                            replacement = cand_lower.upper()
                        elif token.istitle():
                            replacement = cand_lower.capitalize()
                        else:
                            replacement = cand_lower

                        if replacement != token:
                            corrections_applied.append({
                                "line": line_idx + 1,
                                "original": token,
                                "corrected": replacement,
                                "distance": best.distance,
                                "type": "portuguese_typo_fix"
                            })
                            new_line_parts.append(replacement)
                        else:
                            new_line_parts.append(token)
                        continue

                # Caso nenhuma sugestão seja aceita com segurança, mantém original
                new_line_parts.append(token)

            # Reconstruir linha reconstruindo espaçamento
            reconstructed = ""
            for part in new_line_parts:
                if re.match(r"^[.,;:!?)]", part):
                    reconstructed += part
                elif part == "(" or not reconstructed:
                    reconstructed += (" " + part if reconstructed and not reconstructed.endswith(" ") else part)
                else:
                    reconstructed += " " + part
            corrected_lines.append(reconstructed.strip())

        text_after = "\n".join(corrected_lines)
        return text, text_after, corrections_applied
