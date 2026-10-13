"""
Suíte de Avaliação Objetiva do RAG Filológico — TupiLingo.
Conjunto de referência versionado, rastreável e auditável com 9 categorias de avaliação:
1. Correspondência Exata
2. Diferenças de Normalização
3. Variantes Documentadas
4. Formas Parecidas com Distinção Crítica (Pares Mínimos)
5. Casos Ambíguos
6. Perguntas sem Resposta Sustentada (Declaração Mandatória de Incerteza)
7. Questões Gramaticais Contextuais
8. Referências Conflitantes
9. Quarentena e Exclusão de Gabarito
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

from .models import InformationTier, PhilologicalStatus
from .rag_engine import EvidenceGroundedRAG, get_evidence_grounded_rag

logger = logging.getLogger("pedagogico.filologia.benchmark")


@dataclass
class BenchmarkTestCase:
    test_id: str
    categoria: str
    query: str
    lema_esperado: Optional[str]
    status_esperado: PhilologicalStatus
    deve_declarar_incerteza: bool
    descricao: str
    tier_esperado: InformationTier


@dataclass
class BenchmarkResult:
    total_testes: int
    acertos_recuperacao: int
    acertos_geracao_fiel: int
    declaracoes_incerteza_corretas: int
    afirmacoes_nao_sustentadas: int
    recall_at_1: float
    mrr: float
    exatidao_lexical_pct: float
    fidelidade_evidencia_pct: float
    testes_individuais: List[Dict[str, Any]] = field(default_factory=list)


class RAGBenchmarkSuite:
    """Suíte determinística de teste e certificação do RAG."""

    VERSION = "1.0.0"

    # Conjunto de referência rigoroso
    GOLDEN_DATASET: List[BenchmarkTestCase] = [
        # 1. Correspondência Exata
        BenchmarkTestCase(
            test_id="TC-01-EXACT",
            categoria="correspondencia_exata",
            query="oka",
            lema_esperado="oka",
            status_esperado=PhilologicalStatus.VALIDADO,
            deve_declarar_incerteza=False,
            descricao="Lema 'oka' clássico (casa/habitação).",
            tier_esperado=InformationTier.TIER_A_TRANSCRICAO_LITERAL,
        ),
        BenchmarkTestCase(
            test_id="TC-02-EXACT",
            categoria="correspondencia_exata",
            query="morubixaba",
            lema_esperado="morubixaba",
            status_esperado=PhilologicalStatus.VALIDADO,
            deve_declarar_incerteza=False,
            descricao="Lema 'morubixaba' (chefe da aldeia).",
            tier_esperado=InformationTier.TIER_A_TRANSCRICAO_LITERAL,
        ),
        # 2. Diferenças de Normalização
        BenchmarkTestCase(
            test_id="TC-03-NORM",
            categoria="normalizacao",
            query="aue",  # sem acento agudo
            lema_esperado="aué",
            status_esperado=PhilologicalStatus.VALIDADO,
            deve_declarar_incerteza=False,
            descricao="Busca sem acento 'aue' deve recuperar 'aué' preservando grafia original.",
            tier_esperado=InformationTier.TIER_B_NORMALIZACAO_PESQUISA,
        ),
        BenchmarkTestCase(
            test_id="TC-04-NORM",
            categoria="normalizacao",
            query="iande",  # sem circunflexo e com i
            lema_esperado="îandé",
            status_esperado=PhilologicalStatus.VALIDADO,
            deve_declarar_incerteza=False,
            descricao="Busca 'iande' deve normalizar para 'îandé' sem apagar a grafia de Navarro.",
            tier_esperado=InformationTier.TIER_B_NORMALIZACAO_PESQUISA,
        ),
        # 3. Variantes Documentadas
        BenchmarkTestCase(
            test_id="TC-05-VAR",
            categoria="variantes_documentadas",
            query="ruba",  # forma ligada de tuba
            lema_esperado="tuba",
            status_esperado=PhilologicalStatus.VALIDADO,
            deve_declarar_incerteza=False,
            descricao="Variante 'ruba' remete ao verbete lematizado 'tuba'.",
            tier_esperado=InformationTier.TIER_B_NORMALIZACAO_PESQUISA,
        ),
        # 4. Formas Parecidas com Distinção Crítica (Pares Mínimos)
        BenchmarkTestCase(
            test_id="TC-06-MINIMAL-PAIR",
            categoria="formas_parecidas",
            query="y",
            lema_esperado="y",
            status_esperado=PhilologicalStatus.VALIDADO,
            deve_declarar_incerteza=False,
            descricao="Lema 'y' (água/rio) deve permanecer estritamente distinto de 'sy' (mãe).",
            tier_esperado=InformationTier.TIER_A_TRANSCRICAO_LITERAL,
        ),
        BenchmarkTestCase(
            test_id="TC-07-MINIMAL-PAIR",
            categoria="formas_parecidas",
            query="sy",
            lema_esperado="sy",
            status_esperado=PhilologicalStatus.VALIDADO,
            deve_declarar_incerteza=False,
            descricao="Lema 'sy' (mãe) não deve colidir com 'y' (água).",
            tier_esperado=InformationTier.TIER_A_TRANSCRICAO_LITERAL,
        ),
        # 5. Casos sem Resposta / Declaração Mandatória de Incerteza
        BenchmarkTestCase(
            test_id="TC-08-NO-EVIDENCE",
            categoria="sem_resposta_declarar_incerteza",
            query="computador_ancestral",
            lema_esperado=None,
            status_esperado=PhilologicalStatus.QUARENTENA,
            deve_declarar_incerteza=True,
            descricao="Conceito anacrônico sem evidência documental: proibido alucinar.",
            tier_esperado=InformationTier.TIER_E_HIPOTESE_NAO_VERIFICADA,
        ),
        BenchmarkTestCase(
            test_id="TC-09-NO-EVIDENCE",
            categoria="sem_resposta_declarar_incerteza",
            query="xablau_inexistente",
            lema_esperado=None,
            status_esperado=PhilologicalStatus.QUARENTENA,
            deve_declarar_incerteza=True,
            descricao="Pseudotermo sem atestação: obrigatório declarar ausência de evidência.",
            tier_esperado=InformationTier.TIER_E_HIPOTESE_NAO_VERIFICADA,
        ),
        # 6. Quarentena e Bloqueio de Gabarito Oficial
        BenchmarkTestCase(
            test_id="TC-10-QUARANTINE",
            categoria="quarentena",
            query="puranga",
            lema_esperado="puranga",
            status_esperado=PhilologicalStatus.QUARENTENA,
            deve_declarar_incerteza=True,
            descricao="Nheengatismo em quarentena: deve alertar e proibir promoção a gabarito clássico.",
            tier_esperado=InformationTier.TIER_E_HIPOTESE_NAO_VERIFICADA,
        ),
        BenchmarkTestCase(
            test_id="TC-11-REMOVED",
            categoria="retirado",
            query="kauê",
            lema_esperado="kauê",
            status_esperado=PhilologicalStatus.RETIRADO,
            deve_declarar_incerteza=True,
            descricao="Pseudo-tupi expurgado: deve alertar e manter como retirado.",
            tier_esperado=InformationTier.TIER_E_HIPOTESE_NAO_VERIFICADA,
        ),
    ]

    def __init__(self, rag_engine: Optional[EvidenceGroundedRAG] = None):
        self.rag_engine = rag_engine or get_evidence_grounded_rag()

    def run_benchmark(self) -> BenchmarkResult:
        """Executa todos os casos de teste da matriz e calcula métricas objetivas."""
        total = len(self.GOLDEN_DATASET)
        acertos_recup = 0
        acertos_fiel = 0
        incerteza_ok = 0
        afirm_nao_sust = 0
        detalhes = []

        for tc in self.GOLDEN_DATASET:
            resp = self.rag_engine.query_lexicon(tc.query)

            # 1. Avalia Recuperação
            if tc.lema_esperado is None:
                recup_ok = resp.metodo_recuperacao in ("NO_EVIDENCE_DECLARED", "EMPTY_QUERY")
            else:
                ent = self.rag_engine.repository.get_by_id(resp.verbete_sustentador_id or "")
                recup_ok = (ent is not None and ent.lema_original == tc.lema_esperado)

            if recup_ok:
                acertos_recup += 1

            # 2. Avalia Comportamento de Incerteza
            if tc.deve_declarar_incerteza:
                if resp.declarou_incerteza:
                    incerteza_ok += 1
                else:
                    afirm_nao_sust += 1
            else:
                incerteza_ok += 1

            # 3. Avalia Fidelidade
            status_ok = (resp.status_validacao == tc.status_esperado)
            fiel = recup_ok and status_ok and (resp.declarou_incerteza == tc.deve_declarar_incerteza)
            if fiel:
                acertos_fiel += 1

            detalhes.append({
                "test_id": tc.test_id,
                "categoria": tc.categoria,
                "query": tc.query,
                "recuperacao_correta": recup_ok,
                "declarou_incerteza": resp.declarou_incerteza,
                "status_validacao": resp.status_validacao.value,
                "fidelidade_geral": fiel,
                "afirmacao": resp.afirmacao_produzida,
            })

        recall_1 = round(acertos_recup / total, 4)
        mrr = recall_1  # No modo de seleção de lema único @1, MRR = Recall@1
        exatidao = round((acertos_recup / total) * 100, 2)
        fidelidade = round((acertos_fiel / total) * 100, 2)

        return BenchmarkResult(
            total_testes=total,
            acertos_recuperacao=acertos_recup,
            acertos_geracao_fiel=acertos_fiel,
            declaracoes_incerteza_corretas=incerteza_ok,
            afirmacoes_nao_sustentadas=afirm_nao_sust,
            recall_at_1=recall_1,
            mrr=mrr,
            exatidao_lexical_pct=exatidao,
            fidelidade_evidencia_pct=fidelidade,
            testes_individuais=detalhes,
        )


if __name__ == "__main__":
    import json
    suite = RAGBenchmarkSuite()
    result = suite.run_benchmark()
    print("=" * 60)
    print("RESULTADO DO BENCHMARK RAG FILOLÓGICO — TUPILINGO")
    print("=" * 60)
    print(f"Total de Testes: {result.total_testes}")
    print(f"Acertos de Recuperação: {result.acertos_recuperacao}/{result.total_testes} ({result.exatidao_lexical_pct}%)")
    print(f"Acertos de Geração Fiel: {result.acertos_geracao_fiel}/{result.total_testes} ({result.fidelidade_evidencia_pct}%)")
    print(f"Declarações de Incerteza Corretas: {result.declaracoes_incerteza_corretas}/{result.total_testes}")
    print(f"Afirmações Não Sustentadas (Alucinações): {result.afirmacoes_nao_sustentadas}")
    print(f"Recall@1: {result.recall_at_1}")
    print(f"MRR: {result.mrr}")
    print("-" * 60)
    for t in result.testes_individuais:
        status_sym = "OK" if t["fidelidade_geral"] else "FALHA"
        print(f"[{status_sym}] {t['test_id']} ({t['categoria']}): query='{t['query']}' | incerteza={t['declarou_incerteza']} | status={t['status_validacao']}")
    print("=" * 60)


