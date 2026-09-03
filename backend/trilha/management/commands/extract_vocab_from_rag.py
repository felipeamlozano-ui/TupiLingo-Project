import json
import logging
import os
import time
from typing import Literal, List
from django.core.management.base import BaseCommand
from django.db import connection, transaction, close_old_connections
from pydantic import BaseModel, Field

from app.ai.rag_service import get_db
from app.ai.router import ModelRouter
from app.ai.fallback import FallbackOrchestrator
import litellm

logger = logging.getLogger("nivelamento.etl")

class ItemCategory(BaseModel):
    id: int
    categoria: Literal["Vocabulário", "Gramática", "História", "Mitologia", "Desconhecido"] = Field(
        ..., description="A categoria principal do documento."
    )

class BatchClassification(BaseModel):
    itens: List[ItemCategory]

class Command(BaseCommand):
    help = "Varre o banco vetorial SQLite (GraphRAG), usa LLMs na nuvem em lote (10 chunks por chamada) para classificar o texto e insere imediatamente no Supabase."

    def add_arguments(self, parser):
        parser.add_argument('--limit', type=int, default=50, help='Limite de chunks buscados por ciclo.')
        parser.add_argument('--offset', type=int, default=0, help='Offset para buscar chunks.')
        parser.add_argument('--batch-size', type=int, default=10, help='Tamanho do lote de chunks por chamada de LLM.')
        parser.add_argument('--continuous', action='store_true', help='Executa em loop contínuo como worker.')

    def handle(self, *args, **options):
        limit = options['limit']
        offset = options['offset']
        batch_size = options['batch_size']
        continuous = options['continuous']

        self.stdout.write(self.style.NOTICE(
            f"Iniciando ETL de classificação em Lote (Batch={batch_size} chunks/prompt, Continuous={continuous})"
        ))
        
        vector_db = get_db()
        
        # Garante que a coluna de status exista no SQLite
        with vector_db._connect() as conn:
            try:
                conn.execute("ALTER TABLE documents ADD COLUMN category_extracted INTEGER DEFAULT 0")
            except Exception:
                pass

        # Garante que a tabela exista no Supabase/PostgreSQL via Django DB connection
        close_old_connections()
        with connection.cursor() as cursor:
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS rag_document_categories (
                    id SERIAL PRIMARY KEY,
                    chunk_id TEXT NOT NULL,
                    document_text TEXT NOT NULL,
                    categoria TEXT NOT NULL,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                )
            """)
        connection.close()

        total_categorizados = 0

        while True:
            # Busca chunks pendentes
            with vector_db._connect() as conn:
                rows = conn.execute(
                    "SELECT id, document FROM documents WHERE category_extracted = 0 ORDER BY created_at DESC LIMIT ? OFFSET ?", 
                    (limit, offset)
                ).fetchall()

            if not rows:
                if continuous:
                    self.stdout.write(self.style.WARNING("Nenhum chunk pendente. Aguardando 15s para nova checagem..."))
                    time.sleep(15)
                    continue
                else:
                    self.stdout.write(self.style.WARNING("Nenhum chunk pendente de classificação encontrado no RAG."))
                    break

            # Processa as linhas em sub-lotes de tamanho `batch_size` (ex: 10 chunks por vez)
            for i in range(0, len(rows), batch_size):
                chunk_batch = rows[i : i + batch_size]
                batch_len = len(chunk_batch)

                self.stdout.write(f"Classificando lote com {batch_len} chunks (IDs: {chunk_batch[0][0][:12]}..{chunk_batch[-1][0][:12]})...")

                # Monta prompt em lote numerado com diretrizes claras para evitar falso "Desconhecido"
                prompt = (
                    f"Você é um especialista em língua Tupi Antiga, linguística e história indígena.\n"
                    f"Classifique cada um dos {batch_len} textos numerados a seguir na categoria MAIS APROPRIADA dentre as opções:\n"
                    "- 'Vocabulário': Dicionários, listas de vocábulos, traduções palavra por palavra, termos isolados e seus significados.\n"
                    "- 'Gramática': Regras sintáticas, conjugação de verbos, prefixos/sufixos, pronomes, morfologia e estrutura de frases.\n"
                    "- 'História': Cartas históricas, documentos coloniais, relatos de viagem (ex: Hans Staden, Thevet), guerras, personagens (ex: Pedro Poti, Camarão) e notas sobre aldeias.\n"
                    "- 'Mitologia': Lendas, seres míticos (Tupã, Curupira, Anhangá, Jaci), rituais religiosos, cosmologia e crenças indígenas.\n"
                    "- 'Desconhecido': Use APENAS para sumários, índices bibliográficos ou ruídos ilegíveis sem conteúdo textual útil.\n\n"
                    "Textos:\n"
                )
                for idx, (row_id, doc_text) in enumerate(chunk_batch, 1):
                    # Limita o texto do chunk caso seja excessivamente longo
                    doc_snippet = doc_text.strip()[:800]
                    prompt += f"[{idx}] {doc_snippet}\n"

                prompt += '\nRetorne ESTRITAMENTE o JSON no formato: {"itens": [{"id": 1, "categoria": "Vocabulário"}, ...]}'

                registros_lote: list[tuple[str, str, str]] = []
                processados_ids: list[str] = []

                try:
                    chain = ModelRouter.get_chain_for_task("vocab_extraction_cloud")
                    batch_res = FallbackOrchestrator.execute_with_fallback(
                        prompt=prompt,
                        schema=BatchClassification,
                        chain=chain,
                        temperature=0.0,
                        max_tokens=600,
                    )

                    # Cria mapa de resultados { 1: "Vocabulário", 2: "Gramática", ... }
                    results_map = {item.id: item.categoria for item in batch_res.itens}

                    for idx, (row_id, doc_text) in enumerate(chunk_batch, 1):
                        categoria = results_map.get(idx, "Desconhecido")
                        registros_lote.append((str(row_id), doc_text, categoria))
                        processados_ids.append(str(row_id))

                    total_categorizados += len(registros_lote)

                    # Salva imediatamente os 10 chunks no Supabase e atualiza SQLite
                    self._salvar_lote(registros_lote, processados_ids, vector_db)
                    time.sleep(0.4)

                except Exception as e:
                    self.stdout.write(self.style.ERROR(f"Erro ao classificar lote de {batch_len} chunks: {e}"))
                    logger.error(f"Erro ETL no lote de chunks", exc_info=True)
                    # Marca como processado com Desconhecido para não travar o loop
                    fallback_registros = [(str(r[0]), r[1], "Desconhecido") for r in chunk_batch]
                    fallback_ids = [str(r[0]) for r in chunk_batch]
                    self._salvar_lote(fallback_registros, fallback_ids, vector_db)

            self.stdout.write(self.style.SUCCESS(f"Ciclo concluído. Total acumulado: {total_categorizados} textos categorizados."))

            if not continuous:
                break



    def _salvar_lote(self, registros: list[tuple[str, str, str]], row_ids: list[str], vector_db):
        """Salva múltiplos registros de uma vez no Supabase e atualiza o SQLite local."""
        close_old_connections()
        with connection.cursor() as cursor:
            # PostgreSQL bulk insert eficiente
            args_str = ','.join(cursor.mogrify("(%s,%s,%s)", x).decode('utf-8') for x in registros) if hasattr(cursor, 'mogrify') else ','.join(['(%s,%s,%s)'] * len(registros))
            if hasattr(cursor, 'mogrify'):
                cursor.execute("INSERT INTO rag_document_categories (chunk_id, document_text, categoria) VALUES " + args_str)
            else:
                flat_params = [item for sublist in registros for item in sublist]
                cursor.execute(f"INSERT INTO rag_document_categories (chunk_id, document_text, categoria) VALUES {args_str}", flat_params)
        
        # Atualiza o SQLite local em batch
        with vector_db._connect() as conn:
            conn.executemany("UPDATE documents SET category_extracted = 1 WHERE id = ?", [(rid,) for rid in row_ids])
            conn.commit()
            
        self.stdout.write(self.style.SUCCESS(f"  [OK] Lote de {len(registros)} chunks salvo no Supabase."))
        # Força o fechamento da conexão do Postgres após salvar o lote
        # para que uma nova seja aberta no próximo lote, evitando
        # erros de "server closed the connection unexpectedly" devido
        # ao tempo ocioso aguardando as respostas da LLM local (Ollama).
        connection.close()
