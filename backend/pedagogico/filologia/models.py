"""
Modelos de Dados Filológicos e Contratos de Integridade — TupiLingo.
Fundamentado em:
Navarro, Eduardo de Almeida. Dicionário de Tupi Antigo: a língua indígena clássica do Brasil.
1ª Edição, Global Editora, São Paulo, 2013.
"""

from __future__ import annotations

import unicodedata
from dataclasses import asdict, dataclass, field
from enum import Enum
from typing import Any, Dict, List, Optional


class PhilologicalStatus(str, Enum):
    """Estados de ciclo de vida e publicação filológica."""
    RASCUNHO = "rascunho"
    AGUARDANDO_REVISAO = "aguardando_revisao"
    VALIDADO = "validado"
    QUARENTENA = "quarentena"
    RETIRADO = "retirado"


class InformationTier(str, Enum):
    """
    Estratificação estrita de informação para evitar confusão entre
    transcrição de Navarro, interpretação validada e hipótese.
    """
    TIER_A_TRANSCRICAO_LITERAL = "tier_a_transcricao_literal"       # Transcrito diretamente da fonte documental
    TIER_B_NORMALIZACAO_PESQUISA = "tier_b_normalizacao_pesquisa"   # Normalizado para pesquisa computacional
    TIER_C_INTERPRETACAO_VALIDADA = "tier_c_interpretacao_validada" # Interpretação linguística confirmada por especialista
    TIER_D_EXPLICACAO_PEDAGOGICA = "tier_d_explicacao_pedagogica"   # Explicação didática derivada para o estudante
    TIER_E_HIPOTESE_NAO_VERIFICADA = "tier_e_hipotese_nao_verificada" # Hipótese, inferência de LLM ou dado incerto


@dataclass
class BibliographicSource:
    """Metadados bibliográficos precisos da obra de autoridade."""
    obra: str = "Dicionário de Tupi Antigo: a língua indígena clássica do Brasil"
    autor: str = "Eduardo de Almeida Navarro"
    edicao: str = "1ª Edição"
    ano: int = 2013
    editora: str = "Global Editora"
    local: str = "São Paulo"
    pagina: Optional[int] = None  # Mantido para retrocompatibilidade
    pagina_impressa: Optional[int] = None
    pagina_digital: Optional[int] = None
    verbete: Optional[str] = None
    hash_documento: str = "87c9662bc45de33bf5f5592c24f249d4ac86ed3fe568d99bcff11f96ad131671"
    arquivo_fonte: str = "Dicionário Tupi.pdf"
    isbn: Optional[str] = "978-85-260-1933-1"
    observacao_localizacao: Optional[str] = None
    extrator_versao: str = "1.0.0-canonical"
    bbox: Optional[Dict[str, float]] = None

    def __post_init__(self):
        # Sincroniza pagina e pagina_impressa para compatibilidade bidirecional
        if self.pagina_impressa is None and self.pagina is not None:
            self.pagina_impressa = self.pagina
        elif self.pagina is None and self.pagina_impressa is not None:
            self.pagina = self.pagina_impressa

    def citacao_canonica(self) -> str:
        loc = []
        pag = self.pagina_impressa or self.pagina
        if pag is not None:
            loc.append(f"p. {pag}")
        if self.pagina_digital is not None:
            loc.append(f"folha digital {self.pagina_digital}")
        if self.verbete:
            loc.append(f"verbete '{self.verbete}'")
        loc_str = f", {', '.join(loc)}" if loc else ""
        return f"NAVARRO, Eduardo de Almeida. {self.obra}. {self.edicao}. {self.local}: {self.editora}, {self.ano}{loc_str}."


@dataclass
class OCREvidence:
    """Evidência física da extração OCR."""
    confidence_score: float
    extraction_method: str = "ocr"
    requires_human_review: bool = False
    scan_quality_notes: Optional[str] = None
    raw_tokens: List[str] = field(default_factory=list)
    is_orientation_corrected: bool = False
    suspicious_characters: List[str] = field(default_factory=list)



@dataclass
class AuditLogEntry:
    """Registro histórico imutável de revisão filológica."""
    revision_id: str
    timestamp: str
    revisor: str
    valor_anterior: Dict[str, Any]
    valor_revisado: Dict[str, Any]
    justificativa: str
    aprovado: bool


@dataclass
class LexicalEntry:
    """Entrada lexical canônica do Tupi Antigo."""
    id: str
    lema_original: str
    lema_normalizado: str
    classe_gramatical: str
    significados: List[str]
    morfologia: Dict[str, Any] = field(default_factory=dict)
    exemplos_fonte: List[Dict[str, str]] = field(default_factory=list)
    variantes_documentadas: List[str] = field(default_factory=list)
    status_publicacao: PhilologicalStatus = PhilologicalStatus.VALIDADO
    tier: InformationTier = InformationTier.TIER_A_TRANSCRICAO_LITERAL
    fonte: BibliographicSource = field(default_factory=BibliographicSource)
    ocr_evidence: OCREvidence = field(default_factory=lambda: OCREvidence(confidence_score=1.0))
    audit_history: List[AuditLogEntry] = field(default_factory=list)
    revisao_responsavel: Optional[str] = "Eduardo de Almeida Navarro (Ed. 2013)"
    versao_publicada: str = "1.0.0"

    @property
    def is_eligible_for_quiz(self) -> bool:
        """Apenas verbetes validados podem alimentar gabaritos oficiais."""
        return self.status_publicacao == PhilologicalStatus.VALIDADO

    @property
    def is_eligible_for_psychometrics(self) -> bool:
        """Apenas itens sustentados por verbetes validados contam para calibração psicométrica normal."""
        return self.status_publicacao == PhilologicalStatus.VALIDADO

    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class RAGResponseContract:
    """
    Contrato estrito de resposta fundamentada em evidências.
    Garante rastreabilidade, identificação de Tier e declaração explícita de incerteza.
    """
    query: str
    afirmacao_produzida: str
    verbete_sustentador_id: Optional[str]
    citacao_fonte: Optional[str]
    status_validacao: PhilologicalStatus
    information_tier: InformationTier
    is_citacao_direta: bool
    limitacoes_e_ambiguidades: List[str]
    declarou_incerteza: bool
    metodo_recuperacao: str
    confianca_recuperacao: float
    contexto_recuperado: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        res = asdict(self)
        res["status_validacao"] = self.status_validacao.value
        res["information_tier"] = self.information_tier.value
        return res


def normalize_tupi(text: str) -> str:
    """
    Normaliza a grafia de Tupi Antigo para pesquisa computacional,
    sem apagar a forma original preservada no lema:
    - Lowercase e strip.
    - Remove marcas diacríticas combinantes mantendo as consoantes oclusivas/glotais ('/î/ŷ).
    - Mapeia variantes gráficas padronizadas por Navarro (ex.: î -> i, ŷ -> y para índice flexível).
    """
    if not text:
        return ""
    t = text.strip().lower()
    t = t.replace("î", "i").replace("ŷ", "y").replace("'", "").replace("’", "")
    nfkd = unicodedata.normalize("NFD", t)
    return "".join(c for c in nfkd if unicodedata.category(c) != "Mn")
