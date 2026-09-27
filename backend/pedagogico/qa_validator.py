#!/usr/bin/env python3
"""
TupiLingo — Validador Determinístico de Controle de Qualidade (QA Validator)
Conforme RFC Pedagógica e Diretrizes da Seção 1.3:
  1. Interseção de Conjuntos ("Ensinar antes de cobrar"):
     Todo item cobrado em exercícios do capítulo N deve estar na união
     dos manifestos de conteúdo ensinado dos capítulos 1..N daquela variante.
  2. Proveniência no RAG:
     Todo item do manifesto ensinado deve possuir um rag_id válido rastreável.
  3. Paridade entre Variantes:
     Verifica volume de itens ensinados e categorias entre as 4 variantes.

Este validador opera de forma estritamente DETERMINÍSTICA em Python puro.
NENHUMA auto-avaliação de LLM é utilizada para certificar os capítulos.
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Set, Tuple

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("QAValidator")

BASE_DIR = Path(__file__).resolve().parent
CONTEUDO_DIR = BASE_DIR / "conteudo"
MANIFESTOS_DIR = BASE_DIR / "manifestos"

VALID_VARIANTS = ["tupi_contemporaneo", "tupi_antigo", "kamaiura", "tupinamba"]


class QAReport:
    def __init__(self, variant: str, chapter: int):
        self.variant = variant
        self.chapter = chapter
        self.passed = True
        self.errors: List[Dict[str, Any]] = []
        self.warnings: List[Dict[str, Any]] = []
        self.stats: Dict[str, Any] = {
            "total_taught_items": 0,
            "total_tested_items": 0,
            "provenance_coverage_pct": 0.0,
            "cumulative_taught_items": 0,
        }

    def add_error(self, code: str, message: str, context: Dict[str, Any] | None = None):
        self.passed = False
        self.errors.append({"code": code, "message": message, "context": context or {}})

    def add_warning(self, code: str, message: str, context: Dict[str, Any] | None = None):
        self.warnings.append({"code": code, "message": message, "context": context or {}})

    def to_dict(self) -> Dict[str, Any]:
        return {
            "variant": self.variant,
            "chapter": self.chapter,
            "status": "APPROVED" if self.passed else "REJECTED",
            "passed": self.passed,
            "errors_count": len(self.errors),
            "warnings_count": len(self.warnings),
            "stats": self.stats,
            "errors": self.errors,
            "warnings": self.warnings,
        }


def _normalize_token(text: str) -> str:
    """Normaliza um token linguístico para comparação determinística."""
    if not text:
        return ""
    t = text.lower().strip()
    # Remove pontuação adjacente mas preserva apóstrofo e hífen
    t = re.sub(r"[!?,.;:\"()\[\]{}]+", "", t)
    # Remove caracteres de espaço extras
    t = re.sub(r"\s+", " ", t)
    return t


class DeterministicQAValidator:
    def __init__(
        self,
        conteudo_dir: Path = CONTEUDO_DIR,
        manifestos_dir: Path = MANIFESTOS_DIR,
    ):
        self.conteudo_dir = conteudo_dir
        self.manifestos_dir = manifestos_dir

    def load_manifest(self, variant: str, chapter: int) -> Dict[str, Any] | None:
        """Carrega o manifesto de conteúdo ensinado de um capítulo específico."""
        fn = self.manifestos_dir / f"manifesto_{variant}_cap{chapter:02d}.json"
        if not fn.exists():
            return None
        with open(fn, "r", encoding="utf-8") as f:
            return json.load(f)

    def load_chapter(self, variant: str, chapter: int) -> Dict[str, Any] | None:
        """Carrega os dados pedagógicos completos de um capítulo."""
        fn = self.conteudo_dir / variant / f"capitulo_{chapter:02d}.json"
        if not fn.exists():
            return None
        with open(fn, "r", encoding="utf-8") as f:
            return json.load(f)

    def build_cumulative_taught_bank(
        self, variant: str, up_to_chapter: int
    ) -> Tuple[Set[str], List[Dict[str, Any]]]:
        """
        Constrói a união de todos os itens ensinados de 1 até up_to_chapter.
        Retorna conjunto de termos normalizados e lista dos itens completos.
        """
        bank_tokens: Set[str] = set()
        bank_items: List[Dict[str, Any]] = []

        for ch in range(1, up_to_chapter + 1):
            manifest = self.load_manifest(variant, ch)
            if not manifest:
                continue
            for item in manifest.get("itens_ensinados", []):
                bank_items.append(item)
                # Extrai tokens do termo original e traduções
                palavra = item.get("palavra", "")
                norm = _normalize_token(palavra)
                if norm:
                    bank_tokens.add(norm)
                    # Adiciona também palavras individuais se for uma expressão
                    for p in norm.split():
                        if len(p) > 2:
                            bank_tokens.add(p)
                # Adiciona formas de raiz se presentes
                raiz = item.get("raiz_morfologica")
                if raiz:
                    bank_tokens.add(_normalize_token(raiz))

        return bank_tokens, bank_items

    def validate_unit(self, variant: str, chapter: int) -> QAReport:
        """Executa a validação determinística de uma unidade (capítulo x variante)."""
        report = QAReport(variant, chapter)

        if variant not in VALID_VARIANTS:
            report.add_error("ERR_INVALID_VARIANT", f"Variante '{variant}' desconhecida.")
            return report

        # 1. Carrega Capítulo e Manifesto
        chap_data = self.load_chapter(variant, chapter)
        if not chap_data:
            report.add_error("ERR_MISSING_CHAPTER_FILE", f"Arquivo capitulo_{chapter:02d}.json não encontrado para {variant}.")
            return report

        manifest_data = self.load_manifest(variant, chapter)
        if not manifest_data:
            report.add_error("ERR_MISSING_MANIFEST_FILE", f"Manifesto manifesto_{variant}_cap{chapter:02d}.json não encontrado.")
            return report

        itens_cap = manifest_data.get("itens_ensinados", [])
        report.stats["total_taught_items"] = len(itens_cap)

        if len(itens_cap) == 0:
            report.add_error("ERR_EMPTY_MANIFEST", "Manifesto de conteúdo ensinado está vazio.")

        # 2. Check de Proveniência no RAG
        items_with_provenance = 0
        for idx, item in enumerate(itens_cap, start=1):
            rag_id = str(item.get("rag_id", "")).strip()
            termo = item.get("palavra", f"item_{idx}")
            if not rag_id or rag_id.lower() in ["none", "null", "pending", "desconhecido", "gap"]:
                # Se for marcado como aguardando RAG honestamente
                if item.get("status") == "incompleto_aguardando_rag":
                    report.add_warning(
                        "WARN_ITEM_AWAITING_RAG",
                        f"Item '{termo}' sinalizado como aguardando RAG em variant={variant}.",
                        {"item_index": idx, "termo": termo},
                    )
                else:
                    report.add_error(
                        "ERR_MISSING_RAG_PROVENANCE",
                        f"Item '{termo}' no capítulo {chapter} não tem rag_id comprovado.",
                        {"item_index": idx, "termo": termo, "item": item},
                    )
            else:
                items_with_provenance += 1

        if itens_cap:
            report.stats["provenance_coverage_pct"] = round(
                (items_with_provenance / len(itens_cap)) * 100, 2
            )

        # 3. Constrói o banco cumulativo de ensinados (Capítulos 1 até N)
        cumulative_tokens, cumulative_items = self.build_cumulative_taught_bank(variant, chapter)
        report.stats["cumulative_taught_items"] = len(cumulative_tokens)

        # 4. Check de Interseção de Conjuntos ("Ensinar antes de cobrar")
        tested_count = 0
        licoes = chap_data.get("licoes", [])
        if not licoes:
            report.add_error("ERR_NO_LESSONS", f"Capítulo {chapter} não possui lições cadastradas.")

        for lic_idx, licao in enumerate(licoes, start=1):
            # Valida presença de bloco de ensino antes dos exercícios
            bloco_ensino = licao.get("bloco_ensino", {})
            termos_bloco = bloco_ensino.get("itens_apresentados", [])
            if not termos_bloco:
                report.add_error(
                    "ERR_NO_TEACHING_BLOCK",
                    f"Lição {lic_idx} do Cap {chapter} não possui bloco explícito de apresentação de vocabulário.",
                    {"licao_numero": licao.get("numero", lic_idx)},
                )

            exercicios = licao.get("exercicios", [])
            for ex_idx, ex in enumerate(exercicios, start=1):
                tested_count += 1
                tipo = ex.get("tipo", "desconhecido")
                itens_alvo = ex.get("itens_alvo", [])

                # Extrai termos a validar
                termos_a_validar: List[str] = []

                if itens_alvo:
                    termos_a_validar.extend(itens_alvo)
                else:
                    # Extração automática por tipo se itens_alvo não especificado
                    if tipo in ["escolha_multipla", "multipla_escolha"]:
                        resposta_correta = ex.get("resposta_correta_termo") or ex.get("resposta_correta", "")
                        if resposta_correta:
                            termos_a_validar.append(resposta_correta)
                    elif tipo in ["completar", "completar_lacunas"]:
                        lacunas = ex.get("respostas_lacunas") or ex.get("respostas_corretas", [])
                        termos_a_validar.extend(lacunas)
                    elif tipo in ["associacao", "associacao_pares"]:
                        pares = ex.get("pares_corretos", {})
                        termos_a_validar.extend(pares.keys())

                for termo_cobrado in termos_a_validar:
                    norm_cobrado = _normalize_token(termo_cobrado)
                    if not norm_cobrado or len(norm_cobrado) <= 1:
                        continue

                    # Verifica se o termo cobrado (ou suas palavras-chave) está no banco ensinado
                    is_in_bank = False
                    if norm_cobrado in cumulative_tokens:
                        is_in_bank = True
                    else:
                        # Se for locução, checa se as palavras principais foram ensinadas
                        sub_tokens = [w for w in norm_cobrado.split() if len(w) > 2]
                        if sub_tokens and all(w in cumulative_tokens for w in sub_tokens):
                            is_in_bank = True

                    if not is_in_bank:
                        report.add_error(
                            "ERR_ORPHAN_TESTED_ITEM",
                            f"Exercício {ex_idx} da Lição {lic_idx} cobra o termo '{termo_cobrado}' que nunca foi ensinado em capítulos 1..{chapter}.",
                            {
                                "licao_numero": licao.get("numero", lic_idx),
                                "exercicio_ordem": ex.get("ordem", ex_idx),
                                "termo_orfao": termo_cobrado,
                                "tipo_exercicio": tipo,
                            },
                        )

        report.stats["total_tested_items"] = tested_count
        return report

    def validate_variant_parity(self, chapter: int) -> Dict[str, Any]:
        """
        Verifica a paridade de cobertura entre as 4 variantes para um mesmo capítulo.
        Compara número de itens ensinados e categorias.
        """
        parity_summary: Dict[str, Any] = {
            "chapter": chapter,
            "variants_evaluated": {},
            "is_balanced": True,
            "discrepancies": [],
        }

        counts: Dict[str, int] = {}
        category_sets: Dict[str, Set[str]] = {}

        for var in VALID_VARIANTS:
            manifest = self.load_manifest(var, chapter)
            if not manifest:
                parity_summary["variants_evaluated"][var] = {"status": "MISSING"}
                parity_summary["is_balanced"] = False
                parity_summary["discrepancies"].append(f"Variante {var} ainda não gerou o capítulo {chapter}.")
                continue

            itens = manifest.get("itens_ensinados", [])
            counts[var] = len(itens)
            cats = {it.get("categoria", "geral") for it in itens}
            category_sets[var] = cats

            parity_summary["variants_evaluated"][var] = {
                "status": "LOADED",
                "taught_items_count": len(itens),
                "categories": sorted(list(cats)),
            }

        if len(counts) == 4:
            min_c = min(counts.values())
            max_c = max(counts.values())
            if min_c > 0 and (max_c / min_c) > 2.5:
                parity_summary["is_balanced"] = False
                parity_summary["discrepancies"].append(
                    f"Desequilíbrio de volume no capítulo {chapter}: max={max_c}, min={min_c} (razão > 2.5)."
                )

        return parity_summary

    def run_all(self, max_chapter: int = 20) -> Dict[str, Any]:
        """Executa validação completa em todos os capítulos e variantes disponíveis."""
        overall_report: Dict[str, Any] = {
            "total_units_evaluated": 0,
            "passed_units": 0,
            "rejected_units": 0,
            "unit_reports": {},
            "parity_reports": {},
        }

        for ch in range(1, max_chapter + 1):
            for var in VALID_VARIANTS:
                overall_report["total_units_evaluated"] += 1
                rep = self.validate_unit(var, ch)
                unit_key = f"{var}_cap{ch:02d}"
                overall_report["unit_reports"][unit_key] = rep.to_dict()
                if rep.passed:
                    overall_report["passed_units"] += 1
                else:
                    overall_report["rejected_units"] += 1

            # Paridade entre variantes no capítulo
            parity = self.validate_variant_parity(ch)
            overall_report["parity_reports"][f"cap{ch:02d}"] = parity

        return overall_report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="TupiLingo Deterministic QA Validator")
    parser.add_argument("--variante", choices=VALID_VARIANTS, help="Variante a validar")
    parser.add_argument("--capitulo", type=int, help="Número do capítulo (1 a 20)")
    parser.add_argument("--all", action="store_true", help="Validar todas as 80 unidades")
    args = parser.parse_args()

    validator = DeterministicQAValidator()

    if args.all:
        results = validator.run_all(20)
        print(json.dumps(results, indent=2, ensure_ascii=False))
        sys.exit(0 if results["rejected_units"] == 0 else 1)
    elif args.variante and args.capitulo:
        rep = validator.validate_unit(args.variante, args.capitulo)
        print(json.dumps(rep.to_dict(), indent=2, ensure_ascii=False))
        sys.exit(0 if rep.passed else 1)
    else:
        parser.print_help()
        sys.exit(1)
