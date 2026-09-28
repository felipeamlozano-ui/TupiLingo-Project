"""
Never Hallucinate Guard — RFC v6.1 Capítulo H
==============================================
Guarda arquivístico ultra-conservador:
- Impede terminantemente a invenção de palavras e substituições indevidas de:
  * Nomes próprios históricos (Camarão, Tibiriçá, Anchieta, Paraguaçu)
  * Numerais arábicos e romanos (Capítulo IV, 1595, 1645)
  * Topônimos (Pindorama, Piratininga, Guanabara, Itanhaém)
  * Etnônimos (Tupinambá, Potiguara, Temiminó, Caeté, Carijó)
  * Variantes indígenas morfológicas
- Marca tokens suspeitos ou ambíguos como 'UNCERTAIN'
- Garante que nenhum token 'UNCERTAIN' entre no banco de dados pedagógico.
"""

import logging
import re
from dataclasses import asdict, dataclass
from typing import Any, Dict, List, Optional, Set

logger = logging.getLogger("never_hallucinate_guard")


@dataclass
class TokenGuardDecision:
    token: str
    cleaned_token: str
    is_protected_invariant: bool
    invariant_type: Optional[str]  # NUMERAL | ROMAN | DATE | PROPER_NAME | TOPONYM | ETHNONYM
    is_uncertain: bool
    uncertainty_reason: Optional[str]
    allowed_for_pedagogical_db: bool


class NeverHallucinateGuard:
    """Salvaguarda rigorosa contra alucinações de transcrição e injeção espúria."""

    # Etnônimos históricos documentados
    ETHNONYMS = {
        "tupinamba", "tupinambá", "potiguara", "potyguara", "temimino", "temiminó",
        "caete", "caeté", "carijo", "carijó", "aimore", "aimoré", "tamoio", "tamoios",
        "goitaca", "goitacá", "tabajara", "tabajaras", "guarani", "kamaiura", "kamaiurá",
        "tupiniquim", "tupiniquins", "baniwa", "maue", "maué", "maues", "maués"
    }

    # Topônimos indígenas históricos
    TOPONYMS = {
        "pindorama", "piratininga", "guanabara", "itanhaem", "itanhaém", "bertioga",
        "urussanga", "itamaraca", "itamaracá", "paraiba", "paraíba", "potengi",
        "tietê", "tiete", "anhangabau", "anhangabaú", "maranhao", "maranhão", "araruama"
    }

    # Nomes próprios documentados em obras coloniais
    HISTORICAL_PROPER_NAMES = {
        "camarao", "camarão", "anchieta", "tibirica", "tibiriçá", "paraguacu", "paraguaçu",
        "cunhambebe", "morubixaba", "montoya", "navarro", "barbosa", "ayrosa", "figueira",
        "araujo", "maria", "jesuita", "jesuíta", "nobrega", "nóbrega"
    }

    # Regex para numerais arábicos, romanos e anos
    ROMAN_REGEX = re.compile(r"^[IVXLCDMivxlcdm]+$")
    NUMERIC_REGEX = re.compile(r"^\d+([,.]\d+)?$")
    YEAR_DATE_REGEX = re.compile(r"^(1[5-9]\d{2}|20\d{2})$")

    def __init__(self):
        self.uncertain_queue: List[TokenGuardDecision] = []

    def evaluate_token(
        self,
        raw_token: str,
        proposed_correction: Optional[str] = None,
        confidence: float = 1.0,
        consensus_sources_count: int = 0,
    ) -> TokenGuardDecision:
        """
        Avalia o token segundo as regras conservadoras do Capítulo H:
        - Se for número, data, nome próprio, topônimo ou etnônimo: PROIBIDO ALTERAR.
        - Se a confiança for baixa (<0.60) ou fonte única não confirmada: MARCAR UNCERTAIN.
        """
        clean_raw = raw_token.strip().strip(".,;:!?()[]\"'")
        clean_lower = clean_raw.lower()

        # 1. Checagem de Numerais e Datas
        if self.YEAR_DATE_REGEX.match(clean_raw):
            return TokenGuardDecision(
                token=raw_token,
                cleaned_token=raw_token,  # Preserva original intacto
                is_protected_invariant=True,
                invariant_type="DATE",
                is_uncertain=False,
                uncertainty_reason=None,
                allowed_for_pedagogical_db=True,
            )

        if self.NUMERIC_REGEX.match(clean_raw):
            return TokenGuardDecision(
                token=raw_token,
                cleaned_token=raw_token,
                is_protected_invariant=True,
                invariant_type="NUMERAL",
                is_uncertain=False,
                uncertainty_reason=None,
                allowed_for_pedagogical_db=True,
            )

        if self.ROMAN_REGEX.match(clean_raw) and len(clean_raw) <= 10:
            return TokenGuardDecision(
                token=raw_token,
                cleaned_token=raw_token,
                is_protected_invariant=True,
                invariant_type="ROMAN",
                is_uncertain=False,
                uncertainty_reason=None,
                allowed_for_pedagogical_db=True,
            )

        # 2. Checagem de Etnônimos
        if clean_lower in self.ETHNONYMS:
            return TokenGuardDecision(
                token=raw_token,
                cleaned_token=raw_token,
                is_protected_invariant=True,
                invariant_type="ETHNONYM",
                is_uncertain=False,
                uncertainty_reason=None,
                allowed_for_pedagogical_db=True,
            )

        # 3. Checagem de Topônimos
        if clean_lower in self.TOPONYMS:
            return TokenGuardDecision(
                token=raw_token,
                cleaned_token=raw_token,
                is_protected_invariant=True,
                invariant_type="TOPONYM",
                is_uncertain=False,
                uncertainty_reason=None,
                allowed_for_pedagogical_db=True,
            )

        # 4. Checagem de Nomes Próprios
        if clean_lower in self.HISTORICAL_PROPER_NAMES:
            return TokenGuardDecision(
                token=raw_token,
                cleaned_token=raw_token,
                is_protected_invariant=True,
                invariant_type="PROPER_NAME",
                is_uncertain=False,
                uncertainty_reason=None,
                allowed_for_pedagogical_db=True,
            )

        # 5. Avaliação de Confiança e Risco de Alucinação
        # Se um corretor automático tentar substituir um token mas a confiança for baixa:
        is_uncertain = False
        reason = None

        if confidence < 0.60:
            is_uncertain = True
            reason = f"Baixa confiança ({confidence*100:.1f}% < 60.0%)"
        elif proposed_correction and proposed_correction != raw_token and consensus_sources_count == 0:
            is_uncertain = True
            reason = "Substituição léxica sem evidência multi-fonte independente (Risco de Alucinação)"

        final_word = raw_token if is_uncertain else (proposed_correction or raw_token)

        decision = TokenGuardDecision(
            token=raw_token,
            cleaned_token=final_word,
            is_protected_invariant=False,
            invariant_type=None,
            is_uncertain=is_uncertain,
            uncertainty_reason=reason,
            allowed_for_pedagogical_db=not is_uncertain,
        )

        if is_uncertain:
            self.uncertain_queue.append(decision)

        return decision

    def filter_pedagogical_export(self, tokens: List[TokenGuardDecision]) -> List[TokenGuardDecision]:
        """
        Filtro estrito para o banco pedagógico (vector_store.db):
        Rejeita 100% dos tokens marcados como UNCERTAIN.
        """
        approved = [t for t in tokens if t.allowed_for_pedagogical_db]
        logger.info(f"Filtro Pedagógico: {len(approved)} aprovados de {len(tokens)} (rejeitados {len(tokens) - len(approved)} incertos).")
        return approved
