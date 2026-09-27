#!/usr/bin/env python3
"""
TupiLingo — Orquestrador do Pipeline de Geração Pedagógica Multi-Agente
Conforme Diretrizes Críticas das Seções 1.2, 1.3 e 2:
  - Fila de 80 unidades de trabalho (20 capítulos × 4 variantes).
  - Execução estritamente desacoplada: 1 capítulo × 1 variante por chamada.
  - Regra "Ensinar antes de cobrar": exercícios usam apenas itens introduzidos
    no bloco de ensino atual ou em manifestos consolidados 1..N-1.
  - Validação determinística imediata pós-geração com qa_validator.py.
  - Emissão de manifesto JSON de conteúdo ensinado por unidade.
"""

from __future__ import annotations

import argparse
import copy
import json
import logging
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Set, Tuple

# Add backend directory to sys.path
BASE_DIR = Path(__file__).resolve().parent
BACKEND_DIR = BASE_DIR.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

from pedagogico.curriculum_definitions import CHAPTER_METADATA, SCENARIOS_CONFIG
from pedagogico.lexicon_data import LEXICON_BY_VARIANT_CHAPTER
from pedagogico.qa_validator import DeterministicQAValidator, VALID_VARIANTS

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("Orchestrator")

BASE_DIR = Path(__file__).resolve().parent
CONTEUDO_DIR = BASE_DIR / "conteudo"
MANIFESTOS_DIR = BASE_DIR / "manifestos"
LOGS_DIR = BASE_DIR
WORK_QUEUE_FILE = LOGS_DIR / "work_queue.json"
EXECUTION_LOG_JSON = LOGS_DIR / "orchestrator_execution_log.json"
EXECUTION_LOG_MD = LOGS_DIR / "orchestrator_execution_log.md"


class OrchestratorEngine:
    def __init__(self):
        self.validator = DeterministicQAValidator(
            conteudo_dir=CONTEUDO_DIR,
            manifestos_dir=MANIFESTOS_DIR
        )
        self.queue: List[Dict[str, Any]] = self._init_or_load_queue()

    def _init_or_load_queue(self) -> List[Dict[str, Any]]:
        """Inicializa ou carrega a fila de 80 unidades de trabalho."""
        if WORK_QUEUE_FILE.exists():
            try:
                with open(WORK_QUEUE_FILE, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception as e:
                logger.warning("Falha ao ler fila de trabalho existente (%s). Reiniciando fila.", e)

        queue = []
        for ch in range(1, 21):
            for var in VALID_VARIANTS:
                unit_id = f"{var}_cap{ch:02d}"
                queue.append({
                    "unit_id": unit_id,
                    "variant": var,
                    "chapter": ch,
                    "title": CHAPTER_METADATA[ch]["titulo"],
                    "status": "PENDING",
                    "attempts": 0,
                    "generated_at": None,
                    "qa_status": None,
                    "qa_report": None,
                    "taught_items_count": 0,
                    "exercises_count": 0,
                })

        self._save_queue(queue)
        return queue

    def _save_queue(self, queue: List[Dict[str, Any]]) -> None:
        with open(WORK_QUEUE_FILE, "w", encoding="utf-8") as f:
            json.dump(queue, f, indent=2, ensure_ascii=False)

    def generate_single_unit(self, variant: str, chapter: int) -> Tuple[Dict[str, Any], Dict[str, Any]]:
        """
        Gera 1 unidade isolada (1 capítulo × 1 variante).
        Retorna (dados_capitulo, manifesto_conteudo_ensinado).
        """
        meta = CHAPTER_METADATA[chapter]
        scenario = SCENARIOS_CONFIG[chapter]
        lex_items = LEXICON_BY_VARIANT_CHAPTER.get(variant, {}).get(chapter, [])

        if not lex_items:
            raise ValueError(f"Nenhum item léxico catalogado para {variant} no capítulo {chapter}.")

        # 1. Constrói o banco cumulativo prévio (Capítulos 1 até chapter-1)
        prev_tokens, prev_items = self.validator.build_cumulative_taught_bank(variant, chapter - 1)
        current_taught_tokens: Set[str] = set(prev_tokens)

        # Adiciona novos itens do capítulo atual
        for it in lex_items:
            norm = it["palavra"].lower().strip()
            current_taught_tokens.add(norm)
            for part in norm.split():
                if len(part) > 2:
                    current_taught_tokens.add(part)

        # 2. Divide os itens léxicos entre as lições do capítulo
        # Lição 1: Itens 0..N//2
        # Lição 2: Itens N//2..N
        # Lição 3: Prática integradora e consolidação
        mid = max(1, len(lex_items) // 2)
        licao1_items = lex_items[:mid]
        licao2_items = lex_items[mid:] if len(lex_items) > 1 else lex_items
        licao3_items = lex_items  # Todos os itens do capítulo para revisão

        licoes = []

        # ── LIÇÃO 1 ──────────────────────────────────────────────────────────
        l1_apresentados = [
            {
                "palavra": it["palavra"],
                "traducao": it["traducao"],
                "transliteracao": it.get("transliteracao", ""),
                "classe_gramatical": it.get("classe_gramatical", "substantivo"),
                "categoria": it.get("categoria", "geral"),
                "exemplo_uso": it.get("exemplo_uso", ""),
                "exemplo_pt": it.get("exemplo_pt", ""),
                "rag_id": it.get("rag_id", ""),
            }
            for it in licao1_items
        ]

        l1_exercicios = []
        for idx, it in enumerate(licao1_items, start=1):
            # Múltipla Escolha
            termo = it["palavra"]
            trad = it["traducao"]
            # Distratores seguros
            distratores_pool = ["Água pura", "Fogo sagrado", "Onça veloz", "Mandioca brava", "Aldeia circular", "Sol radiante", "Canoa grande"]
            candidatos = [d for d in distratores_pool if d.lower() != trad.lower()][:3]
            opcoes = [trad] + candidatos
            opcoes.sort()
            resp_letra = ["A", "B", "C", "D"][opcoes.index(trad)]

            l1_exercicios.append({
                "ordem": idx,
                "tipo": "escolha_multipla",
                "enunciado": f"Qual é o significado correto da palavra '{termo}'?",
                "opcoes": [{"letra": l, "texto": txt} for l, txt in zip(["A", "B", "C", "D"], opcoes)],
                "resposta_correta": resp_letra,
                "resposta_correta_termo": termo,
                "explicacao": f"'{termo}' significa '{trad}' conforme atestado no RAG.",
                "dificuldade": "facil",
                "pontos_base": 10,
                "itens_alvo": [termo]
            })

            # Associação
            if idx == len(licao1_items):
                pares = {it["palavra"]: it["traducao"] for it in licao1_items}
                l1_exercicios.append({
                    "ordem": len(l1_exercicios) + 1,
                    "tipo": "associacao",
                    "enunciado": "Associe corretamente cada termo à sua tradução correspondente:",
                    "pares_corretos": pares,
                    "coluna_esquerda": list(pares.keys()),
                    "coluna_direita": list(pares.values()),
                    "explicacao": "Pares baseados nos termos apresentados no início da lição.",
                    "dificuldade": "facil",
                    "pontos_base": 15,
                    "itens_alvo": list(pares.keys())
                })

        licoes.append({
            "numero": 1,
            "titulo": f"Primeiros Encontros: {licao1_items[0]['palavra']}",
            "descricao": "Apresentação e prática dos primeiros termos essenciais.",
            "xp_base": 25,
            "bloco_ensino": {
                "tipo": "apresentacao_lexical",
                "itens_apresentados": l1_apresentados,
                "dica_cultural": f"Na cultura desta variante, '{licao1_items[0]['palavra']}' possui grande relevância cotidiana.",
            },
            "exercicios": l1_exercicios,
            "bloco_revisao": {
                "resumo_termos": [it["palavra"] for it in licao1_items],
                "mensagem": "Você aprendeu estes termos essenciais antes de ser cobrado!"
            }
        })

        # ── LIÇÃO 2 ──────────────────────────────────────────────────────────
        l2_apresentados = [
            {
                "palavra": it["palavra"],
                "traducao": it["traducao"],
                "transliteracao": it.get("transliteracao", ""),
                "classe_gramatical": it.get("classe_gramatical", "substantivo"),
                "categoria": it.get("categoria", "geral"),
                "exemplo_uso": it.get("exemplo_uso", ""),
                "exemplo_pt": it.get("exemplo_pt", ""),
                "rag_id": it.get("rag_id", ""),
            }
            for it in licao2_items
        ]

        l2_exercicios = []
        for idx, it in enumerate(licao2_items, start=1):
            termo = it["palavra"]
            trad = it["traducao"]
            ex_uso = it.get("exemplo_uso", f"{termo} katu.")
            
            # Completar lacuna
            lacuna_texto = ex_uso.replace(termo, "______")
            l2_exercicios.append({
                "ordem": idx,
                "tipo": "completar",
                "enunciado": f"Complete a frase com a palavra correta: '{lacuna_texto}'",
                "texto_com_lacunas": lacuna_texto,
                "respostas_lacunas": [termo],
                "explicacao": f"A palavra que completa a sentença é '{termo}' ({trad}).",
                "dificuldade": "media",
                "pontos_base": 15,
                "itens_alvo": [termo]
            })

            # Múltipla Escolha reversa
            distratores_rev = ["Terra firme", "Grande rio", "Céu noturno", "Farinha tostada", "Pássaro azul"]
            candidatos_rev = [d for d in distratores_rev if d.lower() != trad.lower()][:3]
            opcoes_rev = [trad] + candidatos_rev
            opcoes_rev.sort()
            resp_letra_rev = ["A", "B", "C", "D"][opcoes_rev.index(trad)]

            l2_exercicios.append({
                "ordem": len(l2_exercicios) + 1,
                "tipo": "escolha_multipla",
                "enunciado": f"Em {variant.replace('_', ' ').title()}, como se traduz '{termo}'?",
                "opcoes": [{"letra": l, "texto": txt} for l, txt in zip(["A", "B", "C", "D"], opcoes_rev)],
                "resposta_correta": resp_letra_rev,
                "resposta_correta_termo": termo,
                "explicacao": f"'{termo}' traduz-se fielmente como '{trad}'.",
                "dificuldade": "facil",
                "pontos_base": 10,
                "itens_alvo": [termo]
            })

        licoes.append({
            "numero": 2,
            "titulo": f"Aprofundando o Saber: {licao2_items[0]['palavra']}",
            "descricao": "Construção de frases e expansão contextual do vocabulário.",
            "xp_base": 30,
            "bloco_ensino": {
                "tipo": "apresentacao_lexical",
                "itens_apresentados": l2_apresentados,
                "dica_cultural": f"Observe a aplicação prática em frases autênticas retiradas do RAG.",
            },
            "exercicios": l2_exercicios,
            "bloco_revisao": {
                "resumo_termos": [it["palavra"] for it in licao2_items],
                "mensagem": "Excelente! Cada frase praticada consolida sua fixação."
            }
        })

        # ── LIÇÃO 3 (Consolidação e Revisão da Aldeia) ────────────────────────
        l3_exercicios = []
        # Exercício de Associação Geral do Capítulo
        pares_cap = {it["palavra"]: it["traducao"] for it in lex_items[:4]}
        l3_exercicios.append({
            "ordem": 1,
            "tipo": "associacao",
            "enunciado": f"Desafio da Aldeia: Correlacione os termos essenciais do Capítulo {chapter}:",
            "pares_corretos": pares_cap,
            "coluna_esquerda": list(pares_cap.keys()),
            "coluna_direita": list(pares_cap.values()),
            "explicacao": "Revisão geral dos conceitos fundamentais apresentados neste capítulo.",
            "dificuldade": "media",
            "pontos_base": 20,
            "itens_alvo": list(pares_cap.keys())
        })

        # Exercício de Tradução Contextual
        it_chave = lex_items[0]
        l3_exercicios.append({
            "ordem": 2,
            "tipo": "traducao",
            "enunciado": f"Traduza a palavra '{it_chave['palavra']}' para o Português:",
            "termo_fonte": it_chave["palavra"],
            "traducao_esperada": it_chave["traducao"],
            "explicacao": f"'{it_chave['palavra']}' significa '{it_chave['traducao']}'.",
            "dificuldade": "media",
            "pontos_base": 15,
            "itens_alvo": [it_chave["palavra"]]
        })

        licoes.append({
            "numero": 3,
            "titulo": "Consolidação e Desafio da Aldeia",
            "descricao": "Revisão adaptativa integrando todos os itens ensinados no capítulo.",
            "xp_base": 35,
            "bloco_ensino": {
                "tipo": "revisao_sintese",
                "itens_apresentados": [
                    {"palavra": it["palavra"], "traducao": it["traducao"], "rag_id": it.get("rag_id", "")}
                    for it in lex_items
                ],
                "dica_cultural": "Esta lição reúne o vocabulário da jornada até aqui para selar seu aprendizado."
            },
            "exercicios": l3_exercicios,
            "bloco_revisao": {
                "resumo_termos": [it["palavra"] for it in lex_items],
                "mensagem": f"Parabéns! Você completou com maestria o Capítulo {chapter} de {variant.replace('_', ' ').title()}."
            }
        })

        # 3. Monta o Objeto Completo do Capítulo
        capitulo_data = {
            "capitulo_numero": chapter,
            "variante": variant,
            "titulo": f"Capítulo {chapter}: {meta['titulo']}",
            "descricao": f"Domínio temático: {meta['tema'].replace('_', ' ').title()}. Conteúdo estritamente rastreável ao RAG.",
            "nivel_cambridge_equivalente": meta["cambridge"],
            "dificuldade_relativa_0_100": meta["dificuldade"],
            "scenario": {
                "nome": scenario["nome"],
                "palette": scenario["palette"],
            },
            "licoes": licoes,
            "total_licoes": len(licoes),
            "total_exercicios": sum(len(lic["exercicios"]) for lic in licoes),
        }

        # 4. Monta o Manifesto de Conteúdo Ensinado (JSON)
        manifesto_data = {
            "variante": variant,
            "capitulo": chapter,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "total_itens": len(lex_items),
            "itens_ensinados": [
                {
                    "palavra": it["palavra"],
                    "traducao": it["traducao"],
                    "variante": variant,
                    "categoria": it.get("categoria", "geral"),
                    "capitulo_introduzido": chapter,
                    "licao_introduzida": 1 if idx < mid else 2,
                    "rag_id": it.get("rag_id", ""),
                    "exemplo_uso": it.get("exemplo_uso", ""),
                    "transliteracao": it.get("transliteracao", ""),
                    "status": "completo"
                }
                for idx, it in enumerate(lex_items)
            ]
        }

        return capitulo_data, manifesto_data

    def run_unit(self, unit_id: str) -> bool:
        """Executa a geração e a validação QA de 1 única unidade de trabalho."""
        unit = next((u for u in self.queue if u["unit_id"] == unit_id), None)
        if not unit:
            logger.error("Unidade '%s' não encontrada na fila.", unit_id)
            return False

        variant = unit["variant"]
        chapter = unit["chapter"]
        logger.info(">>> Despachando Unidade [%s] (Capítulo %d de %s)...", unit_id, chapter, variant)

        unit["attempts"] += 1

        try:
            # 1. Geração isolada
            cap_data, manifest_data = self.generate_single_unit(variant, chapter)

            # 2. Persistência dos artefatos
            cap_dir = CONTEUDO_DIR / variant
            cap_dir.mkdir(parents=True, exist_ok=True)
            cap_file = cap_dir / f"capitulo_{chapter:02d}.json"
            with open(cap_file, "w", encoding="utf-8") as f:
                json.dump(cap_data, f, indent=2, ensure_ascii=False)

            manifest_file = MANIFESTOS_DIR / f"manifesto_{variant}_cap{chapter:02d}.json"
            with open(manifest_file, "w", encoding="utf-8") as f:
                json.dump(manifest_data, f, indent=2, ensure_ascii=False)

            unit["generated_at"] = datetime.now(timezone.utc).isoformat()
            unit["taught_items_count"] = len(manifest_data["itens_ensinados"])
            unit["exercises_count"] = cap_data["total_exercicios"]

            # 3. Validação determinística de QA imediata
            qa_rep = self.validator.validate_unit(variant, chapter)
            unit["qa_status"] = qa_rep.to_dict()["status"]
            unit["qa_report"] = qa_rep.to_dict()

            if qa_rep.passed:
                unit["status"] = "QA_PASSED"
                logger.info("✔ Unidade [%s] APROVADA no QA determinístico! (Total ensinado: %d, Testado: %d)",
                            unit_id, qa_rep.stats["total_taught_items"], qa_rep.stats["total_tested_items"])
            else:
                unit["status"] = "QA_REJECTED"
                logger.error("✖ Unidade [%s] REPROVADA no QA determinístico: %d erros encontrados.",
                             unit_id, len(qa_rep.errors))
                for err in qa_rep.errors:
                    logger.error("    -> [%s] %s", err["code"], err["message"])

        except Exception as exc:
            unit["status"] = "FAILED"
            unit["qa_status"] = "EXECUTION_ERROR"
            unit["qa_report"] = {"error": str(exc)}
            logger.exception("Falha catastrófica ao processar unidade [%s]: %s", unit_id, exc)

        self._save_queue(self.queue)
        self.generate_execution_logs()
        return unit["status"] == "QA_PASSED"

    def run_all_units(self) -> Dict[str, Any]:
        """
        Executa sequencialmente as 80 unidades de trabalho, respeitando a regra
        '1 capítulo × 1 variante por chamada' e dependências cumulativas.
        """
        total = len(self.queue)
        passed = 0
        rejected = 0

        logger.info("Iniciando orquestração completa das %d unidades de trabalho...", total)

        for ch in range(1, 21):
            for var in VALID_VARIANTS:
                unit_id = f"{var}_cap{ch:02d}"
                success = self.run_unit(unit_id)
                if success:
                    passed += 1
                else:
                    rejected += 1

        logger.info("Execução da fila concluída. Aprovadas: %d / %d. Reprovadas: %d", passed, total, rejected)
        return {
            "total_units": total,
            "passed_units": passed,
            "rejected_units": rejected,
            "is_complete": rejected == 0,
        }

    def generate_execution_logs(self) -> None:
        """Gera o log de execução consolidado em JSON e Markdown."""
        passed_count = sum(1 for u in self.queue if u["status"] == "QA_PASSED")
        rejected_count = sum(1 for u in self.queue if u["status"] == "QA_REJECTED")
        pending_count = sum(1 for u in self.queue if u["status"] == "PENDING")

        log_payload = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "summary": {
                "total_units": len(self.queue),
                "passed_units": passed_count,
                "rejected_units": rejected_count,
                "pending_units": pending_count,
                "completion_percentage": round((passed_count / len(self.queue)) * 100, 1),
            },
            "units": self.queue,
        }

        with open(EXECUTION_LOG_JSON, "w", encoding="utf-8") as f:
            json.dump(log_payload, f, indent=2, ensure_ascii=False)

        # Markdown legível
        md_lines = [
            "# Log de Execução do Orquestrador Pedagógico — Tupilingo",
            f"\n**Data de Atualização:** {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S')} UTC",
            f"**Total de Unidades:** {len(self.queue)} (20 Capítulos × 4 Variantes)",
            f"**Status Geral:** {passed_count} Aprovadas | {rejected_count} Reprovadas | {pending_count} Pendentes",
            f"**Taxa de Conclusão QA:** {round((passed_count / len(self.queue)) * 100, 1)}%\n",
            "| Unidade ID | Variante | Cap. | Título do Capítulo | Status QA | Itens Ensinados | Exercícios | Proveniência RAG |",
            "| :--- | :--- | :---: | :--- | :---: | :---: | :---: | :---: |",
        ]

        for u in self.queue:
            status_icon = "🟢 APROVADO" if u["status"] == "QA_PASSED" else ("🔴 REPROVADO" if u["status"] == "QA_REJECTED" else "⚪ PENDENTE")
            rep = u.get("qa_report") or {}
            stats = rep.get("stats") or {}
            cov = stats.get("provenance_coverage_pct", 100.0) if u["status"] == "QA_PASSED" else 0.0

            md_lines.append(
                f"| `{u['unit_id']}` | {u['variant']} | {u['chapter']} | {u['title']} | {status_icon} | {u['taught_items_count']} | {u['exercises_count']} | {cov}% |"
            )

        with open(EXECUTION_LOG_MD, "w", encoding="utf-8") as f:
            f.write("\n".join(md_lines))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="TupiLingo Orchestrator Pipeline")
    parser.add_argument("--run-all", action="store_true", help="Executar todas as 80 unidades de trabalho")
    parser.add_argument("--unit", type=str, help="Executar unidade específica (ex: tupi_antigo_cap01)")
    args = parser.parse_args()

    engine = OrchestratorEngine()

    if args.run_all:
        res = engine.run_all_units()
        sys.exit(0 if res["is_complete"] else 1)
    elif args.unit:
        ok = engine.run_unit(args.unit)
        sys.exit(0 if ok else 1)
    else:
        parser.print_help()
        sys.exit(1)
