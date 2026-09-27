"""
Validador RAG Forense Zero Alucinação (Etapa 9).

Integração com o vector store SQLite local (vector_store.db) e léxicos históricos:
- Validação de existência no corpus documental real (22.140 chunks)
- Validação de variantes linguísticas (Tupinambá, Kamaiurá, Potiguara, Nheengatu)
- Validação de coocorrência contextual em janelas de n-gramas
- Rejeição estrita de termos sem evidência empírica (Zero Alucinação)
"""

from __future__ import annotations

import json
import logging
import re
import sqlite3
from pathlib import Path

from pydantic import BaseModel, Field

logger = logging.getLogger("ocr_pipeline.rag_validation")


class CorpusOccurrence(BaseModel):
    """Ocorrência documental encontrada no acervo histórico."""

    chunk_id: str
    filename: str | None = None
    page: int | None = None
    snippet: str
    relevance_score: float = 1.0


class RAGValidationResult(BaseModel):
    """Resultado detalhado da validação RAG de um termo ou frase."""

    term: str
    exists_in_corpus: bool = False
    corpus_occurrences_count: int = 0
    exists_in_lexicon: bool = False
    variant_detected: str | None = None
    context_cooccurrence_score: float = 0.0
    is_hallucination: bool = False
    rag_confidence_score: float = 0.0
    evidence_samples: list[CorpusOccurrence] = Field(default_factory=list)
    verdict: str = Field(
        ...,
        description="confirmed_corpus | confirmed_lexicon | confirmed_morphology | rejected_hallucination",
    )


class RAGValidator:
    """Validador RAG contra o acervo histórico indexado e dicionários."""

    def __init__(
        self,
        vector_store_path: Path | None = None,
        lexicon_data_path: Path | None = None,
    ):
        self.vector_store_path = (
            vector_store_path
            if vector_store_path and vector_store_path.exists()
            else Path("vector_store.db")
        )
        self.lexicon_terms: set[str] = set()
        self.variant_map: dict[str, str] = {}
        self._cache: dict[str, RAGValidationResult] = {}
        self.corpus_words: set[str] = set()
        self._conn: sqlite3.Connection | None = None
        if self.vector_store_path.exists():
            try:
                self._conn = sqlite3.connect(
                    f"file:{self.vector_store_path.resolve()}?mode=ro",
                    uri=True,
                    check_same_thread=False,
                )
                self._load_corpus_index()
            except Exception as e:
                logger.warning(f"Aviso ao abrir conexão persistente com vector_store: {e}")

        self._load_lexicon(lexicon_data_path)

    def _load_corpus_index(self):
        """Indexa em memória os termos existentes nos 22.140 chunks para busca O(1)."""
        if self._conn is None:
            return
        try:
            cursor = self._conn.cursor()
            cursor.execute("SELECT document FROM documents")
            for r in cursor.fetchall():
                if r[0]:
                    for w in re.findall(r"[\w'-]+", r[0].lower()):
                        self.corpus_words.add(w)
            logger.info(f"RAGValidator: {len(self.corpus_words)} termos indexados em memória.")
        except Exception as e:
            logger.warning(f"Erro ao indexar corpus em memória: {e}")

    def close(self):
        """Fecha a conexão com o banco se aberta."""
        if self._conn is not None:
            try:
                self._conn.close()
            except Exception:
                pass
            self._conn = None

    def __del__(self):
        self.close()

    def _load_lexicon(self, lexicon_data_path: Path | None):
        """Carrega vocabulário estruturado por variantes de lexicon_data.py."""
        target_path = (
            lexicon_data_path
            if lexicon_data_path and lexicon_data_path.exists()
            else Path("pedagogico/lexicon_data.py")
        )
        if not target_path.exists():
            return

        try:
            import importlib.util

            spec = importlib.util.spec_from_file_location("lexicon_data_rag", str(target_path))
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
                                    c = re.sub(r"[^\w'-]", "", tok).lower()
                                    if c:
                                        self.lexicon_terms.add(c)
                                        self.variant_map[c] = variant
        except Exception as e:
            logger.warning(f"Erro ao carregar lexicon_data para RAG: {e}")

    def _query_corpus(self, term: str, limit: int = 5) -> list[CorpusOccurrence]:
        """Consulta o banco SQLite local em modo leitura rápida com conexão persistente."""
        if not self.vector_store_path.exists():
            return []

        clean_term = term.strip("'-").lower()
        if len(clean_term) < 2:
            return []

        occurrences: list[CorpusOccurrence] = []
        try:
            if self._conn is None:
                self._conn = sqlite3.connect(
                    f"file:{self.vector_store_path.resolve()}?mode=ro",
                    uri=True,
                    check_same_thread=False,
                )
            cursor = self._conn.cursor()
            query = """
                SELECT id, document, metadata 
                FROM documents 
                WHERE document LIKE ? 
                LIMIT ?
            """
            cursor.execute(query, (f"%{clean_term}%", limit))
            rows = cursor.fetchall()
            for doc_id, doc_text, meta_str in rows:
                meta = {}
                if meta_str:
                    try:
                        meta = json.loads(meta_str)
                    except Exception:
                        meta = {}

                # Extrair snippet ao redor da palavra
                snippet = ""
                idx = doc_text.lower().find(clean_term)
                if idx >= 0:
                    start = max(0, idx - 40)
                    end = min(len(doc_text), idx + len(clean_term) + 40)
                    snippet = doc_text[start:end].replace("\n", " ").strip()
                else:
                    snippet = doc_text[:100].replace("\n", " ").strip()

                occurrences.append(
                    CorpusOccurrence(
                        chunk_id=str(doc_id),
                        filename=meta.get("filename"),
                        page=meta.get("page"),
                        snippet=snippet,
                        relevance_score=1.0,
                    )
                )
        except Exception as e:
            logger.debug(f"Aviso na consulta ao vector_store: {e}")

        return occurrences

    def validate_term(
        self,
        term: str,
        context_words: list[str] | None = None,
        fetch_snippets: bool = False,
    ) -> RAGValidationResult:
        """
        Valida se o termo tem evidência no corpus documental ou léxico histórico.
        Rejeita alucinações (termos inventados sem suporte empírico).
        """
        clean = term.strip(".,;:()[]{}'\"-")
        clean_lower = clean.lower()

        if clean_lower in self._cache:
            return self._cache[clean_lower]

        # 0. Verificação de números ou ausência de caracteres alfabéticos
        if not re.search(r"[a-zA-ZáéíóúÁÉÍÓÚãõÃÕâêîôûÂÊÎÔÛẽĩỹẼĨỸçÇ]", clean_lower):
            res = RAGValidationResult(
                term=term,
                exists_in_corpus=True,
                rag_confidence_score=1.0,
                verdict="confirmed_morphology",
            )
            self._cache[clean_lower] = res
            return res

        # 1. Consulta ao léxico estruturado
        in_lexicon = clean_lower in self.lexicon_terms
        variant = self.variant_map.get(clean_lower)

        # 2. Consulta ao acervo documental real (vector_store.db via set em memória)
        if self.corpus_words:
            in_corpus = clean_lower in self.corpus_words
            corpus_matches = self._query_corpus(clean_lower, limit=3) if (in_corpus and fetch_snippets) else []
        else:
            corpus_matches = self._query_corpus(clean_lower, limit=3)
            in_corpus = len(corpus_matches) > 0

        # 3. Análise de coocorrência de contexto
        context_score = 0.0
        if in_corpus and context_words and corpus_matches:
            cw_lower = {w.lower() for w in context_words if len(w) > 3}
            if cw_lower:
                matched_ctx = 0
                for occ in corpus_matches:
                    snip_lower = occ.snippet.lower()
                    for cw in cw_lower:
                        if cw in snip_lower:
                            matched_ctx += 1
                context_score = min(1.0, matched_ctx / (len(cw_lower) * len(corpus_matches)))

        # 4. Cálculo do RAG Confidence e Detecção de Alucinação
        if in_corpus and in_lexicon:
            rag_conf = 1.0
            verdict = "confirmed_corpus"
            is_hallucination = False
        elif in_corpus:
            rag_conf = 0.90 + (context_score * 0.10)
            verdict = "confirmed_corpus"
            is_hallucination = False
        elif in_lexicon:
            rag_conf = 0.85
            verdict = "confirmed_lexicon"
            is_hallucination = False
        else:
            # Termo não existe nem no corpus nem no léxico histórico
            rag_conf = 0.10
            verdict = "rejected_hallucination"
            is_hallucination = True

        result = RAGValidationResult(
            term=term,
            exists_in_corpus=in_corpus,
            corpus_occurrences_count=len(corpus_matches),
            exists_in_lexicon=in_lexicon,
            variant_detected=variant,
            context_cooccurrence_score=context_score,
            is_hallucination=is_hallucination,
            rag_confidence_score=rag_conf,
            evidence_samples=corpus_matches,
            verdict=verdict,
        )

        self._cache[clean_lower] = result
        return result

    def validate_page_tokens(
        self,
        tokens: list[str],
        window_size: int = 5,
    ) -> list[RAGValidationResult]:
        """Valida sequencialmente uma lista de tokens com janelas contextuais."""
        results = []
        for i, tok in enumerate(tokens):
            if not re.search(r"\w", tok) or len(tok.strip("'-")) <= 2:
                results.append(
                    RAGValidationResult(
                        term=tok,
                        exists_in_corpus=True,
                        rag_confidence_score=0.90,
                        verdict="confirmed_morphology",
                    )
                )
                continue

            # Extrair contexto ao redor
            start_w = max(0, i - window_size)
            end_w = min(len(tokens), i + window_size + 1)
            ctx = [tokens[j] for j in range(start_w, end_w) if j != i]

            res = self.validate_term(tok, context_words=ctx)
            results.append(res)

        return results
