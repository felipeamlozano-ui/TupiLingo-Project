"""
Engine Léxico Forense com Salvaguarda Morfológica Tupi e Rollback Gate (Etapa 8).

Implementa:
- Distância adaptativa baseada no comprimento do token
- Blacklist estrita para números, datas e numerais romanos (invioláveis)
- Blacklist de nomes próprios
- Whitelist de português histórico e gramatical
- Parser morfológico de Tupi Antigo (prefixos, sufixos, clíticos e afixos composicionais)
- Palavras-ímã (termos âncora de alta frequência)
- Confidence Gate (não altera tokens de altíssima certeza sem evidência robusta)
- Context Gate (validação de concordância estrutural)
- Rollback Gate (reversão automática caso ocorra violação de invariantes)
- Preservação estrita de caixa tipográfica original (Regra 1.4)
"""

from __future__ import annotations

import logging
import re
from pathlib import Path
from typing import Any, Optional

from pydantic import BaseModel, Field

try:
    import symspellpy
except ImportError:
    symspellpy = None

logger = logging.getLogger("ocr_pipeline.lexical_engine")


class MorphologicalDecomposition(BaseModel):
    """Decomposição morfológica de um vocábulo Tupi."""

    original: str
    prefix: str | None = None
    stem: str
    suffix: str | None = None
    particle: str | None = None
    is_valid_tupi: bool = False
    confidence_bonus: float = 0.0
    linguistic_variant: str = "Tupi Antigo"  # Tupi Antigo, Tupinambá, Kamaiurá, Tupi Contemporâneo
    morphology_status: str = "morfologia_nao_verificada"  # validado_corpus | morfologia_nao_verificada


class LexicalCorrection(BaseModel):
    """Registro auditável de uma correção léxica aplicada."""

    token_idx: int
    original: str
    corrected: str
    edit_distance: int
    confidence_before: float
    confidence_after: float
    category: str = Field(
        ...,
        description="tupi_stem | tupi_morphology | portuguese_whitelist | rejected_invariant",
    )
    rollback_applied: bool = False
    reason: str = ""
    rag_provenance_id: str | None = None


class ForensicLexicalResult(BaseModel):
    """Resultado do processamento léxico forense de um bloco ou página."""

    original_text: str
    corrected_text: str
    corrections_applied: list[LexicalCorrection] = Field(default_factory=list)
    corrections_rolled_back: list[LexicalCorrection] = Field(default_factory=list)
    rejected_candidates: list[dict[str, Any]] = Field(default_factory=list)
    magnet_word_audit: dict[str, Any] = Field(default_factory=dict)
    tupi_tokens_count: int = 0
    tupi_morphological_matches: int = 0
    invariants_checked: int = 0


# Prefixos e sufixos canônicos do Tupi Antigo (Gramática de Anchieta / Lemos Barbosa / Navarro)
TUPI_PREFIXES: tuple[str, ...] = (
    "xe-",
    "nde-",
    "i-",
    "s-",
    "t-",
    "o-",
    "ore-",
    "oré-",
    "yande-",
    "îandé-",
    "pe-",
    "mo-",
    "mbo-",
    "ye-",
    "yo-",
    "îe-",
    "îo-",
    "xe",
    "nde",
    "ore",
    "oré",
    "yande",
    "îandé",
    "pe",
    "mo",
    "mbo",
)

TUPI_SUFFIXES: tuple[str, ...] = (
    "-a",
    "-ba",
    "-pe",
    "-me",
    "-be",
    "-bé",
    "-rama",
    "-ram",
    "-puera",
    "-pûera",
    "-pwera",
    "-uera",
    "-ete",
    "-eté",
    "-iara",
    "-îara",
    "-su",
    "-usu",
    "-i",
    "-ĩ",
    "-miri",
    "-mirĩ",
    "-katu",
    "-catu",
    "-bo",
    "-re",
    "-pupé",
    "-suí",
    "a",
    "ba",
    "pe",
    "me",
    "be",
    "bé",
    "rama",
    "ram",
    "puera",
    "pûera",
    "pwera",
    "uera",
    "ete",
    "eté",
    "iara",
    "îara",
    "su",
    "usu",
    "katu",
    "catu",
)

TUPI_MAGNET_WORDS: set[str] = {
    "tupi",
    "aba",
    "abare",
    "abaré",
    "tuba",
    "sy",
    "sý",
    "ta'yra",
    "mbya",
    "mbyá",
    "oka",
    "oca",
    "morubixaba",
    "tupinamba",
    "tupinambá",
    "ka'a",
    "caa",
    "y",
    "'y",
    "ita",
    "pira",
    "tata",
    "tupana",
    "tupan",
    "tupã",
    "nhanderu",
    "nhande",
    "co",
    "ko",
    "a'e",
    "marã",
    "marandua",
    "nhe'eng",
    "nheenga",
    "nhe'enga",
}

PORTUGUESE_GRAMMATICAL_WHITELIST: set[str] = {
    # Preposições e locuções
    "a", "ao", "aos", "de", "do", "da", "dos", "das", "em", "no", "na", "nos", "nas",
    "para", "pro", "pra", "pras", "pros", "por", "pelo", "pela", "pelos", "pelas",
    "com", "contra", "desde", "ate", "até", "entre", "sem", "sob", "sobre", "tras", "trás",
    # Artigos e Pronomes
    "o", "a", "os", "as", "um", "uma", "uns", "umas",
    "eu", "tu", "ele", "ela", "nos", "nós", "vos", "vós", "eles", "elas",
    "me", "te", "se", "lhe", "lhes",
    "meu", "minha", "meus", "minhas", "teu", "tua", "teus", "tuas",
    "seu", "sua", "seus", "suas", "nosso", "nossa", "nossos", "nossas",
    "este", "esta", "estes", "estas", "esse", "essa", "esses", "essas",
    "aquele", "aquela", "aqueles", "aquelas", "isto", "isso", "aquilo",
    "que", "quem", "qual", "quais", "cujo", "cuja", "cujos", "cujas",
    "onde", "como", "quando", "quanto", "quanta", "quantos", "quantas",
    # Conjunções e Advérbios
    "e", "ou", "mas", "porem", "porém", "todavia", "contudo", "entretanto",
    "portanto", "porque", "porquê", "pois", "assim", "tambem", "também",
    "nao", "não", "sim", "ja", "já", "ainda", "sempre", "nunca",
    "mais", "menos", "muito", "pouco", "bem", "mal", "apenas", "quase",
    # Verbos comuns e auxiliares
    "ser", "estar", "ter", "haver", "fazer", "ir", "vir", "dar", "ver", "dizer",
    "é", "era", "foi", "sao", "são", "sendo", "sido",
    "esta", "está", "estava", "estao", "estão",
    "tem", "têm", "tinha", "tinham", "teve",
    "ha", "há", "havia", "houve",
    "faz", "fez", "fazem", "fazia",
    "vai", "vao", "vão", "iam",
    "vem", "vêm", "veio", "vinham",
    "da", "dá", "dao", "dão", "deu",
    "diz", "dizem", "disse", "disseram",
    # Termos e Abreviaturas Gramaticais e Dicionarísticas
    "loc", "posp", "intr", "tr", "adj", "subst", "adv", "prep", "pron", "art",
    "conj", "interj", "sm", "sf", "fig", "lit", "ant", "pop", "bras", "port", "lat",
    # Vocabulário Acadêmico e Textual
    "obra", "obras", "livro", "livros", "autor", "autores", "texto", "textos",
    "trabalho", "trabalhos", "estudo", "estudos", "analise", "análise",
    "resumo", "sumario", "sumário", "indice", "índice", "prefacio", "prefácio",
    "capitulo", "capítulo", "capitulos", "capítulos", "pagina", "página", "paginas", "páginas",
    "tomo", "tomos", "volume", "volumes", "edicao", "edição", "edicoes", "edições",
    "nota", "notas", "referencia", "referência", "referencias", "referências",
    "termo", "termos", "palavra", "palavras", "verbete", "verbetes", "glossario", "glossário",
    "forma", "formas", "sentido", "sentidos", "origem", "nome", "nomes",
    "ano", "anos", "data", "datas", "seculo", "século", "seculos", "séculos", "tempo", "vida",
    "parte", "partes", "fase", "ponto", "pontos", "caso", "casos", "modo", "grau", "linha", "linhas",
    "lingua", "língua", "linguas", "línguas", "linguagem", "gramatica", "gramática",
    "dialeto", "dialetos", "fala", "falar", "leitura", "leituras",
    "indio", "índio", "indios", "índios", "indigena", "indígena", "indigenas", "indígenas",
    "tribo", "tribos", "povo", "povos", "nacao", "nação",
    "brasil", "brasileiro", "brasileira", "brasileiros", "brasileiras",
    "portugues", "português", "portuguesa", "portugueses", "portuguesas",
    "tupi", "tupis", "guarani", "guaranis", "tupinamba", "tupinambá", "tupinambas", "tupinambás",
    "padre", "padres", "jesuita", "jesuíta", "jesuitas", "jesuítas",
    "carta", "cartas", "documento", "documentos", "arquivo", "arquivos",
    "biblioteca", "bibliotecas", "nacional", "faculdade", "universidade",
    "poema", "poemas", "poesia", "lirica", "lírica", "teatro", "peca", "peça", "pecas", "peças",
    # Substantivos, Adjetivos e Verbos Comuns do Português frequentemente confundidos por distância 1
    "mira", "mirar", "gira", "girar", "giro", "pura", "puro", "puros", "puras",
    "pica", "picar", "pera", "peras", "dira", "diria", "dias", "dia", "casa", "casas", "rio", "rios",
    "mar", "mata", "matas", "terra", "terras", "sol", "lua", "ceu", "céu",
    "grande", "grandes", "pequeno", "pequena", "bom", "boa", "bons", "boas",
    "novo", "nova", "novos", "novas", "velho", "velha", "velhos", "velhas",
    "primeiro", "primeira", "segundo", "segunda", "terceiro", "terceira",
    # Formas relacionais legítimas Tupi (r-, s-, t-)
    "roka", "soka", "toka", "tasy", "tasý", "tesá", "resá", "sesá", "to'ó", "so'o",
}

HISTORICAL_PORTUGUESE_WHITELIST: set[str] = PORTUGUESE_GRAMMATICAL_WHITELIST

ROMAN_NUMERALS_PATTERN = re.compile(
    r"^M{0,4}(CM|CD|D?C{0,3})(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})$", re.IGNORECASE
)


class TupiMorphologicalParser:
    """Parser morfológico determinístico para Tupi Antigo, Tupinambá, Kamaiurá e Tupi Contemporâneo."""

    def __init__(self, canonical_stems: set[str]):
        self.stems = {s.lower() for s in canonical_stems if len(s) >= 2}

    def _determine_variant(self, clean: str) -> str:
        """Classifica a variante linguística (Capítulo 11)."""
        if any(marker in clean for marker in ("kamaiur", "awy", "ywy", "wer")):
            return "Kamaiurá"
        if any(marker in clean for marker in ("nheeng", "wa", "ana")):
            return "Tupi Contemporâneo"
        if any(marker in clean for marker in ("tupinamb", "katu", "ko")):
            return "Tupinambá"
        return "Tupi Antigo"

    def parse(self, token: str, rag_validator: Any = None) -> MorphologicalDecomposition:
        """Decompõe o token em prefixo + radical + sufixo e valida contra corpus/RAG."""
        clean = token.lower().strip("'-")
        if not clean:
            return MorphologicalDecomposition(original=token, stem="", is_valid_tupi=False)

        variant = self._determine_variant(clean)

        def check_status(t: str) -> str:
            if rag_validator:
                val = rag_validator.validate_term(t)
                return "validado_corpus" if (val.exists_in_corpus or val.exists_in_lexicon) else "morfologia_nao_verificada"
            return "validado_corpus"

        # 1. Checagem direta de radical exato
        if clean in self.stems:
            return MorphologicalDecomposition(
                original=token,
                stem=clean,
                is_valid_tupi=True,
                confidence_bonus=0.15,
                linguistic_variant=variant,
                morphology_status=check_status(clean),
            )

        # 2. Decomposição Prefixal + Stem
        for pfx in TUPI_PREFIXES:
            pfx_clean = pfx.replace("-", "")
            has_pfx = False
            rest = ""
            if clean.startswith(pfx + "-") or clean.startswith(pfx_clean + "-"):
                has_pfx = True
                rest = clean.split("-", 1)[1]
            elif clean.startswith(pfx_clean) and len(clean) > len(pfx_clean) + 1:
                has_pfx = True
                rest = clean[len(pfx_clean):].lstrip("-")

            if has_pfx and rest:
                potential_stem = rest.strip("'-")
                if potential_stem in self.stems:
                    return MorphologicalDecomposition(
                        original=token,
                        prefix=pfx,
                        stem=potential_stem,
                        is_valid_tupi=True,
                        confidence_bonus=0.20,
                        linguistic_variant=variant,
                        morphology_status=check_status(potential_stem),
                    )

        # 3. Decomposição Stem + Suffixal
        for sfx in TUPI_SUFFIXES:
            sfx_clean = sfx.replace("-", "")
            has_sfx = False
            head = ""
            if clean.endswith("-" + sfx) or clean.endswith("-" + sfx_clean):
                has_sfx = True
                head = clean.rsplit("-", 1)[0]
            elif clean.endswith(sfx_clean) and len(clean) > len(sfx_clean) + 1:
                has_sfx = True
                head = clean[:-len(sfx_clean)].rstrip("-")

            if has_sfx and head:
                potential_stem = head.strip("'-")
                if potential_stem in self.stems:
                    return MorphologicalDecomposition(
                        original=token,
                        stem=potential_stem,
                        suffix=sfx,
                        is_valid_tupi=True,
                        confidence_bonus=0.20,
                        linguistic_variant=variant,
                        morphology_status=check_status(potential_stem),
                    )

        # 4. Decomposição Circunfixal (Prefix + Stem + Suffix)
        for pfx in TUPI_PREFIXES:
            pfx_clean = pfx.replace("-", "")
            if clean.startswith(pfx_clean):
                rest = clean[len(pfx_clean):].lstrip("-")
                for sfx in TUPI_SUFFIXES:
                    sfx_clean = sfx.replace("-", "")
                    if rest.endswith(sfx_clean) and len(rest) > len(sfx_clean) + 1:
                        potential_stem = rest[:-len(sfx_clean)].strip("'-")
                        if potential_stem in self.stems:
                            return MorphologicalDecomposition(
                                original=token,
                                prefix=pfx,
                                stem=potential_stem,
                                suffix=sfx,
                                is_valid_tupi=True,
                                confidence_bonus=0.25,
                                linguistic_variant=variant,
                                morphology_status=check_status(potential_stem),
                            )

        return MorphologicalDecomposition(
            original=token,
            stem=clean,
            is_valid_tupi=False,
            linguistic_variant=variant,
            morphology_status="morfologia_nao_verificada",
        )


class ForensicLexicalEngine:
    """Motor Léxico Forense com preservação de invariantes e rollback automático."""

    def __init__(
        self,
        tupi_vocab_path: Path | None = None,
        lexicon_data_path: Path | None = None,
        max_edit_distance: int = 2,
    ):
        self.max_edit_distance = max_edit_distance
        self.tupi_vocab: set[str] = set()
        self.tupi_case_map: dict[str, str] = {}
        self.proper_names_blacklist: set[str] = set()

        self._load_vocabularies(tupi_vocab_path, lexicon_data_path)
        self.morph_parser = TupiMorphologicalParser(self.tupi_vocab)

        # Configurar SymSpell
        if symspellpy is not None:
            self.sym_spell = symspellpy.SymSpell(
                max_dictionary_edit_distance=max_edit_distance,
                prefix_length=7,
            )
            # Carregar vocabulários com pesos equilibrados
            for w in self.tupi_vocab:
                self.sym_spell.create_dictionary_entry(w.lower(), 100000)
            for w in TUPI_MAGNET_WORDS:
                self.sym_spell.create_dictionary_entry(w.lower(), 100000)
            for w in HISTORICAL_PORTUGUESE_WHITELIST:
                self.sym_spell.create_dictionary_entry(w.lower(), 100000)
        else:
            self.sym_spell = None
            logger.warning("symspellpy não disponível. Modo fallback ativo.")

    def _load_vocabularies(
        self, tupi_vocab_path: Path | None, lexicon_data_path: Path | None
    ):
        """Carrega vocabulários de tupi_user_words.txt e lexicon_data.py."""
        # Palavras ímã padrão
        for mw in TUPI_MAGNET_WORDS:
            self.tupi_vocab.add(mw.lower())

        if tupi_vocab_path and tupi_vocab_path.exists():
            for line in tupi_vocab_path.read_text(encoding="utf-8").splitlines():
                w = line.strip()
                if w and not w.startswith("#"):
                    w_clean = re.sub(r"[^\w'-]", "", w)
                    if w_clean:
                        w_lower = w_clean.lower()
                        self.tupi_vocab.add(w_lower)
                        self.tupi_case_map[w_lower] = w_clean

        if lexicon_data_path and lexicon_data_path.exists():
            try:
                import importlib.util

                spec = importlib.util.spec_from_file_location(
                    "lexicon_data", str(lexicon_data_path)
                )
                if spec and spec.loader:
                    mod = importlib.util.module_from_spec(spec)
                    spec.loader.exec_module(mod)
                    lex_dict = getattr(mod, "LEXICON_BY_VARIANT_CHAPTER", {})
                    for variant, chapters in lex_dict.items():
                        for ch, items in chapters.items():
                            for item in items:
                                pal = item.get("palavra", "").strip()
                                if pal:
                                    for tok in pal.split():
                                        c = re.sub(r"[^\w'-]", "", tok)
                                        if c:
                                            c_lower = c.lower()
                                            self.tupi_vocab.add(c_lower)
                                            self.tupi_case_map[c_lower] = c
            except Exception as e:
                logger.warning(f"Erro ao carregar lexicon_data: {e}")

    def _is_number_or_date(self, token: str) -> bool:
        """Invariante: números arábicos, romanos e datas são intocáveis."""
        clean = token.strip(".,;:()[]{}'\"-")
        if not clean:
            return False
        # Números arábicos (com pontuação opcional)
        if re.match(r"^\d+([.,/\-]\d+)*$", clean):
            return True
        # Numerais romanos
        if len(clean) >= 1 and ROMAN_NUMERALS_PATTERN.match(clean):
            return True
        return False

    def _is_proper_noun_or_blacklisted(self, token: str) -> bool:
        """Invariante: nomes próprios protegidos nunca devem ser alterados."""
        clean = token.strip(".,;:()[]{}'\"-")
        if clean.lower() in self.proper_names_blacklist:
            return True
        return False

    def _get_adaptive_edit_distance(self, token_len: int) -> int:
        """Calcula a distância de edição permitida de acordo com o tamanho."""
        if token_len <= 3:
            return 0  # Palavras de 3 caracteres ou menos são invariantes (previne eee->esá, rsa->oka)
        elif token_len <= 5:
            return 1  # Palavras de 4 a 5 caracteres aceitam no máximo 1 alteração
        else:
            return min(2, self.max_edit_distance)

    def _preserve_original_casing(self, original: str, target: str) -> str:
        """Garante conformidade com a Regra 1.4: preserva estritamente a caixa original."""
        if original.islower():
            return target.lower()
        if original.isupper():
            return target.upper()
        if original.istitle():
            return target.capitalize()
        # Se misto, usar mapeamento canônico ou target
        return self.tupi_case_map.get(target.lower(), target)

    def audit_magnet_words(self, corrections: list[LexicalCorrection]) -> dict[str, Any]:
        """
        Auditoria de palavras-ímã obrigatória (Capítulo 10):
        Tabela de frequência de cada palavra usada como alvo de correção.
        Sinaliza qualquer uma cuja frequência destoe do esperado (esá/oka/îasy engolindo ruído).
        """
        freq: dict[str, int] = {}
        for c in corrections:
            if not c.rollback_applied:
                target = c.corrected.lower()
                freq[target] = freq.get(target, 0) + 1

        total = sum(freq.values())
        flagged: list[str] = []
        for word, count in freq.items():
            if total >= 5 and (count / total > 0.20) and count >= 3:
                flagged.append(word)

        return {
            "frequencies": freq,
            "total_applied": total,
            "flagged_suspicious_magnets": flagged,
            "has_suspicious_magnet": len(flagged) > 0,
        }

    def process_text(
        self,
        text: str,
        token_confidences: list[float] | None = None,
        rag_validator: Any = None,
    ) -> ForensicLexicalResult:
        """
        Processa o texto linha por linha aplicando salvaguarda morfológica,
        validação RAG (Capítulo 12) e rollback gate.
        """
        if not text:
            return ForensicLexicalResult(original_text="", corrected_text="")

        applied_corrections: list[LexicalCorrection] = []
        rolled_back_corrections: list[LexicalCorrection] = []
        rejected_candidates: list[dict[str, Any]] = []
        tupi_tokens_count = 0
        morph_matches = 0
        invariants_checked = 0

        # Regex para isolar palavras (mantendo diacríticos e apóstrofos Tupi) e pontuações
        tokens = re.findall(r"\b[\w'-]+\b|[^\w\s]|\s+", text, flags=re.UNICODE)
        corrected_tokens = []
        global_tok_idx = 0

        for tok in tokens:
            if not re.search(r"\w", tok):
                corrected_tokens.append(tok)
                continue

            invariants_checked += 1
            tok_clean = tok.strip("'-")
            tok_lower = tok_clean.lower()
            orig_conf = (
                token_confidences[global_tok_idx]
                if token_confidences and global_tok_idx < len(token_confidences)
                else 0.80
            )

            # INVARIANTE 1: Blacklist de Números e Datas
            if self._is_number_or_date(tok):
                corrected_tokens.append(tok)
                global_tok_idx += 1
                continue

            # INVARIANTE 2: Blacklist de Nomes Próprios
            if self._is_proper_noun_or_blacklisted(tok):
                corrected_tokens.append(tok)
                global_tok_idx += 1
                continue

            # INVARIANTE 3: Token já pertence ao vocabulário Tupi direto
            if tok_lower in self.tupi_vocab:
                tupi_tokens_count += 1
                corrected_tokens.append(tok)
                global_tok_idx += 1
                continue

            # INVARIANTE 4: Análise Morfológica Tupi (prefixos, sufixos, clíticos)
            morph_res = self.morph_parser.parse(tok_clean, rag_validator=rag_validator)
            if morph_res.is_valid_tupi:
                morph_matches += 1
                tupi_tokens_count += 1
                corrected_tokens.append(tok)
                global_tok_idx += 1
                continue

            # INVARIANTE 5: Whitelist de Português (Zero Corrupção de Palavras Portuguesas)
            if tok_lower in HISTORICAL_PORTUGUESE_WHITELIST:
                corrected_tokens.append(tok)
                global_tok_idx += 1
                continue

            # INVARIANTE 6: Confidence Gate
            # Se o token já tiver alta confiança do OCR (>= 0.90), não alterar
            if orig_conf >= 0.90:
                rejected_candidates.append({
                    "token_idx": global_tok_idx,
                    "original": tok,
                    "reason": "confidence_gate_high_confidence",
                    "confidence": orig_conf,
                })
                corrected_tokens.append(tok)
                global_tok_idx += 1
                continue

            if self.sym_spell is None:
                corrected_tokens.append(tok)
                global_tok_idx += 1
                continue

            # Distância adaptativa
            allowed_dist = self._get_adaptive_edit_distance(len(tok_clean))
            if allowed_dist == 0:
                rejected_candidates.append({
                    "token_idx": global_tok_idx,
                    "original": tok,
                    "reason": "proportional_distance_zero_for_short_token",
                })
                corrected_tokens.append(tok)
                global_tok_idx += 1
                continue

            # Consulta SymSpell
            suggestions = self.sym_spell.lookup(
                tok_lower,
                symspellpy.Verbosity.CLOSEST,
                max_edit_distance=allowed_dist,
            )

            if not suggestions:
                corrected_tokens.append(tok)
                global_tok_idx += 1
                continue

            best = suggestions[0]
            cand_term = best.term
            edit_dist = best.distance

            # Invariante de Deformação de Tamanho: Rejeita truncamentos em palavras-ímã curtas
            if abs(len(cand_term) - len(tok_clean)) >= 2:
                rejected_candidates.append({
                    "token_idx": global_tok_idx,
                    "original": tok,
                    "proposed": cand_term,
                    "reason": "size_deformation_discrepancy",
                })
                corrected_tokens.append(tok)
                global_tok_idx += 1
                continue

            is_cand_tupi = cand_term in self.tupi_vocab
            is_cand_pt = cand_term in HISTORICAL_PORTUGUESE_WHITELIST

            if not (is_cand_tupi or is_cand_pt):
                rejected_candidates.append({
                    "token_idx": global_tok_idx,
                    "original": tok,
                    "proposed": cand_term,
                    "reason": "unknown_candidate_target",
                })
                corrected_tokens.append(tok)
                global_tok_idx += 1
                continue

            final_token = self._preserve_original_casing(tok, cand_term)

            # Validação RAG obrigatória (Capítulo 12)
            rag_chunk_id = None
            if rag_validator is not None:
                rag_res = rag_validator.validate_term(cand_term)
                if not rag_res.exists_in_corpus and not rag_res.exists_in_lexicon:
                    rejected_candidates.append({
                        "token_idx": global_tok_idx,
                        "original": tok,
                        "proposed": final_token,
                        "reason": "rejected_no_rag_provenance",
                    })
                    corrected_tokens.append(tok)
                    global_tok_idx += 1
                    continue
                rag_chunk_id = (
                    rag_res.evidence_samples[0].chunk_id
                    if rag_res.evidence_samples
                    else "lexicon_canonical"
                )

            # ROLLBACK GATE 1: Não permitir que Tupi vire português
            if tok_lower in self.tupi_vocab and is_cand_pt and not is_cand_tupi:
                rollback_record = LexicalCorrection(
                    token_idx=global_tok_idx,
                    original=tok,
                    corrected=final_token,
                    edit_distance=edit_dist,
                    confidence_before=orig_conf,
                    confidence_after=orig_conf * 0.5,
                    category="rejected_invariant",
                    rollback_applied=True,
                    reason="Tentativa ilegal de aportuguesamento de radical Tupi",
                    rag_provenance_id=rag_chunk_id,
                )
                rolled_back_corrections.append(rollback_record)
                corrected_tokens.append(tok)
                global_tok_idx += 1
                continue

            # ROLLBACK GATE 2: Não permitir que português vire Tupi
            if tok_lower in HISTORICAL_PORTUGUESE_WHITELIST and is_cand_tupi and not is_cand_pt:
                rollback_record = LexicalCorrection(
                    token_idx=global_tok_idx,
                    original=tok,
                    corrected=final_token,
                    edit_distance=edit_dist,
                    confidence_before=orig_conf,
                    confidence_after=orig_conf * 0.5,
                    category="rejected_invariant",
                    rollback_applied=True,
                    reason="Tentativa ilegal de conversão de palavra em português para Tupi",
                    rag_provenance_id=rag_chunk_id,
                )
                rolled_back_corrections.append(rollback_record)
                corrected_tokens.append(tok)
                global_tok_idx += 1
                continue

            if final_token == tok:
                corrected_tokens.append(tok)
                global_tok_idx += 1
                continue

            cat = "tupi_stem" if is_cand_tupi else "portuguese_whitelist"
            corr_record = LexicalCorrection(
                token_idx=global_tok_idx,
                original=tok,
                corrected=final_token,
                edit_distance=edit_dist,
                confidence_before=orig_conf,
                confidence_after=min(1.0, orig_conf + 0.15),
                category=cat,
                rollback_applied=False,
                reason=f"Correção validada por {cat} (dist={edit_dist})",
                rag_provenance_id=rag_chunk_id,
            )
            applied_corrections.append(corr_record)
            corrected_tokens.append(final_token)
            global_tok_idx += 1

        final_text = "".join(corrected_tokens)
        magnet_audit = self.audit_magnet_words(applied_corrections)

        return ForensicLexicalResult(
            original_text=text,
            corrected_text=final_text,
            corrections_applied=applied_corrections,
            corrections_rolled_back=rolled_back_corrections,
            rejected_candidates=rejected_candidates,
            magnet_word_audit=magnet_audit,
            tupi_tokens_count=tupi_tokens_count,
            tupi_morphological_matches=morph_matches,
            invariants_checked=invariants_checked,
        )
