"""
Motor de Recuperação Aumentada por Geração (RAG) Fundamentado em Evidências — TupiLingo.
Prioridades de Recuperação:
1. Correspondência Exata de Grafia
2. Busca Normalizada (preservando grafia original)
3. Variantes Documentadas
4. Contexto Histórico/Documental de Navarro (2013)
5. Verificação de Sustentação & Declaração Mandatória de Incerteza
"""

from __future__ import annotations

import logging
from typing import Any, Dict, List, Optional, Tuple

from .models import (
    InformationTier,
    LexicalEntry,
    PhilologicalStatus,
    RAGResponseContract,
    normalize_tupi,
)
from .lexicon_repository import PhilologicalRepository, get_philological_repository

logger = logging.getLogger("pedagogico.filologia.rag")


class EvidenceGroundedRAG:
    """
    RAG Filológico com salvaguardas contra alucinações e promoção indevida de similaridade semântica.
    """

    def __init__(self, repository: Optional[PhilologicalRepository] = None):
        self.repository = repository or get_philological_repository()

    def query_lexicon(
        self,
        query: str,
        context_sentence: Optional[str] = None,
        pedagogical_intent: Optional[str] = None
    ) -> RAGResponseContract:
        """
        Executa a consulta lexical com prioridades estritas de recuperação e validação de tiers.
        """
        q_raw = query.strip()
        if not q_raw:
            return RAGResponseContract(
                query=query,
                afirmacao_produzida="Consulta vazia não produz afirmação documental.",
                verbete_sustentador_id=None,
                citacao_fonte=None,
                status_validacao=PhilologicalStatus.RETIRADO,
                information_tier=InformationTier.TIER_E_HIPOTESE_NAO_VERIFICADA,
                is_citacao_direta=False,
                limitacoes_e_ambiguidades=["Consulta nula ou vazia."],
                declarou_incerteza=True,
                metodo_recuperacao="EMPTY_QUERY",
                confianca_recuperacao=0.0,
            )

        # ── 1. CORRESPONDÊNCIA EXATA ──────────────────────────────────────────
        entry_exact = self.repository.lookup_exact(q_raw)
        if entry_exact:
            return self._build_response_from_entry(
                query=q_raw,
                entry=entry_exact,
                method="EXACT_LEMMA",
                confidence=1.0,
                is_exact=True
            )

        # ── 2. BUSCA NORMALIZADA (Sem apagar a grafia de origem) ──────────────
        entries_norm = self.repository.lookup_normalized(q_raw)
        if entries_norm:
            # Seleciona o melhor candidato e registra a diferença ortográfica
            best_entry = entries_norm[0]
            orthographic_note = (
                f"Forma de consulta '{q_raw}' normalizada para o lema documental '{best_entry.lema_original}'."
            )
            return self._build_response_from_entry(
                query=q_raw,
                entry=best_entry,
                method="NORMALIZED_LEMMA",
                confidence=0.95,
                is_exact=False,
                extra_notes=[orthographic_note]
            )

        # ── 3. VARIANTES DOCUMENTADAS ─────────────────────────────────────────
        entries_var = self.repository.lookup_variant(q_raw)
        if entries_var:
            best_entry = entries_var[0]
            variant_note = (
                f"Forma '{q_raw}' identificada como variante/remissão documentada de '{best_entry.lema_original}'."
            )
            return self._build_response_from_entry(
                query=q_raw,
                entry=best_entry,
                method="DOCUMENTED_VARIANT",
                confidence=0.90,
                is_exact=False,
                extra_notes=[variant_note]
            )

        # ── 4. TERMO NÃO DOCUMENTADO OU AMBÍGUO: DECLARAÇÃO MANDATÓRIA DE INCERTEZA ───
        # Conforme a regra inegociável da missão: "Quando a evidência for inexistente,
        # conflitante ou insuficiente, o RAG deve declarar a limitação em vez de inventar uma resposta."
        return RAGResponseContract(
            query=q_raw,
            afirmacao_produzida=(
                f"Não há registro documental para '{q_raw}' no Dicionário de Tupi Antigo de Eduardo Navarro (Ed. 2013). "
                "O sistema declara ausência de evidência e não realiza inferência conjectural."
            ),
            verbete_sustentador_id=None,
            citacao_fonte=None,
            status_validacao=PhilologicalStatus.QUARENTENA,
            information_tier=InformationTier.TIER_E_HIPOTESE_NAO_VERIFICADA,
            is_citacao_direta=False,
            limitacoes_e_ambiguidades=[
                f"Lema '{q_raw}' não consta no acervo canônico homologado.",
                "Similaridade semântica isolada não comprova equivalência lexical ou gramatical."
            ],
            declarou_incerteza=True,
            metodo_recuperacao="NO_EVIDENCE_DECLARED",
            confianca_recuperacao=0.0,
        )

    def _build_response_from_entry(
        self,
        query: str,
        entry: LexicalEntry,
        method: str,
        confidence: float,
        is_exact: bool,
        extra_notes: Optional[List[str]] = None
    ) -> RAGResponseContract:
        notes = extra_notes or []

        # Casos em Quarentena ou Retirados não podem ser promovidos a fato atestado
        if entry.status_publicacao in (PhilologicalStatus.QUARENTENA, PhilologicalStatus.RETIRADO):
            notes.append(
                f"Aviso de Integridade: O termo '{entry.lema_original}' encontra-se em {entry.status_publicacao.value.upper()} "
                "e não constitui evidência para gabaritos oficiais ou calibração psicométrica."
            )
            return RAGResponseContract(
                query=query,
                afirmacao_produzida=(
                    f"Entrada '{entry.lema_original}' classificada em {entry.status_publicacao.value}: "
                    f"{'; '.join(entry.significados)}. "
                    "Nota: Não atestada como Tupi Antigo canônico em Navarro (2013)."
                ),
                verbete_sustentador_id=entry.id,
                citacao_fonte=entry.fonte.citacao_canonica(),
                status_validacao=entry.status_publicacao,
                information_tier=InformationTier.TIER_E_HIPOTESE_NAO_VERIFICADA,
                is_citacao_direta=False,
                limitacoes_e_ambiguidades=notes,
                declarou_incerteza=True,
                metodo_recuperacao=method,
                confianca_recuperacao=0.40,
                contexto_recuperado=str(entry.morfologia)
            )

        # Casos aguardando revisão humana (extraídos automaticamente por OCR)
        if entry.status_publicacao == PhilologicalStatus.AGUARDANDO_REVISAO:
            notes.append(
                f"Aviso Filológico: O lema '{entry.lema_original}' foi extraído preliminarmente por OCR "
                f"(confiança {entry.ocr_evidence.confidence_score:.1f}%) e está AGUARDANDO REVISÃO HUMANA. "
                "Evidência documental não homologada para gabarito oficial."
            )
            tier = InformationTier.TIER_B_NORMALIZACAO_PESQUISA
            is_exact = False  # Não pode ser citação direta sem validação humana
        else:
            tier = InformationTier.TIER_A_TRANSCRICAO_LITERAL if is_exact else InformationTier.TIER_B_NORMALIZACAO_PESQUISA

        significados_str = "; ".join(entry.significados)
        afirmacao = f"{entry.lema_original} ({entry.classe_gramatical}): {significados_str}."

        if entry.exemplos_fonte:
            ex = entry.exemplos_fonte[0]
            afirmacao += f" Exemplo documental: '{ex.get('exemplo_tupi')}' ({ex.get('traducao_fonte')})."

        return RAGResponseContract(


            query=query,
            afirmacao_produzida=afirmacao,
            verbete_sustentador_id=entry.id,
            citacao_fonte=entry.fonte.citacao_canonica(),
            status_validacao=entry.status_publicacao,
            information_tier=tier,
            is_citacao_direta=is_exact,
            limitacoes_e_ambiguidades=notes,
            declarou_incerteza=False,
            metodo_recuperacao=method,
            confianca_recuperacao=confidence,
            contexto_recuperado=f"Página {entry.fonte.pagina or 'N/D'}, Verbete: {entry.fonte.verbete or entry.lema_original}"
        )


_global_rag_engine: Optional[EvidenceGroundedRAG] = None


def get_evidence_grounded_rag() -> EvidenceGroundedRAG:
    global _global_rag_engine
    if _global_rag_engine is None:
        _global_rag_engine = EvidenceGroundedRAG()
    return _global_rag_engine
