"""
Suíte de Avaliação Adversarial Expandida do RAG Filológico — TupiLingo.
Conjunto de teste independente e versionado (N=30 casos) para auditoria rigorosa de:
1. Correspondência exata e fidelidade lexical.
2. Normalização sem perda de grafia documental.
3. Variantes documentadas vs. lemas de referência.
4. Pares mínimos e formas parecidas com distinção crítica.
5. Termos modernos e anacrônicos (Declaração Mandatória de Incerteza).
6. Pseudopalavras e construções morfológicas espúrias.
7. Dialetos modernos e Nheengatismos em Quarentena.
8. Tokens de OCR corrompido / páginas invertidas.
9. Candidatos extraídos pendentes de revisão humana (Bloqueio de Tier A).

Inclui cálculo de Intervalos de Confiança de Wilson (95%) para todas as taxas estimadas.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Tuple

from .models import InformationTier, PhilologicalStatus
from .rag_engine import EvidenceGroundedRAG, get_evidence_grounded_rag


def wilson_score_interval(successes: int, total: int, confidence: float = 0.95) -> Tuple[float, float]:
    """Calcula o Intervalo de Confiança de Wilson para uma proporção binomial."""
    if total <= 0:
        return (0.0, 0.0)
    # Valor crítico z para o nível de confiança especificado (default 1.96 para 95%)
    z = 1.95996 if abs(confidence - 0.95) < 0.01 else 1.64485
    p = successes / total
    z2 = z ** 2
    denom = 1.0 + z2 / total
    center = (p + z2 / (2.0 * total)) / denom
    half_width = (z * math.sqrt((p * (1.0 - p) + z2 / (4.0 * total)) / total)) / denom
    lower = max(0.0, center - half_width)
    upper = min(1.0, center + half_width)
    return (round(lower, 4), round(upper, 4))


@dataclass
class AdversarialTestCase:
    test_id: str
    categoria: str
    query: str
    lema_esperado: Optional[str]
    status_esperado: PhilologicalStatus
    deve_declarar_incerteza: bool
    permite_tier_a: bool
    descricao: str
    deve_bloquear_gabarito: bool = False


@dataclass
class AdversarialBenchmarkReport:
    total_casos: int
    acertos_recuperacao: int
    taxa_recuperacao_pct: float
    recuperacao_ci_95: Tuple[float, float]
    
    abstencoes_corretas: int
    total_sem_evidencia: int
    taxa_abstencao_correta_pct: float
    abstencao_ci_95: Tuple[float, float]
    
    afirmacoes_sem_sustentacao: int  # Alucinações
    taxa_alucinacao_pct: float
    alucinacao_ci_95: Tuple[float, float]
    
    vazamentos_nao_aprovados: int  # Candidatos não revisados promovidos a Tier A
    taxa_vazamento_pct: float
    
    fidelidade_estrita_acertos: int
    fidelidade_estrita_pct: float
    fidelidade_ci_95: Tuple[float, float]
    
    detalhes_testes: List[Dict[str, Any]] = field(default_factory=list)


class AdversarialRAGBenchmarkSuite:
    """Suíte adversarial de avaliação contínua do RAG com 30 casos de teste independentes."""

    DATASET: List[AdversarialTestCase] = [
        # ── 1. CORRESPONDÊNCIA EXATA (5 casos) ────────────────────────────────
        AdversarialTestCase(
            test_id="ADV-01-EXACT",
            categoria="correspondencia_exata",
            query="oka",
            lema_esperado="oka",
            status_esperado=PhilologicalStatus.VALIDADO,
            deve_declarar_incerteza=False,
            permite_tier_a=True,
            descricao="Lema 'oka' clássico (habitação/casa).",
        ),
        AdversarialTestCase(
            test_id="ADV-02-EXACT",
            categoria="correspondencia_exata",
            query="morubixaba",
            lema_esperado="morubixaba",
            status_esperado=PhilologicalStatus.VALIDADO,
            deve_declarar_incerteza=False,
            permite_tier_a=True,
            descricao="Lema 'morubixaba' (cacique/líder).",
        ),
        AdversarialTestCase(
            test_id="ADV-03-EXACT",
            categoria="correspondencia_exata",
            query="abá",
            lema_esperado="abá",
            status_esperado=PhilologicalStatus.VALIDADO,
            deve_declarar_incerteza=False,
            permite_tier_a=True,
            descricao="Lema 'abá' clássico (ser humano/homem tupi).",
        ),
        AdversarialTestCase(
            test_id="ADV-04-EXACT",
            categoria="correspondencia_exata",
            query="kunhã",
            lema_esperado="kunhã",
            status_esperado=PhilologicalStatus.VALIDADO,
            deve_declarar_incerteza=False,
            permite_tier_a=True,
            descricao="Lema 'kunhã' clássico (mulher).",
        ),
        AdversarialTestCase(
            test_id="ADV-05-EXACT",
            categoria="correspondencia_exata",
            query="tuba",
            lema_esperado="tuba",
            status_esperado=PhilologicalStatus.VALIDADO,
            deve_declarar_incerteza=False,
            permite_tier_a=True,
            descricao="Lema 'tuba' clássico (pai).",
        ),

        # ── 2. NORMALIZAÇÃO SEM PERDA DE GRAFIA (4 casos) ─────────────────────
        AdversarialTestCase(
            test_id="ADV-06-NORM",
            categoria="normalizacao",
            query="aue",
            lema_esperado="aué",
            status_esperado=PhilologicalStatus.VALIDADO,
            deve_declarar_incerteza=False,
            permite_tier_a=False,  # Normalização rebaixa para Tier B
            descricao="Busca sem acento 'aue' deve normalizar para 'aué'.",
        ),
        AdversarialTestCase(
            test_id="ADV-07-NORM",
            categoria="normalizacao",
            query="iande",
            lema_esperado="îandé",
            status_esperado=PhilologicalStatus.VALIDADO,
            deve_declarar_incerteza=False,
            permite_tier_a=False,
            descricao="Busca 'iande' deve normalizar para 'îandé' sem apagar grafia.",
        ),
        AdversarialTestCase(
            test_id="ADV-08-NORM",
            categoria="normalizacao",
            query="xe",
            lema_esperado="xé",
            status_esperado=PhilologicalStatus.VALIDADO,
            deve_declarar_incerteza=False,
            permite_tier_a=False,
            descricao="Busca sem acento 'xe' deve recuperar 'xé' (eu/meu).",
        ),
        AdversarialTestCase(
            test_id="ADV-09-NORM",
            categoria="normalizacao",
            query="tembiu",
            lema_esperado="tembi'u",
            status_esperado=PhilologicalStatus.VALIDADO,
            deve_declarar_incerteza=False,
            permite_tier_a=False,
            descricao="Busca sem apóstrofo 'tembiu' deve recuperar 'tembi\\'u' (comida).",
        ),

        # ── 3. VARIANTES DOCUMENTADAS (3 casos) ───────────────────────────────
        AdversarialTestCase(
            test_id="ADV-10-VAR",
            categoria="variantes_documentadas",
            query="ruba",
            lema_esperado="tuba",
            status_esperado=PhilologicalStatus.VALIDADO,
            deve_declarar_incerteza=False,
            permite_tier_a=False,
            descricao="Variante ligada 'ruba' remete ao verbete lematizado 'tuba'.",
        ),
        AdversarialTestCase(
            test_id="ADV-11-VAR",
            categoria="variantes_documentadas",
            query="suba",
            lema_esperado="tuba",
            status_esperado=PhilologicalStatus.VALIDADO,
            deve_declarar_incerteza=False,
            permite_tier_a=False,
            descricao="Forma relacional de 3ª pessoa 'suba' remete a 'tuba'.",
        ),
        AdversarialTestCase(
            test_id="ADV-12-VAR",
            categoria="variantes_documentadas",
            query="jandé",
            lema_esperado="îandé",
            status_esperado=PhilologicalStatus.VALIDADO,
            deve_declarar_incerteza=False,
            permite_tier_a=False,
            descricao="Variante ortográfica quinhentista 'jandé' remete a 'îandé'.",
        ),

        # ── 4. PARES MÍNIMOS E FORMAS PARECIDAS (4 casos) ─────────────────────
        AdversarialTestCase(
            test_id="ADV-13-MINIMAL",
            categoria="pares_minimos",
            query="y",
            lema_esperado="y",
            status_esperado=PhilologicalStatus.VALIDADO,
            deve_declarar_incerteza=False,
            permite_tier_a=True,
            descricao="Lema 'y' (água) não deve colidir com 'sy' (mãe) nem com 'î' (ele).",
        ),
        AdversarialTestCase(
            test_id="ADV-14-MINIMAL",
            categoria="pares_minimos",
            query="sy",
            lema_esperado="sy",
            status_esperado=PhilologicalStatus.VALIDADO,
            deve_declarar_incerteza=False,
            permite_tier_a=True,
            descricao="Lema 'sy' (mãe) deve se manter estritamente distinto de 'y'.",
        ),
        AdversarialTestCase(
            test_id="ADV-15-MINIMAL",
            categoria="pares_minimos",
            query="katu",
            lema_esperado="katu",
            status_esperado=PhilologicalStatus.VALIDADO,
            deve_declarar_incerteza=False,
            permite_tier_a=True,
            descricao="Lema 'katu' (bom/bem) deve se manter estritamente distinto de 'kauê'.",
        ),
        AdversarialTestCase(
            test_id="ADV-16-MINIMAL",
            categoria="pares_minimos",
            query="pira",
            lema_esperado="pira",
            status_esperado=PhilologicalStatus.VALIDADO,
            deve_declarar_incerteza=False,
            permite_tier_a=True,
            descricao="Lema 'pira' (peixe) deve se manter estritamente distinto de 'puranga'.",
        ),

        # ── 5. TERMOS MODERNOS E ANACRÔNICOS (5 casos) ────────────────────────
        AdversarialTestCase(
            test_id="ADV-17-MODERN",
            categoria="sem_evidencia_anacronico",
            query="computador",
            lema_esperado=None,
            status_esperado=PhilologicalStatus.QUARENTENA,
            deve_declarar_incerteza=True,
            permite_tier_a=False,
            descricao="Conceito contemporâneo sem atestação quinhentista: declarar incerteza.",
        ),
        AdversarialTestCase(
            test_id="ADV-18-MODERN",
            categoria="sem_evidencia_anacronico",
            query="aviao",
            lema_esperado=None,
            status_esperado=PhilologicalStatus.QUARENTENA,
            deve_declarar_incerteza=True,
            permite_tier_a=False,
            descricao="Neologismo contemporâneo: proibido inventar tradução.",
        ),
        AdversarialTestCase(
            test_id="ADV-19-MODERN",
            categoria="sem_evidencia_anacronico",
            query="televisao",
            lema_esperado=None,
            status_esperado=PhilologicalStatus.QUARENTENA,
            deve_declarar_incerteza=True,
            permite_tier_a=False,
            descricao="Conceito tecnológico inexistente na fonte de 2013.",
        ),
        AdversarialTestCase(
            test_id="ADV-20-MODERN",
            categoria="sem_evidencia_anacronico",
            query="blockchain",
            lema_esperado=None,
            status_esperado=PhilologicalStatus.QUARENTENA,
            deve_declarar_incerteza=True,
            permite_tier_a=False,
            descricao="Termo técnico recente: o RAG deve se abster com incerteza mandatória.",
        ),
        AdversarialTestCase(
            test_id="ADV-21-MODERN",
            categoria="sem_evidencia_anacronico",
            query="internet",
            lema_esperado=None,
            status_esperado=PhilologicalStatus.QUARENTENA,
            deve_declarar_incerteza=True,
            permite_tier_a=False,
            descricao="Tentativa de indução de resposta definitiva sobre tecnologia.",
        ),

        # ── 6. PSEUDOPALAVRAS E RUÍDO MORFOLÓGICO (3 casos) ───────────────────
        AdversarialTestCase(
            test_id="ADV-22-PSEUDO",
            categoria="pseudopalavra",
            query="xablau_inexistente",
            lema_esperado=None,
            status_esperado=PhilologicalStatus.QUARENTENA,
            deve_declarar_incerteza=True,
            permite_tier_a=False,
            descricao="Sequência fonética arbitrária: abstenção imediata.",
        ),
        AdversarialTestCase(
            test_id="ADV-23-PSEUDO",
            categoria="pseudopalavra",
            query="tupiniquim_cyber",
            lema_esperado=None,
            status_esperado=PhilologicalStatus.QUARENTENA,
            deve_declarar_incerteza=True,
            permite_tier_a=False,
            descricao="Construção espúria híbrida.",
        ),
        AdversarialTestCase(
            test_id="ADV-24-PSEUDO",
            categoria="pseudopalavra",
            query="itapuan_ficticio",
            lema_esperado=None,
            status_esperado=PhilologicalStatus.QUARENTENA,
            deve_declarar_incerteza=True,
            permite_tier_a=False,
            descricao="Topônimo inventado sem registro em Navarro.",
        ),

        # ── 7. DIALETOS MODERNOS E TERMOS EM QUARENTENA (3 casos) ─────────────
        AdversarialTestCase(
            test_id="ADV-25-QUARANTINE",
            categoria="quarentena_dialetal",
            query="puranga",
            lema_esperado="puranga",
            status_esperado=PhilologicalStatus.QUARENTENA,
            deve_declarar_incerteza=True,
            permite_tier_a=False,
            deve_bloquear_gabarito=True,
            descricao="Nheengatismo 'puranga' deve emitir alerta e proibir promoção a gabarito clássico.",
        ),
        AdversarialTestCase(
            test_id="ADV-26-QUARANTINE",
            categoria="quarentena_dialetal",
            query="kauê",
            lema_esperado="kauê",
            status_esperado=PhilologicalStatus.RETIRADO,
            deve_declarar_incerteza=True,
            permite_tier_a=False,
            deve_bloquear_gabarito=True,
            descricao="Pseudo-tupi expurgado: deve constar como retirado.",
        ),
        AdversarialTestCase(
            test_id="ADV-27-QUARANTINE",
            categoria="quarentena_dialetal",
            query="mborayhu",
            lema_esperado=None,
            status_esperado=PhilologicalStatus.QUARENTENA,
            deve_declarar_incerteza=True,
            permite_tier_a=False,
            deve_bloquear_gabarito=True,
            descricao="Termo exclusivo de Guarani Moderno (amor): não registrar como Tupi Antigo de Navarro.",
        ),

        # ── 8. TOKENS DE OCR CORROMPIDO / SCAN INVERTIDO (2 casos) ────────────
        AdversarialTestCase(
            test_id="ADV-28-OCR-CORRUPT",
            categoria="ocr_corrompido",
            query="(69 ‘1 ‘Q7A)",
            lema_esperado=None,
            status_esperado=PhilologicalStatus.QUARENTENA,
            deve_declarar_incerteza=True,
            permite_tier_a=False,
            descricao="Token de página invertida (VLB, I, 69 de cabeça para baixo): recusar categoricamente.",
        ),
        AdversarialTestCase(
            test_id="ADV-29-OCR-CORRUPT",
            categoria="ocr_corrompido",
            query="gweinsusD",
            lema_esperado=None,
            status_esperado=PhilologicalStatus.QUARENTENA,
            deve_declarar_incerteza=True,
            permite_tier_a=False,
            descricao="Fragmento tipográfico invertido em 180°: recusar sem alucinar lema.",
        ),

        # ── 9. CANDIDATOS NÃO HOMOLOGADOS EM AGUARDANDO REVISÃO (1 caso) ──────
        AdversarialTestCase(
            test_id="ADV-30-UNREVIEWED",
            categoria="candidato_nao_homologado",
            query="abanga",
            lema_esperado="abanga",
            status_esperado=PhilologicalStatus.AGUARDANDO_REVISAO,
            deve_declarar_incerteza=False,  # O RAG recupera com advertência de OCR
            permite_tier_a=False,  # PROIBIDO TIER A PARA NÃO HOMOLOGADO
            deve_bloquear_gabarito=True,
            descricao="Candidato OCR não revisado: deve conter nota de cautela e ser barrado de Tier A.",
        ),
    ]

    def __init__(self, rag_engine: Optional[EvidenceGroundedRAG] = None):
        self.rag_engine = rag_engine or get_evidence_grounded_rag()

    def run_adversarial_suite(self) -> AdversarialBenchmarkReport:
        total = len(self.DATASET)
        acertos_recup = 0
        abstencoes_corretas = 0
        total_sem_evidencia = 0
        afirm_nao_sust = 0
        vazamentos_tier_a = 0
        fidelidade_estrita = 0
        detalhes = []

        for tc in self.DATASET:
            resp = self.rag_engine.query_lexicon(tc.query)

            # 1. Avalia Recuperação
            if tc.lema_esperado is None:
                total_sem_evidencia += 1
                recup_ok = resp.metodo_recuperacao in ("NO_EVIDENCE_DECLARED", "EMPTY_QUERY")
                if resp.declarou_incerteza:
                    abstencoes_corretas += 1
                else:
                    afirm_nao_sust += 1
            else:
                ent = self.rag_engine.repository.get_by_id(resp.verbete_sustentador_id or "")
                recup_ok = (ent is not None and ent.lema_original == tc.lema_esperado)

            if recup_ok:
                acertos_recup += 1

            # 2. Avalia Vazamento de Candidato / Tier A
            vazou_tier_a = False
            if not tc.permite_tier_a and resp.information_tier == InformationTier.TIER_A_TRANSCRICAO_LITERAL:
                vazamentos_tier_a += 1
                vazou_tier_a = True

            # 3. Avalia Fidelidade Estrita
            status_ok = (resp.status_validacao == tc.status_esperado)
            incerteza_ok = (resp.declarou_incerteza == tc.deve_declarar_incerteza)
            tier_ok = (not vazou_tier_a)
            
            fiel = recup_ok and status_ok and incerteza_ok and tier_ok
            if fiel:
                fidelidade_estrita += 1

            detalhes.append({
                "test_id": tc.test_id,
                "categoria": tc.categoria,
                "query": tc.query,
                "recuperado_corretamente": recup_ok,
                "status_validacao": resp.status_validacao.value,
                "declarou_incerteza": resp.declarou_incerteza,
                "tier": resp.information_tier.value,
                "vazou_tier_a": vazou_tier_a,
                "fidelidade_estrita": fiel,
                "afirmacao": resp.afirmacao_produzida,
            })

        taxa_recup = round((acertos_recup / total) * 100, 2)
        ci_recup = wilson_score_interval(acertos_recup, total)

        taxa_abst = round((abstencoes_corretas / max(1, total_sem_evidencia)) * 100, 2)
        ci_abst = wilson_score_interval(abstencoes_corretas, max(1, total_sem_evidencia))

        taxa_aluc = round((afirm_nao_sust / total) * 100, 2)
        ci_aluc = wilson_score_interval(afirm_nao_sust, total)

        taxa_vaz = round((vazamentos_tier_a / total) * 100, 2)

        taxa_fiel = round((fidelidade_estrita / total) * 100, 2)
        ci_fiel = wilson_score_interval(fidelidade_estrita, total)

        return AdversarialBenchmarkReport(
            total_casos=total,
            acertos_recuperacao=acertos_recup,
            taxa_recuperacao_pct=taxa_recup,
            recuperacao_ci_95=ci_recup,
            abstencoes_corretas=abstencoes_corretas,
            total_sem_evidencia=total_sem_evidencia,
            taxa_abstencao_correta_pct=taxa_abst,
            abstencao_ci_95=ci_abst,
            afirmacoes_sem_sustentacao=afirm_nao_sust,
            taxa_alucinacao_pct=taxa_aluc,
            alucinacao_ci_95=ci_aluc,
            vazamentos_nao_aprovados=vazamentos_tier_a,
            taxa_vazamento_pct=taxa_vaz,
            fidelidade_estrita_acertos=fidelidade_estrita,
            fidelidade_estrita_pct=taxa_fiel,
            fidelidade_ci_95=ci_fiel,
            detalhes_testes=detalhes,
        )


if __name__ == "__main__":
    suite = AdversarialRAGBenchmarkSuite()
    # Assegura que o candidato 'aandira' esteja no repositório com status AGUARDANDO_REVISAO para o teste ADV-30
    repo = suite.rag_engine.repository
    repo.load_candidates_from_file()

    rep = suite.run_adversarial_suite()
    print("=" * 70)
    print("RELATÓRIO DO BENCHMARK ADVERSARIAL EXPANDIDO DO RAG (N=30)")
    print("=" * 70)
    print(f"Total de Casos Avaliados: {rep.total_casos}")
    print(f"Taxa de Recuperação: {rep.taxa_recuperacao_pct}% (IC 95%: [{rep.recuperacao_ci_95[0]*100:.1f}%, {rep.recuperacao_ci_95[1]*100:.1f}%])")
    print(f"Taxa de Abstenção Correta: {rep.taxa_abstencao_correta_pct}% (IC 95%: [{rep.abstencao_ci_95[0]*100:.1f}%, {rep.abstencao_ci_95[1]*100:.1f}%])")
    print(f"Taxa de Alucinação (Afirmações Não Sustentadas): {rep.taxa_alucinacao_pct}% (IC 95%: [{rep.alucinacao_ci_95[0]*100:.1f}%, {rep.alucinacao_ci_95[1]*100:.1f}%])")
    print(f"Vazamentos de Não Aprovados para Tier A: {rep.vazamentos_nao_aprovados} ({rep.taxa_vazamento_pct}%)")
    print(f"Fidelidade Estrita ao Modelo: {rep.fidelidade_estrita_pct}% (IC 95%: [{rep.fidelidade_ci_95[0]*100:.1f}%, {rep.fidelidade_ci_95[1]*100:.1f}%])")
    print("-" * 70)
    for d in rep.detalhes_testes:
        sym = "OK" if d["fidelidade_estrita"] else "FALHA"
        print(f"[{sym}] {d['test_id']} ({d['categoria']}): query='{d['query']}' | tier={d['tier']} | incerteza={d['declarou_incerteza']}")
    print("=" * 70)
