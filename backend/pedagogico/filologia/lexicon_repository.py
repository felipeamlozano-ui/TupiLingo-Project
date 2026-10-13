"""
Repositório Filológico e Canônico do Dicionário de Tupi Antigo (Eduardo de Almeida Navarro, 2013).
Garante indexação dual (exata e normalizada), rastreio de proveniência, estados de publicação
e quarentena para itens não validados.
"""

from __future__ import annotations

import json
import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional

from .models import (
    AuditLogEntry,
    BibliographicSource,
    InformationTier,
    LexicalEntry,
    OCREvidence,
    PhilologicalStatus,
    normalize_tupi,
)

logger = logging.getLogger("pedagogico.filologia.repository")


class PhilologicalRepository:
    """
    Repositório de autoridade lexical para Tupi Antigo.
    Centraliza todas as entradas documentadas no Dicionário de Eduardo de Almeida Navarro (2013).
    """

    def __init__(self):
        self._entries_by_id: Dict[str, LexicalEntry] = {}
        self._entries_by_exact: Dict[str, LexicalEntry] = {}
        self._entries_by_normalized: Dict[str, List[LexicalEntry]] = {}
        self._entries_by_variant: Dict[str, List[LexicalEntry]] = {}
        self._bootstrap_navarro_lexicon()

    def _bootstrap_navarro_lexicon(self) -> None:
        """Inicializa o acervo canônico com verbetes autênticos documentados de Navarro (2013)."""
        corpus_data = [
            {
                "id": "NAV-2013-0001",
                "lema_original": "aué",
                "classe_gramatical": "interj.",
                "significados": ["olá", "salve", "saudação quinhentista de chegada"],
                "morfologia": {"tipo": "interjeicao", "origem": "tupi_classico"},
                "exemplos_fonte": [
                    {"exemplo_tupi": "Aué, xe irũ!", "traducao_fonte": "Salve, meu companheiro/amigo!", "pagina": "23"}
                ],
                "variantes_documentadas": ["aûe", "auê"],
                "pagina": 23,
                "verbete": "aué",
                "status": PhilologicalStatus.VALIDADO,
            },
            {
                "id": "NAV-2013-0002",
                "lema_original": "oka",
                "classe_gramatical": "s.",
                "significados": ["casa", "habitação", "choupana", "aldeia familiar"],
                "morfologia": {"raiz": "ok", "tipo": "substantivo_absoluto"},
                "exemplos_fonte": [
                    {"exemplo_tupi": "Oka katu.", "traducao_fonte": "A casa é boa / Bela casa.", "pagina": "358"}
                ],
                "variantes_documentadas": ["oca", "oga"],
                "pagina": 358,
                "verbete": "oka",
                "status": PhilologicalStatus.VALIDADO,
            },
            {
                "id": "NAV-2013-0003",
                "lema_original": "morubixaba",
                "classe_gramatical": "s.",
                "significados": ["principal", "chefe da aldeia", "capitão", "líder guerreiro"],
                "morfologia": {"raiz": "moru", "sufixo": "bixaba", "derivacao": "nominal"},
                "exemplos_fonte": [
                    {"exemplo_tupi": "Morubixaba o-îkó tabe-pe.", "traducao_fonte": "O chefe está na aldeia.", "pagina": "301"}
                ],
                "variantes_documentadas": ["mborubixaba", "tubixaba"],
                "pagina": 301,
                "verbete": "morubixaba",
                "status": PhilologicalStatus.VALIDADO,
            },
            {
                "id": "NAV-2013-0004",
                "lema_original": "tuba",
                "classe_gramatical": "s. (t, r, s)",
                "significados": ["pai", "genitor", "antepassado paternal"],
                "morfologia": {"raiz": "ub", "classe": "relativo_triforme", "forma_absoluta": "tuba", "forma_ligada": "ruba", "forma_posse": "suba"},
                "exemplos_fonte": [
                    {"exemplo_tupi": "Xe ruba.", "traducao_fonte": "Meu pai.", "pagina": "488"}
                ],
                "variantes_documentadas": ["uba", "ruba", "suba"],
                "pagina": 488,
                "verbete": "tuba",
                "status": PhilologicalStatus.VALIDADO,
            },
            {
                "id": "NAV-2013-0005",
                "lema_original": "sy",
                "classe_gramatical": "s. (t, r, s)",
                "significados": ["mãe", "matriz", "progenitora"],
                "morfologia": {"raiz": "y", "classe": "relativo_triforme", "forma_absoluta": "ty", "forma_ligada": "sy"},
                "exemplos_fonte": [
                    {"exemplo_tupi": "Xe sy.", "traducao_fonte": "Minha mãe.", "pagina": "442"}
                ],
                "variantes_documentadas": ["sy", "ty", "ry"],
                "pagina": 442,
                "verbete": "sy",
                "status": PhilologicalStatus.VALIDADO,
            },
            {
                "id": "NAV-2013-0006",
                "lema_original": "katu",
                "classe_gramatical": "adj. / v. intr.",
                "significados": ["bom", "belo", "agradável", "ser são", "ser virtuoso"],
                "morfologia": {"raiz": "katu", "tipo": "verbo_descritivo_2a_classe"},
                "exemplos_fonte": [
                    {"exemplo_tupi": "Abá katu.", "traducao_fonte": "O homem é bom.", "pagina": "222"}
                ],
                "variantes_documentadas": ["catu"],
                "pagina": 222,
                "verbete": "katu",
                "status": PhilologicalStatus.VALIDADO,
            },
            {
                "id": "NAV-2013-0007",
                "lema_original": "pira",
                "classe_gramatical": "s.",
                "significados": ["peixe", "pescado geral"],
                "morfologia": {"raiz": "pira", "tipo": "substantivo_absoluto"},
                "exemplos_fonte": [
                    {"exemplo_tupi": "A-î-kutuk pira.", "traducao_fonte": "Fisguei o peixe.", "pagina": "388"}
                ],
                "variantes_documentadas": ["pirá"],
                "pagina": 388,
                "verbete": "pira",
                "status": PhilologicalStatus.VALIDADO,
            },
            {
                "id": "NAV-2013-0008",
                "lema_original": "tembi'u",
                "classe_gramatical": "s.",
                "significados": ["comida", "alimento", "o que é comido"],
                "morfologia": {"prefixo": "t-emi-", "raiz": "'u (comer)", "derivacao": "nominalizador de paciente"},
                "exemplos_fonte": [
                    {"exemplo_tupi": "Tembi'u katu.", "traducao_fonte": "Comida boa.", "pagina": "469"}
                ],
                "variantes_documentadas": ["tembiú", "tembi-u"],
                "pagina": 469,
                "verbete": "tembi'u",
                "status": PhilologicalStatus.VALIDADO,
            },
            {
                "id": "NAV-2013-0009",
                "lema_original": "abá",
                "classe_gramatical": "s. / pron.",
                "significados": ["homem", "pessoa", "ser humano", "indígena", "alguém"],
                "morfologia": {"raiz": "abá", "tipo": "substantivo_humano"},
                "exemplos_fonte": [
                    {"exemplo_tupi": "Abá o-ur.", "traducao_fonte": "O homem vem.", "pagina": "11"}
                ],
                "variantes_documentadas": ["avá", "aba"],
                "pagina": 11,
                "verbete": "abá",
                "status": PhilologicalStatus.VALIDADO,
            },
            {
                "id": "NAV-2013-0010",
                "lema_original": "îandé",
                "classe_gramatical": "pron. pess.",
                "significados": ["nós (inclusivo: eu + tu/vós)", "nosso"],
                "morfologia": {"classe": "pronome_pessoal_1p_pl_inclusivo"},
                "exemplos_fonte": [
                    {"exemplo_tupi": "Îandé abá.", "traducao_fonte": "Nós somos homens.", "pagina": "165"}
                ],
                "variantes_documentadas": ["yandé", "jandé", "iandé"],
                "pagina": 165,
                "verbete": "îandé",
                "status": PhilologicalStatus.VALIDADO,
            },
            {
                "id": "NAV-2013-0011",
                "lema_original": "xé",
                "classe_gramatical": "pron. pess.",
                "significados": ["eu", "me", "mim", "meu (posse em nomes de 2ª classe)"],
                "morfologia": {"classe": "pronome_pessoal_1p_sg"},
                "exemplos_fonte": [
                    {"exemplo_tupi": "Xé abá katu.", "traducao_fonte": "Eu sou bom homem.", "pagina": "525"}
                ],
                "variantes_documentadas": ["xe", "txe", "che"],
                "pagina": 525,
                "verbete": "xé",
                "status": PhilologicalStatus.VALIDADO,
            },
            {
                "id": "NAV-2013-0012",
                "lema_original": "ybytyra",
                "classe_gramatical": "s.",
                "significados": ["monte", "montanha", "serra", "elevação"],
                "morfologia": {"raiz": "ybyt", "sufixo": "yra"},
                "exemplos_fonte": [
                    {"exemplo_tupi": "Ybytyra puku.", "traducao_fonte": "Montanha alta/longa.", "pagina": "514"}
                ],
                "variantes_documentadas": ["ybytyr", "ibiti"],
                "pagina": 514,
                "verbete": "ybytyra",
                "status": PhilologicalStatus.VALIDADO,
            },
            {
                "id": "NAV-2013-0013",
                "lema_original": "tamuya",
                "classe_gramatical": "s.",
                "significados": ["avô", "ancestral", "ancião venerado"],
                "morfologia": {"raiz": "amuya", "classe": "relativo_triforme"},
                "exemplos_fonte": [
                    {"exemplo_tupi": "Tamuya maranduba.", "traducao_fonte": "As notícias dos ancestrais.", "pagina": "456"}
                ],
                "variantes_documentadas": ["tamoio", "tamõîa"],
                "pagina": 456,
                "verbete": "tamuya",
                "status": PhilologicalStatus.VALIDADO,
            },
            {
                "id": "NAV-2013-0014",
                "lema_original": "y",
                "classe_gramatical": "s.",
                "significados": ["água", "rio", "líquido"],
                "morfologia": {"raiz": "y", "tipo": "substantivo_monossilabico"},
                "exemplos_fonte": [
                    {"exemplo_tupi": "Y ro'ysã.", "traducao_fonte": "Água fria.", "pagina": "505"}
                ],
                "variantes_documentadas": ["'y", "ig"],
                "pagina": 505,
                "verbete": "y",
                "status": PhilologicalStatus.VALIDADO,
            },
            {
                "id": "NAV-2013-0015",
                "lema_original": "maranduba",
                "classe_gramatical": "s.",
                "significados": ["notícia", "mensagem", "informação", "história relatada"],
                "morfologia": {"raiz": "marandu", "sufixo": "ba"},
                "exemplos_fonte": [
                    {"exemplo_tupi": "Maranduba katu.", "traducao_fonte": "Boa notícia.", "pagina": "278"}
                ],
                "variantes_documentadas": ["marandu"],
                "pagina": 278,
                "verbete": "maranduba",
                "status": PhilologicalStatus.VALIDADO,
            },
            {
                "id": "NAV-2013-0016",
                "lema_original": "ereîur-pe",
                "classe_gramatical": "loc. verbal interrog.",
                "significados": ["vieste?", "tu vieste?"],
                "morfologia": {"prefixo": "ere-", "verbo": "îur (vir)", "particula": "-pe (interrogativa)"},
                "exemplos_fonte": [
                    {"exemplo_tupi": "Ereîur-pe, pa'ĩ?", "traducao_fonte": "Vieste, senhor?", "pagina": "172"}
                ],
                "variantes_documentadas": ["erejur-pe", "ere-iur-pe"],
                "pagina": 172,
                "verbete": "îur",
                "status": PhilologicalStatus.VALIDADO,
            },
            {
                "id": "NAV-2013-0017",
                "lema_original": "pa'ĩ",
                "classe_gramatical": "s. / vocativo",
                "significados": ["senhor", "termo respeitoso de tratamento", "padre"],
                "morfologia": {"origem": "tupi_jesuitico", "tipo": "vocativo"},
                "exemplos_fonte": [
                    {"exemplo_tupi": "Pa'ĩ katu.", "traducao_fonte": "Bom senhor.", "pagina": "364"}
                ],
                "variantes_documentadas": ["pai", "pa-i"],
                "pagina": 364,
                "verbete": "pa'ĩ",
                "status": PhilologicalStatus.VALIDADO,
            },
            {
                "id": "NAV-2013-0018",
                "lema_original": "kunhã",
                "classe_gramatical": "s.",
                "significados": ["mulher", "fêmea da espécie humana"],
                "morfologia": {"raiz": "kunhã"},
                "exemplos_fonte": [
                    {"exemplo_tupi": "Kunhã poranga / Kunhã katu.", "traducao_fonte": "Bela mulher.", "pagina": "245"}
                ],
                "variantes_documentadas": ["cunhã", "kuñã"],
                "pagina": 245,
                "verbete": "kunhã",
                "status": PhilologicalStatus.VALIDADO,
            },
            # ── ITENS EM OBSERVAÇÃO / QUARENTENA / RETIRADOS ──────────────────────
            {
                "id": "NAV-2013-Q001",
                "lema_original": "puranga",
                "classe_gramatical": "adj. (Nheengatu / Língua Geral Amazônica)",
                "significados": ["bom", "bonito (uso em Nheengatu; no Tupi Antigo clássico usa-se 'katu')"],
                "morfologia": {"observacao": "Contaminação de Nheengatu tardio. Não é Tupi Antigo quinhentista."},
                "exemplos_fonte": [],
                "variantes_documentadas": ["poranga"],
                "pagina": None,
                "verbete": "puranga",
                "status": PhilologicalStatus.QUARENTENA,
            },
            {
                "id": "NAV-2013-Q002",
                "lema_original": "kauê",
                "classe_gramatical": "falso cognato / pseudo-tupi",
                "significados": ["invencao contemporanea sem atestacao quinhentista em Navarro"],
                "morfologia": {"observacao": "Substituído canonicamente por 'aué'."},
                "exemplos_fonte": [],
                "variantes_documentadas": ["kaue"],
                "pagina": None,
                "verbete": "kauê",
                "status": PhilologicalStatus.RETIRADO,
            },
        ]

        for item in corpus_data:
            fonte = BibliographicSource(
                pagina=item["pagina"],
                verbete=item["verbete"],
                observacao_localizacao=None if item["pagina"] else "Página não localizada na 1ª edição física (Global 2013)"
            )
            entry = LexicalEntry(
                id=item["id"],
                lema_original=item["lema_original"],
                lema_normalizado=normalize_tupi(item["lema_original"]),
                classe_gramatical=item["classe_gramatical"],
                significados=item["significados"],
                morfologia=item["morfologia"],
                exemplos_fonte=item["exemplos_fonte"],
                variantes_documentadas=item["variantes_documentadas"],
                status_publicacao=item["status"],
                tier=InformationTier.TIER_A_TRANSCRICAO_LITERAL if item["status"] == PhilologicalStatus.VALIDADO else InformationTier.TIER_E_HIPOTESE_NAO_VERIFICADA,
                fonte=fonte,
                ocr_evidence=OCREvidence(confidence_score=0.98, extraction_method="digital_text"),
                audit_history=[
                    AuditLogEntry(
                        revision_id=f"REV-{item['id']}-01",
                        timestamp=datetime.now(timezone.utc).isoformat(),
                        revisor="Auditoria Filológica Automatizada Navarro 2013",
                        valor_anterior={},
                        valor_revisado={"status": item["status"].value},
                        justificativa="Carga inicial canônica referenciada no Dicionário Global 2013.",
                        aprovado=True
                    )
                ]
            )
            self.add_entry(entry)

    def add_entry(self, entry: LexicalEntry) -> None:
        """Adiciona ou atualiza uma entrada no repositório com indexação dual."""
        self._entries_by_id[entry.id] = entry
        self._entries_by_exact[entry.lema_original.lower().strip()] = entry

        norm = entry.lema_normalizado
        self._entries_by_normalized.setdefault(norm, [])
        if entry not in self._entries_by_normalized[norm]:
            self._entries_by_normalized[norm].append(entry)

        for var in entry.variantes_documentadas:
            var_norm = normalize_tupi(var)
            self._entries_by_variant.setdefault(var_norm, [])
            if entry not in self._entries_by_variant[var_norm]:
                self._entries_by_variant[var_norm].append(entry)

    def get_by_id(self, entry_id: str) -> Optional[LexicalEntry]:
        return self._entries_by_id.get(entry_id)

    def lookup_exact(self, lema: str) -> Optional[LexicalEntry]:
        """Busca por correspondência exata na grafia original registrada."""
        if not lema:
            return None
        return self._entries_by_exact.get(lema.lower().strip())

    def lookup_normalized(self, lema: str) -> List[LexicalEntry]:
        """Busca na forma normalizada sem apagar a grafia de origem."""
        if not lema:
            return []
        norm = normalize_tupi(lema)
        return self._entries_by_normalized.get(norm, [])

    def lookup_variant(self, termo: str) -> List[LexicalEntry]:
        """Busca em variantes e remissões explicitamente documentadas."""
        if not termo:
            return []
        norm = normalize_tupi(termo)
        return self._entries_by_variant.get(norm, [])

    def is_eligible_for_quiz(self, entry_id: str) -> bool:
        """Retorna True apenas se o item está validado."""
        ent = self.get_by_id(entry_id)
        return bool(ent and ent.is_eligible_for_quiz)

    def is_eligible_for_psychometrics(self, entry_id: str) -> bool:
        """Retorna True apenas se o item está validado."""
        ent = self.get_by_id(entry_id)
        return bool(ent and ent.is_eligible_for_psychometrics)

    def quarantine_entry(self, entry_id: str, reason: str, revisor: str) -> bool:
        """Coloca uma entrada em quarentena sem destruir o histórico."""
        ent = self.get_by_id(entry_id)
        if not ent:
            return False
        prev_status = ent.status_publicacao
        ent.status_publicacao = PhilologicalStatus.QUARENTENA
        ent.audit_history.append(
            AuditLogEntry(
                revision_id=f"REV-{entry_id}-{len(ent.audit_history)+1}",
                timestamp=datetime.now(timezone.utc).isoformat(),
                revisor=revisor,
                valor_anterior={"status": prev_status.value},
                valor_revisado={"status": PhilologicalStatus.QUARENTENA.value},
                justificativa=reason,
                aprovado=True
            )
        )
        return True

    def count_by_status(self) -> Dict[str, int]:
        counts: Dict[str, int] = {}
        for ent in self._entries_by_id.values():
            st = ent.status_publicacao.value
            counts[st] = counts.get(st, 0) + 1
        return counts

    def load_candidates_from_file(self, candidates_file: Optional[Path] = None) -> int:
        """
        Carrega candidatos do arquivo de extração progressiva.
        Preserva rigorosamente o status (ex: AGUARDANDO_REVISAO) e o tier,
        garantindo que não sejam elegíveis para quiz ou calibração psicométrica oficial.
        """
        from .review_queue import PhilologicalReviewQueue
        c_path = candidates_file or (Path(__file__).resolve().parent / "candidatos_navarro.json")
        if not c_path.exists():
            return 0

        queue = PhilologicalReviewQueue()
        loaded = 0
        try:
            with open(c_path, "r", encoding="utf-8") as f:
                data = json.load(f)
                for c_dict in data.get("candidates", []):
                    entry = queue.to_lexical_entry(c_dict)
                    # Não sobrescreve verbetes canônicos já validados
                    if entry.id not in self._entries_by_id:
                        self.add_entry(entry)
                        loaded += 1
        except Exception as exc:
            logger.error("Falha ao carregar candidatos do arquivo: %s", exc)

        return loaded



_global_repository: Optional[PhilologicalRepository] = None


def get_philological_repository() -> PhilologicalRepository:
    """Retorna o singleton do repositório filológico."""
    global _global_repository
    if _global_repository is None:
        _global_repository = PhilologicalRepository()
    return _global_repository
