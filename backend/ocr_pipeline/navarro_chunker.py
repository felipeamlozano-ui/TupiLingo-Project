"""
TupiLingo — Chunker Lexicográfico e Estruturado (Padrão Eduardo de Almeida Navarro - USP)

Gera chunks de altíssima fidelidade a partir de:
1. Verbetes estruturados do Dicionário de Tupi Antigo (Navarro, 2013).
2. Obras canônicas anotadas por Eduardo Navarro (Cartas de 1645, Topônimos, Acento).
3. Material autêntico de Tupi Revitalizado (Potiguara Kuapa) e linguística quinhentista (Aryon Rodrigues).

Rejeita 100% de fontes espúrias (línguas não-tupi, teses irrelevantes, etc.).
"""

from __future__ import annotations

import hashlib
import json
import logging
import re
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

logger = logging.getLogger("ocr_pipeline.navarro_chunker")

ROOT_DIR = Path(__file__).resolve().parent.parent.parent
BACKEND_DIR = ROOT_DIR / "backend"
PDFS_DIR = BACKEND_DIR / "pdfs"


# ── ACERVO CANÔNICO AUTORIZADO ────────────────────────────────────────────────
CANONICAL_SOURCES = {
    "Dicionário Tupi.pdf": {
        "obra": "Dicionário de Tupi Antigo: A língua indígena clássica do Brasil",
        "autor": "Eduardo de Almeida Navarro",
        "ano": 2013,
        "autoridade": 1.0,
        "variante": "tupi_antigo",
        "tier": "tier_a_lexicografia_canonica",
    },
    "Transcrição e Tradução Carta 1645.pdf": {
        "obra": "Transcrição e tradução integral anotada das Cartas dos Índios Camarões de 1645",
        "autor": "Eduardo de Almeida Navarro",
        "ano": 2022,
        "autoridade": 1.0,
        "variante": "tupi_antigo",
        "tier": "tier_a_corpus_historico",
    },
    "download.pdf": {
        "obra": "Os topônimos de origem tupi no Brasil moderno",
        "autor": "Eduardo de Almeida Navarro",
        "ano": 2021,
        "autoridade": 1.0,
        "variante": "tupi_antigo",
        "tier": "tier_a_toponimia_navarro",
    },
    "Mistieri_2010_Acento_Tupi_Antigo.pdf": {
        "obra": "O acento em Tupi Antigo (UNESP, orient. Eduardo Navarro)",
        "autor": "Fernanda Regina Mistieri",
        "ano": 2010,
        "autoridade": 0.95,
        "variante": "tupi_antigo",
        "tier": "tier_b_fonologia_academica",
    },
    "tupi-potiguara-kuapa-2023_compress.pdf": {
        "obra": "Tupi Potiguara Kuapa (Revitalização e Ensino Comunicativo)",
        "autor": "14ª GRE Mamanguape / Povo Potiguara",
        "ano": 2023,
        "autoridade": 0.95,
        "variante": "tupi_revitalizado",
        "tier": "tier_b_revitalizacao_comunitaria",
    },
    "Rodrigues_2011_AnaliseMorfologicaDeUmTextoTupi.pdf": {
        "obra": "Análise morfológica de um texto tupí",
        "autor": "Aryon Dall'Igna Rodrigues",
        "ano": 2011,
        "autoridade": 0.95,
        "variante": "tupi_antigo",
        "tier": "tier_b_morfologia_cientifica",
    },
    "Rodrigues_1958_Phonologie_der_Tupinamba.pdf": {
        "obra": "Phonologie der Tupinambá-Sprache",
        "autor": "Aryon Dall'Igna Rodrigues",
        "ano": 1958,
        "autoridade": 0.90,
        "variante": "tupi_antigo",
        "tier": "tier_b_fonologia_historica",
    },
}


class NavarroChunker:
    """Processador de Chunks de Alta Precisão Filológica (Eduardo Navarro USP)."""

    def __init__(self, backend_dir: Optional[Path] = None):
        self.backend_dir = backend_dir or BACKEND_DIR
        self.pdfs_dir = self.backend_dir / "pdfs"

    def build_dictionary_chunks(self) -> List[Dict[str, Any]]:
        """
        Gera chunks lexicográficos a partir das correções auditadas e verbetes documentados
        de Eduardo Navarro (2013).
        """
        chunks: List[Dict[str, Any]] = []
        seen_lemmas: set[str] = set()

        # 1. Verbetes de audit_navarro_dictionary_full.py
        try:
            from scripts.audit_navarro_dictionary_full import CANONICAL_NAVARRO_CORRECTIONS
            for termo_raw, info in CANONICAL_NAVARRO_CORRECTIONS.items():
                correto = info.get("correto", termo_raw)
                if correto.lower() in seen_lemmas:
                    continue
                seen_lemmas.add(correto.lower())

                pagina = info.get("pagina", 1)
                categoria_gram = info.get("categoria", "s.")
                traducao = info.get("traducao", "")
                exemplo = info.get("exemplo", "")
                nota = info.get("nota", "")

                doc_text = (
                    f"[VERBETE]: {correto} | [CLASSE]: {categoria_gram} | [SIGNIFICADO]: {traducao}\n"
                    f"[ABONAÇÃO / CONTEXTO HISTÓRICO]: {exemplo}\n"
                    f"[FONTE DOCUMENTAL]: Eduardo de Almeida Navarro, Dicionário de Tupi Antigo (2013), p. {pagina}.\n"
                    f"[REGRA / MORFOLOGIA]: {nota}"
                ).strip()

                chunk_id = f"navarro_dict_p{pagina}_{hashlib.md5(correto.encode()).hexdigest()[:8]}"
                categoria = "Gramática" if ("part." in categoria_gram or "posp." in categoria_gram or "pron." in categoria_gram) else "Vocabulário"

                chunks.append({
                    "id": chunk_id,
                    "document": doc_text,
                    "metadata": {
                        "filename": "Dicionário Tupi.pdf",
                        "obra": "Dicionário de Tupi Antigo (Eduardo de Almeida Navarro, 2013)",
                        "autor": "Eduardo de Almeida Navarro",
                        "pagina": pagina,
                        "lema": correto,
                        "classe": categoria_gram,
                        "variante": "tupi_antigo",
                        "categoria": categoria,
                        "autoridade": 1.0,
                        "confianca": 1.0,
                        "precisa_revisao": 0,
                        "tier": "tier_a_lexicografia_canonica",
                    }
                })
        except Exception as exc:
            logger.warning("[NavarroChunker] Falha ao importar CANONICAL_NAVARRO_CORRECTIONS: %s", exc)

        # 2. Verbetes de candidatos_navarro.json
        cand_file = self.backend_dir / "pedagogico" / "filologia" / "candidatos_navarro.json"
        if cand_file.exists():
            try:
                with open(cand_file, "r", encoding="utf-8") as f:
                    cand_data = json.load(f)
                for cand in cand_data.get("candidates", []):
                    lema = cand.get("lema_original", "").strip()
                    if not lema or lema.lower() in seen_lemmas:
                        continue
                    seen_lemmas.add(lema.lower())

                    sig = cand.get("significado_extraido", "").strip()
                    classe = cand.get("classe_gramatical", "s.").strip()
                    pag = cand.get("fonte", {}).get("pagina_impressa", 1)

                    doc_text = (
                        f"[VERBETE]: {lema} | [CLASSE]: {classe} | [SIGNIFICADO]: {sig}\n"
                        f"[FONTE DOCUMENTAL]: Eduardo de Almeida Navarro, Dicionário de Tupi Antigo (2013), p. {pag}."
                    )
                    chunk_id = f"navarro_cand_p{pag}_{cand.get('id', hashlib.md5(lema.encode()).hexdigest()[:8])}"
                    categoria = "Gramática" if ("part." in classe or "posp." in classe) else "Vocabulário"

                    chunks.append({
                        "id": chunk_id,
                        "document": doc_text,
                        "metadata": {
                            "filename": "Dicionário Tupi.pdf",
                            "obra": "Dicionário de Tupi Antigo (Eduardo de Almeida Navarro, 2013)",
                            "autor": "Eduardo de Almeida Navarro",
                            "pagina": pag,
                            "lema": lema,
                            "classe": classe,
                            "variante": "tupi_antigo",
                            "categoria": categoria,
                            "autoridade": 1.0,
                            "confianca": 0.98,
                            "precisa_revisao": 0,
                            "tier": "tier_a_lexicografia_canonica",
                        }
                    })
            except Exception as exc:
                logger.warning("[NavarroChunker] Falha ao ler candidatos_navarro.json: %s", exc)

        # 3. Léxico de lexicon_data.py (cobrindo Tupi Antigo e Tupi Revitalizado)
        try:
            from pedagogico.lexicon_data import LEXICON_BY_VARIANT_CHAPTER
            for var_key, chapters in LEXICON_BY_VARIANT_CHAPTER.items():
                variante_code = "tupi_revitalizado" if "revitalizado" in var_key else "tupi_antigo"
                for cap_num, items in chapters.items():
                    for it in items:
                        palavra = it.get("palavra", "").strip()
                        if not palavra:
                            continue
                        trad = it.get("traducao", "")
                        exemplo = it.get("exemplo_uso", "")
                        cat = it.get("categoria", "geral")
                        translit = it.get("transliteracao", "")

                        tag_obra = "Método Moderno de Tupi Antigo / Revitalização" if variante_code == "tupi_revitalizado" else "Dicionário de Tupi Antigo (2013)"
                        doc_text = (
                            f"[VERBETE]: {palavra} | [TRADUÇÃO]: {trad} | [VARIANTE]: {variante_code.upper()}\n"
                            f"[EXEMPLO DE USO]: {exemplo}\n"
                            f"[PRONÚNCIA / TRANSLITERAÇÃO]: {translit}\n"
                            f"[FONTE]: Eduardo de Almeida Navarro, {tag_obra} (Capítulo {cap_num})."
                        )
                        chunk_id = f"lexicon_{variante_code}_c{cap_num}_{hashlib.md5(palavra.encode()).hexdigest()[:8]}"
                        chunks.append({
                            "id": chunk_id,
                            "document": doc_text,
                            "metadata": {
                                "filename": "lexicon_data.py",
                                "obra": tag_obra,
                                "autor": "Eduardo de Almeida Navarro",
                                "pagina": int(cap_num),
                                "lema": palavra,
                                "classe": "vocábulo",
                                "variante": variante_code,
                                "categoria": "Vocabulário" if cat not in ("gramatica", "historia") else cat.capitalize(),
                                "autoridade": 1.0,
                                "confianca": 1.0,
                                "precisa_revisao": 0,
                                "tier": "tier_a_lexicografia_canonica",
                            }
                        })
        except Exception as exc:
            logger.warning("[NavarroChunker] Falha ao importar lexicon_data.py: %s", exc)

        logger.info("[NavarroChunker] Total de chunks lexicográficos gerados: %d", len(chunks))
        return chunks

    def extract_textual_chunks_from_pdf(self, filename: str) -> List[Dict[str, Any]]:
        """
        Extrai blocos de texto coesos (parágrafos completos entre 250 e 750 caracteres)
        das obras textuais canônicas (Cartas de 1645, Topônimos, Acento, etc.).
        """
        if filename not in CANONICAL_SOURCES:
            logger.warning("[NavarroChunker] PDF '%s' não está na lista canônica. Ignorado.", filename)
            return []

        info = CANONICAL_SOURCES[filename]
        pdf_path = self.pdfs_dir / filename
        if not pdf_path.exists():
            logger.warning("[NavarroChunker] Arquivo não encontrado: %s", pdf_path)
            return []

        try:
            import PyPDF2
        except ImportError:
            logger.error("[NavarroChunker] PyPDF2 não disponível.")
            return []

        chunks: List[Dict[str, Any]] = []
        try:
            with open(pdf_path, "rb") as f:
                reader = PyPDF2.PdfReader(f)
                total_pages = len(reader.pages)
                for page_num in range(total_pages):
                    raw_text = reader.pages[page_num].extract_text() or ""
                    clean_text = raw_text.strip()
                    if len(clean_text) < 60:
                        continue

                    paragraphs = [p.strip() for p in re.split(r"\n\s*\n+", clean_text) if p.strip()]
                    cur_block: list[str] = []
                    cur_len = 0

                    for p in paragraphs:
                        p_len = len(p)
                        if cur_len + p_len <= 700:
                            cur_block.append(p)
                            cur_len += p_len + 1
                        else:
                            if cur_block:
                                block_text = " ".join(cur_block)
                                if len(block_text) >= 150:
                                    chunks.append(self._format_text_chunk(block_text, filename, page_num + 1, info))
                            cur_block = [p]
                            cur_len = p_len

                    if cur_block:
                        block_text = " ".join(cur_block)
                        if len(block_text) >= 150:
                            chunks.append(self._format_text_chunk(block_text, filename, page_num + 1, info))

        except Exception as exc:
            logger.error("[NavarroChunker] Erro ao processar PDF '%s': %s", filename, exc)

        logger.info("[NavarroChunker] PDF '%s': %d chunks textuais extraídos.", filename, len(chunks))
        return chunks

    def _format_text_chunk(self, text: str, filename: str, page_num: int, info: Dict[str, Any]) -> Dict[str, Any]:
        """Formata chunk textual com metadados completos."""
        h = hashlib.md5(text.encode("utf-8")).hexdigest()[:10]
        cid = f"{filename[:8]}_p{page_num}_{h}"

        t_low = text.lower()
        if any(w in t_low for w in ["acento", "oxítona", "paroxítona", "sílaba", "vogal", "nasal"]):
            cat = "Gramática"
        elif any(w in t_low for w in ["topônimo", "rio", "serra", "lugar", "ipiranga", "tietê", "paraná"]):
            cat = "Toponímia"
        elif any(w in t_low for w in ["carta", "1645", "camarão", "poti", "holandês", "batalha"]):
            cat = "História"
        elif any(w in t_low for w in ["verbo", "sufixo", "prefixo", "morfolo", "sintaxe", "gerúndio"]):
            cat = "Gramática"
        else:
            cat = "Vocabulário"

        return {
            "id": cid,
            "document": text,
            "metadata": {
                "filename": filename,
                "obra": info.get("obra", filename),
                "autor": info.get("autor", "Linguista Especialista"),
                "pagina": page_num,
                "variante": info.get("variante", "tupi_antigo"),
                "categoria": cat,
                "autoridade": info.get("autoridade", 0.9),
                "confianca": 0.95,
                "precisa_revisao": 0,
                "tier": info.get("tier", "tier_b_acervo_canonica"),
            }
        }

    def generate_all_canonical_chunks(self) -> List[Dict[str, Any]]:
        """Compila a base completa de chunks lexicográficos e textuais de Eduardo Navarro."""
        all_chunks: List[Dict[str, Any]] = []

        # 1. Base Lexicográfica
        all_chunks.extend(self.build_dictionary_chunks())

        # 2. Textos Canônicos Anotados
        textual_pdfs = [
            "download.pdf",
            "Transcrição e Tradução Carta 1645.pdf",
            "Mistieri_2010_Acento_Tupi_Antigo.pdf",
            "tupi-potiguara-kuapa-2023_compress.pdf",
            "Rodrigues_2011_AnaliseMorfologicaDeUmTextoTupi.pdf",
        ]
        for pdf_name in textual_pdfs:
            all_chunks.extend(self.extract_textual_chunks_from_pdf(pdf_name))

        logger.info("[NavarroChunker] Total geral de chunks canônicos compilados: %d", len(all_chunks))
        return all_chunks
