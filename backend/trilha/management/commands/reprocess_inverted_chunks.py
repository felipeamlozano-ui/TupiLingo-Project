import time
import logging
import sqlite3
from typing import Literal
from pydantic import BaseModel, Field

from django.core.management.base import BaseCommand
from django.db import connection, close_old_connections

from app.ai.rag_service import get_db
from app.ai.router import ModelRouter
from app.ai.fallback import FallbackOrchestrator

logger = logging.getLogger("reprocess_inverted")

class ClassificationItem(BaseModel):
    id: int
    categoria: Literal["Vocabulário", "Gramática", "História", "Mitologia", "Desconhecido"] = Field(
        description="Categoria atribuída ao trecho de texto."
    )

class BatchClassification(BaseModel):
    itens: list[ClassificationItem]


class Command(BaseCommand):
    help = "Corrige chunks de documentos digitalizados invertidos e reclassifica via LLM"

    def add_arguments(self, parser):
        parser.add_argument(
            "--file-hash",
            type=str,
            default="87c9662bc45de33bf5f5592c24f249d4ac86ed3fe568d99bcff11f96ad131671",
            help="Hash do arquivo com chunks invertidos (default: Dicionário Tupi)",
        )
        parser.add_argument(
            "--batch-size",
            type=int,
            default=15,
            help="Tamanho do lote de chunks enviados para a LLM por vez (default: 15)",
        )
        parser.add_argument(
            "--limit",
            type=int,
            default=0,
            help="Limite de chunks para processar nesta execução (0 = todos)",
        )

    def handle(self, *args, **options):
        file_hash = options["file_hash"]
        batch_size = options["batch_size"]
        limit = options["limit"]

        self.stdout.write(self.style.NOTICE(
            f"Iniciando correção de chunks invertidos e recategorização (Hash: {file_hash[:12]}..., Batch: {batch_size})"
        ))

        vector_db = get_db()

        # 1. Localiza chunks desse arquivo que estão no SQLite
        with vector_db._connect() as conn:
            query = "SELECT id, document FROM documents WHERE id LIKE ? ORDER BY CAST(json_extract(metadata, '$.chunk_index') AS INT)"
            params = [f"{file_hash}%"]
            if limit > 0:
                query += " LIMIT ?"
                params.append(limit)
            rows = conn.execute(query, tuple(params)).fetchall()

        if not rows:
            self.stdout.write(self.style.WARNING("Nenhum chunk encontrado para o hash especificado."))
            return

        self.stdout.write(f"Total de chunks encontrados: {len(rows)}")

        total_processados = 0
        total_atualizados = 0

        for i in range(0, len(rows), batch_size):
            chunk_batch = rows[i : i + batch_size]
            batch_len = len(chunk_batch)

            # Inverte as linhas de cada chunk do lote para restaurar a leitura natural
            corrected_batch = []
            for row_id, doc_text in chunk_batch:
                # Inverte cada linha individualmente (desespelha RTL -> LTR)
                inverted_lines = [line[::-1] for line in doc_text.splitlines()]
                corrected_text = "\n".join(inverted_lines)
                corrected_batch.append((str(row_id), corrected_text))

            # Monta prompt compacto para a LLM
            prompt = (
                f"Você é um especialista em língua Tupi Antiga, linguística e história indígena.\n"
                f"Classifique cada um dos {batch_len} textos a seguir na categoria MAIS APROPRIADA dentre:\n"
                "- 'Vocabulário': Dicionários, listas de palavras, verbetes, termos e traduções isoladas.\n"
                "- 'Gramática': Regras gramaticais, morfologia, prefixos, conjugação de verbos, sintaxe.\n"
                "- 'História': Textos históricos, cartas coloniais, relatos de viagem, biografia de autores.\n"
                "- 'Mitologia': Lendas, seres míticos, rituais, espiritualidade indígena.\n"
                "- 'Desconhecido': Apenas ruídos ilegíveis, índices vazios, capas ou referências numéricas sem texto útil.\n\n"
                "Textos:\n"
            )

            for idx, (row_id, corr_text) in enumerate(corrected_batch, 1):
                snippet = corr_text.strip()[:650]
                prompt += f"[{idx}] {snippet}\n"

            prompt += '\nRetorne ESTRITAMENTE o JSON no formato: {"itens": [{"id": 1, "categoria": "Vocabulário"}, ...]}'

            try:
                chain = ModelRouter.get_chain_for_task("vocab_extraction_cloud")
                batch_res = FallbackOrchestrator.execute_with_fallback(
                    prompt=prompt,
                    schema=BatchClassification,
                    chain=chain,
                    temperature=0.0,
                    max_tokens=600,
                )

                results_map = {item.id: item.categoria for item in batch_res.itens}
            except Exception as e:
                self.stdout.write(self.style.WARNING(f"Falha na LLM para lote ({e}). Aplicando heurística lexical de segurança."))
                # Heurística de fallback: se contém marcadores de verbete ou tradução, é Vocabulário
                results_map = {}
                for idx, (row_id, corr_text) in enumerate(corrected_batch, 1):
                    lower = corr_text.lower()
                    if any(m in lower for m in [" - ", " (s.)", " (v.)", " (adj.)", " (adv.)", " (t.)", " (fig.", "vlb", "arte"]):
                        results_map[idx] = "Vocabulário"
                    elif any(m in lower for m in ["regra", "verbo", "prefixo", "sufixo", "conjugação", "sintaxe"]):
                        results_map[idx] = "Gramática"
                    else:
                        results_map[idx] = "Vocabulário"

            # Prepara atualizações
            supabase_updates = []
            sqlite_updates = []

            for idx, (row_id, corr_text) in enumerate(corrected_batch, 1):
                cat = results_map.get(idx, "Vocabulário")
                supabase_updates.append((cat, corr_text, row_id))
                sqlite_updates.append((corr_text, row_id))

            # Atualiza no SQLite local (texto corrigido)
            with vector_db._connect() as conn:
                conn.executemany("UPDATE documents SET document = ?, category_extracted = 1 WHERE id = ?", sqlite_updates)
                conn.commit()

            # Atualiza ou insere no Supabase (categoria + texto corrigido)
            close_old_connections()
            with connection.cursor() as cursor:
                for cat, text_val, cid in supabase_updates:
                    cursor.execute("""
                        INSERT INTO rag_document_categories (chunk_id, document_text, categoria)
                        VALUES (%s, %s, %s)
                        ON CONFLICT (chunk_id) DO UPDATE 
                        SET categoria = EXCLUDED.categoria,
                            document_text = EXCLUDED.document_text
                    """, (cid, text_val, cat))

            connection.close()

            total_processados += batch_len
            total_atualizados += len(supabase_updates)
            self.stdout.write(self.style.SUCCESS(
                f"  [{total_processados}/{len(rows)}] Lote de {batch_len} chunks corrigido e sincronizado no Supabase/SQLite."
            ))
            time.sleep(0.3)

        self.stdout.write(self.style.SUCCESS(
            f"\nCorreção concluída com sucesso! Total de {total_atualizados} chunks processados."
        ))
