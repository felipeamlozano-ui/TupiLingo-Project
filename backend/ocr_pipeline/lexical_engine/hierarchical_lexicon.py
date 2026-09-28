"""
Hierarchical Lexicon Engine — Capítulo 23
Substitui corretores baseados em edição simples por uma validação estratificada em 4 níveis:
  - Nível 1: Frequência Documental em todo o acervo de PDFs
  - Nível 2: Fontes Históricas Homologadas (Ayrosa, Navarro, Anchieta, Barbosa, Lemos Barbosa, Nimuendajú, Montoya, Catecismos)
  - Nível 3: Variante Linguística (tupi_antigo, tupinamba, nheengatu, guarani_antigo, proto_tupi)
  - Nível 4: Análise Morfológica Fina (Prefixos, Sufixos, Partículas e Raízes)

Cada token avaliado recebe:
  - historical_probability: float
  - variant_probability: float
  - morphological_probability: float
  - lexicon_probability: float
"""
from __future__ import annotations

import logging
import re
from typing import Any, Optional
from pydantic import BaseModel, Field

logger = logging.getLogger("hierarchical_lexicon")


class HierarchicalTokenScore(BaseModel):
    token: str
    historical_probability: float  # Nível 2
    variant_probability: float     # Nível 3
    morphological_probability: float  # Nível 4
    lexicon_probability: float     # Probabilidade combinada (Nível 1-4)
    detected_variant: str = "tupi_antigo"
    sources_found: list[str] = Field(default_factory=list)
    document_frequency: int = 0


class HierarchicalLexiconEngine:
    """Motor de validação e correção léxica hierárquica em 4 níveis."""

    HISTORICAL_SOURCES = [
        "Ayrosa",
        "Navarro",
        "Anchieta",
        "Barbosa",
        "Lemos Barbosa",
        "Nimuendajú",
        "Montoya",
        "Catecismos Jesuíticos",
    ]

    LINGUISTIC_VARIANTS = [
        "tupi_antigo",
        "tupinamba",
        "nheengatu",
        "guarani_antigo",
        "proto_tupi",
    ]

    # Léxico histórico canônico com proveniência de fontes e variantes
    CANONICAL_CORPUS: dict[str, dict[str, Any]] = {
        "oka": {
            "sources": ["Navarro", "Anchieta", "Ayrosa", "Barbosa", "Montoya", "Catecismos Jesuíticos"],
            "variants": {"tupi_antigo": 0.95, "tupinamba": 0.95, "guarani_antigo": 0.90, "nheengatu": 0.85},
            "root": "ok",
            "pos": "substantivo",
            "meaning": "casa, habitação",
        },
        "morubixaba": {
            "sources": ["Anchieta", "Ayrosa", "Navarro", "Barbosa"],
            "variants": {"tupi_antigo": 0.95, "tupinamba": 0.90},
            "root": "morubixab",
            "pos": "substantivo",
            "meaning": "chefe, capitão",
        },
        "tuba": {
            "sources": ["Anchieta", "Barbosa", "Navarro", "Catecismos Jesuíticos", "Montoya"],
            "variants": {"tupi_antigo": 0.95, "tupinamba": 0.90, "guarani_antigo": 0.90},
            "root": "ub",
            "pos": "substantivo",
            "meaning": "pai",
        },
        "sy": {
            "sources": ["Anchieta", "Navarro", "Barbosa", "Montoya"],
            "variants": {"tupi_antigo": 0.95, "guarani_antigo": 0.90},
            "root": "sy",
            "pos": "substantivo",
            "meaning": "mãe",
        },
        "katu": {
            "sources": ["Anchieta", "Navarro", "Barbosa", "Nimuendajú", "Catecismos Jesuíticos"],
            "variants": {"tupi_antigo": 0.95, "tupinamba": 0.90, "nheengatu": 0.90},
            "root": "katu",
            "pos": "adjetivo/verbo",
            "meaning": "bom, belo",
        },
        "pira": {
            "sources": ["Ayrosa", "Navarro", "Barbosa", "Nimuendajú"],
            "variants": {"tupi_antigo": 0.95, "tupinamba": 0.95, "nheengatu": 0.90},
            "root": "pira",
            "pos": "substantivo",
            "meaning": "peixe",
        },
        "tatu": {
            "sources": ["Ayrosa", "Navarro", "Barbosa"],
            "variants": {"tupi_antigo": 0.95, "tupinamba": 0.95, "guarani_antigo": 0.90},
            "root": "tatu",
            "pos": "substantivo",
            "meaning": "tatu",
        },
        "aba": {
            "sources": ["Anchieta", "Navarro", "Barbosa", "Montoya", "Catecismos Jesuíticos"],
            "variants": {"tupi_antigo": 0.95, "tupinamba": 0.90, "guarani_antigo": 0.90},
            "root": "ab",
            "pos": "substantivo",
            "meaning": "homem, pessoa, índio",
        },
        "aoba": {
            "sources": ["Anchieta", "Navarro", "Barbosa"],
            "variants": {"tupi_antigo": 0.95, "tupinamba": 0.90},
            "root": "aob",
            "pos": "substantivo",
            "meaning": "roupa, vestimenta",
        },
        "itá": {
            "sources": ["Anchieta", "Navarro", "Barbosa", "Nimuendajú"],
            "variants": {"tupi_antigo": 0.95, "tupinamba": 0.90, "nheengatu": 0.90},
            "root": "itá",
            "pos": "substantivo",
            "meaning": "pedra, ferro, metal",
        },
    }

    # Afixos morfológicos canônicos (Anchieta / Barbosa)
    PREFIXES = ["xe", "nde", "i", "oré", "îandé", "pe", "o", "te", "t-", "s-", "r-", "mbo-", "mo-", "poro-"]
    SUFFIXES = ["-a", "-ba", "-ramo", "-me", "-pe", "-pupe", "-bo", "-rehe", "-katu", "-eté", "-rana", "-su"]

    def __init__(self, document_frequency_map: Optional[dict[str, int]] = None):
        self.doc_freqs = document_frequency_map or {}

    def evaluate_token(self, token: str) -> HierarchicalTokenScore:
        """Avalia um token nos 4 níveis estratificados."""
        clean = re.sub(r"[^\w'-]", "", token.lower())
        if not clean:
            return HierarchicalTokenScore(
                token=token,
                historical_probability=0.0,
                variant_probability=0.0,
                morphological_probability=0.0,
                lexicon_probability=0.0,
            )

        # Nível 1: Frequência Documental
        doc_freq = self.doc_freqs.get(clean, 0)
        # Normalização logarítmica de frequência
        freq_factor = min(1.0, (doc_freq + 1) / 10.0)

        # Nível 2: Fontes Históricas
        entry = self.CANONICAL_CORPUS.get(clean)
        sources_found: list[str] = []
        if entry:
            sources_found = entry["sources"]
            historical_prob = min(1.0, len(sources_found) / len(self.HISTORICAL_SOURCES))
        else:
            historical_prob = 0.0

        # Nível 3: Variante Linguística
        if entry and "variants" in entry:
            variant_scores = entry["variants"]
            best_variant, var_score = max(variant_scores.items(), key=lambda x: x[1])
            variant_prob = float(var_score)
            detected_variant = best_variant
        else:
            variant_prob = 0.50 if historical_prob > 0 else 0.10
            detected_variant = "tupi_antigo"

        # Nível 4: Morfologia
        morph_prob = 0.0
        if entry:
            morph_prob = 0.95
        else:
            # Tentar decomposição morfológica de prefixos e sufixos
            for pfx in self.PREFIXES:
                clean_pfx = pfx.replace("-", "")
                if clean.startswith(clean_pfx):
                    remainder = clean[len(clean_pfx):]
                    if remainder in self.CANONICAL_CORPUS:
                        morph_prob = 0.85
                        sources_found = self.CANONICAL_CORPUS[remainder]["sources"]
                        historical_prob = min(1.0, len(sources_found) / len(self.HISTORICAL_SOURCES))
                        break
            if morph_prob == 0.0:
                for sfx in self.SUFFIXES:
                    clean_sfx = sfx.replace("-", "")
                    if clean.endswith(clean_sfx):
                        stem = clean[:-len(clean_sfx)]
                        if stem in self.CANONICAL_CORPUS:
                            morph_prob = 0.85
                            sources_found = self.CANONICAL_CORPUS[stem]["sources"]
                            historical_prob = min(1.0, len(sources_found) / len(self.HISTORICAL_SOURCES))
                            break

        # Probabilidade Combinada do Léxico (Bayesiana ponderada dos 4 níveis)
        lexicon_prob = round(
            0.20 * freq_factor +
            0.35 * historical_prob +
            0.20 * variant_prob +
            0.25 * morph_prob,
            3,
        )

        return HierarchicalTokenScore(
            token=token,
            historical_probability=round(historical_prob, 3),
            variant_probability=round(variant_prob, 3),
            morphological_probability=round(morph_prob, 3),
            lexicon_probability=round(lexicon_prob, 3),
            detected_variant=detected_variant,
            sources_found=sources_found,
            document_frequency=doc_freq,
        )

    def evaluate_text(self, text: str) -> list[HierarchicalTokenScore]:
        """Avalia uma sequência de palavras token a token."""
        tokens = re.findall(r"\b[\w'-]+\b", text)
        return [self.evaluate_token(t) for t in tokens]
