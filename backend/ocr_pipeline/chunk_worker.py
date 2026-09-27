"""
Worker de Chunking Consciente de Estrutura de Dicionário (Etapas 9 e 13 da Fase 1).
Implementa preservação atômica de verbetes/traduções/exemplos e subdivisão secundária
com herança de lema e metadados quando o verbete excede o limite máximo (~1.500 chars).
"""
import re
from typing import Any

from .models import DictionaryChunk

# Expressões regulares documentadas para detecção de verbetes de dicionários históricos
# Padrões suportados:
# 1. "Aba: Homem, ser humano."
# 2. "Oka, s. Casa, habitação."
# 3. "Puranga (adj.) Bom, bonito."
# 4. "Iandé (pron. pess.) Nós."
DICT_ENTRY_PATTERNS = [
    re.compile(r"^([A-ZÁÉÍÓÚÂÊÎÔÛÃÕẼĨỸ][\w'-]+)\s*,\s*(s\.|adj\.|v\.|adv\.|pron\.|posp\.|interj\.)\s*[:—–-]?\s*(.*)", re.IGNORECASE),
    re.compile(r"^([A-ZÁÉÍÓÚÂÊÎÔÛÃÕẼĨỸ][\w'-]+)\s*\((s\.|adj\.|v\.|adv\.|pron\.|posp\.|interj\.|[^)]+)\)\s*[:—–-]?\s*(.*)", re.IGNORECASE),
    re.compile(r"^([A-ZÁÉÍÓÚÂÊÎÔÛÃÕẼĨỸ][\w'-]{1,30})\s*[:—–-]\s+(.+)")
]

class ChunkWorker:
    def __init__(self, max_chunk_chars: int = 1500, min_chunk_chars: int = 200):
        self.max_chunk_chars = max_chunk_chars
        self.min_chunk_chars = min_chunk_chars

    def parse_dictionary_entries(self, text: str) -> list[dict[str, Any]]:
        """Identifica e agrupa verbetes por cabeçalho/lema."""
        lines = [line.strip() for line in text.splitlines() if line.strip()]
        entries = []
        current_entry = None

        for line in lines:
            matched = False
            for pat in DICT_ENTRY_PATTERNS:
                m = pat.match(line)
                if m:
                    headword_cand = m.group(1).strip()
                    # Ignorar falsos positivos de lema como "Ex:", "Exemplo:", "Nota:", "Obs:"
                    if headword_cand.lower() in ("ex", "exemplo", "nota", "obs", "observacao", "observação", "veja", "v"):
                        continue

                    # Salva verbete anterior
                    if current_entry:
                        entries.append(current_entry)

                    headword = headword_cand
                    pos = m.group(2).strip() if len(m.groups()) >= 3 else ""
                    rest = m.group(3).strip() if len(m.groups()) >= 3 else m.group(2).strip()

                    current_entry = {
                        "headword": headword,
                        "pos": pos,
                        "lines": [line],
                        "is_dict_entry": True
                    }
                    matched = True
                    break

            if not matched:
                if current_entry:
                    current_entry["lines"].append(line)
                else:
                    # Linhas anteriores ao primeiro verbete (ex: cabeçalhos ou notas)
                    current_entry = {
                        "headword": "Nota/Geral",
                        "pos": "",
                        "lines": [line],
                        "is_dict_entry": False
                    }

        if current_entry:
            entries.append(current_entry)

        return entries

    def chunk_text(
        self,
        text: str,
        filename: str,
        page_num: int
    ) -> list[DictionaryChunk]:
        """
        Executa o chunking consciente de estrutura de dicionário.
        Nunca quebra verbete no meio a menos que exceda max_chunk_chars.
        Se exceder, subdivide por acepção (1., 2.) ou exemplo (Ex:),
        preservando o lema herdado em cada sub-chunk.
        """
        raw_entries = self.parse_dictionary_entries(text)
        chunks = []
        chunk_idx = 0

        for entry in raw_entries:
            entry_text = "\n".join(entry["lines"])
            headword = entry["headword"]
            pos = entry["pos"]
            is_dict = entry["is_dict_entry"]

            # Caso 1: Verbete cabe perfeitamente no chunk
            if len(entry_text) <= self.max_chunk_chars:
                chunks.append(DictionaryChunk(
                    chunk_index=chunk_idx,
                    text=entry_text,
                    headword=headword if is_dict else None,
                    part_of_speech=pos if pos else None,
                    sub_sense=None,
                    source_filename=filename,
                    page_num=page_num,
                    is_subdivided=False,
                    char_count=len(entry_text),
                    metadata={
                        "is_dictionary_entry": is_dict,
                        "headword": headword if is_dict else None
                    }
                ))
                chunk_idx += 1
            else:
                # Caso 2: Verbete excede o limite máximo (~1500 chars)
                # Subdivisão secundária por acepção numerada ou exemplo
                sub_parts = re.split(
                    r"(?=\n\s*(?:[1-9]\.|\b(?:I|II|III|IV|V)\b\.)|\bEx(?:emplo)?:\s*)",
                    entry_text
                )

                sub_accum = ""
                sub_sense_num = 1

                for part in sub_parts:
                    candidate = (sub_accum + "\n" + part).strip() if sub_accum else part.strip()
                    if len(candidate) <= self.max_chunk_chars:
                        sub_accum = candidate
                    else:
                        if sub_accum:
                            # Prefixo herdado para nunca perder contexto semântico
                            inherited_prefix = f"[{headword}{' (' + pos + ')' if pos else ''} - Parte {sub_sense_num}]\n"
                            final_sub_text = inherited_prefix + sub_accum
                            chunks.append(DictionaryChunk(
                                chunk_index=chunk_idx,
                                text=final_sub_text,
                                headword=headword,
                                part_of_speech=pos,
                                sub_sense=f"parte_{sub_sense_num}",
                                source_filename=filename,
                                page_num=page_num,
                                is_subdivided=True,
                                char_count=len(final_sub_text),
                                metadata={
                                    "is_dictionary_entry": True,
                                    "headword": headword,
                                    "subdivided": True,
                                    "sub_sense_index": sub_sense_num
                                }
                            ))
                            chunk_idx += 1
                            sub_sense_num += 1
                        sub_accum = part.strip()

                if sub_accum:
                    inherited_prefix = f"[{headword}{' (' + pos + ')' if pos else ''} - Parte {sub_sense_num}]\n"
                    final_sub_text = inherited_prefix + sub_accum
                    chunks.append(DictionaryChunk(
                        chunk_index=chunk_idx,
                        text=final_sub_text,
                        headword=headword,
                        part_of_speech=pos,
                        sub_sense=f"parte_{sub_sense_num}",
                        source_filename=filename,
                        page_num=page_num,
                        is_subdivided=True,
                        char_count=len(final_sub_text),
                        metadata={
                            "is_dictionary_entry": True,
                            "headword": headword,
                            "subdivided": True,
                            "sub_sense_index": sub_sense_num
                        }
                    ))
                    chunk_idx += 1

        return chunks
