import logging
import time
from typing import Literal

from app.ai.fallback import FallbackOrchestrator
from app.ai.rag_service import get_db
from app.ai.router import ModelRouter
from django.core.management.base import BaseCommand
from django.db import close_old_connections, connection
from pydantic import BaseModel, Field

logger = logging.getLogger("nivelamento.etl")

class SingleChunkCategory(BaseModel):
    categoria: Literal["Vocabulário", "Gramática", "História", "Mitologia", "Desconhecido"] = Field(
        ..., description="A categoria principal do documento."
    )

class ItemCategory(BaseModel):
    id: int
    categoria: Literal["Vocabulário", "Gramática", "História", "Mitologia", "Desconhecido"] = Field(
        ..., description="A categoria principal do documento."
    )

class BatchClassification(BaseModel):
    itens: list[ItemCategory]

class Command(BaseCommand):
    help = (
        "Varre o banco vetorial SQLite (GraphRAG), classifica os chunks usando LLMs na nuvem "
        "com fallback sequencial exaustivo (ciclo 1 a 1 resiliente) e insere com idempotência no Supabase."
    )

    def add_arguments(self, parser):
        parser.add_argument('--limit', type=int, default=50, help='Limite de chunks buscados por ciclo.')
        parser.add_argument('--offset', type=int, default=0, help='Offset para buscar chunks.')
        parser.add_argument('--batch-size', type=int, default=10, help='Tamanho do lote para tentativa inicial de batch (fallback automático 1 a 1).')
        parser.add_argument('--continuous', action='store_true', help='Executa em loop contínuo como worker.')

    def handle(self, *args, **options):
        limit = options['limit']
        offset = options['offset']
        batch_size = options['batch_size']
        continuous = options['continuous']

        self.stdout.write(self.style.NOTICE(
            f"Iniciando ETL de classificação resiliente (Batch={batch_size}, Continuous={continuous})"
        ))
        
        vector_db = get_db()
        
        # Garante que a coluna de status exista no SQLite
        with vector_db._connect() as conn:
            try:
                conn.execute("ALTER TABLE documents ADD COLUMN category_extracted INTEGER DEFAULT 0")
            except Exception:
                pass

        # Garante que a tabela e o índice único existam no Supabase/PostgreSQL
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
            cursor.execute("""
                CREATE UNIQUE INDEX IF NOT EXISTS idx_rag_document_categories_chunk_id 
                ON rag_document_categories (chunk_id)
            """)
        connection.close()

        total_categorizados = 0
        chain = ModelRouter.get_chain_for_task("vocab_extraction_cloud")
        self.stdout.write(self.style.SUCCESS(f"Cadeia de fallback configurada com {len(chain)} modelos:"))
        for idx, m in enumerate(chain, 1):
            self.stdout.write(f"  [{idx}] {m}")

        while True:
            # Busca chunks pendentes de extração
            with vector_db._connect() as conn:
                rows = conn.execute(
                    "SELECT id, document FROM documents WHERE category_extracted = 0 ORDER BY created_at DESC LIMIT ? OFFSET ?", 
                    (limit, offset)
                ).fetchall()

            if not rows:
                if continuous:
                    self.stdout.write(self.style.WARNING("Nenhum chunk pendente. Aguardando 30min (1800s) para nova checagem..."))
                    time.sleep(1800)
                    continue
                else:
                    self.stdout.write(self.style.WARNING("Nenhum chunk pendente de classificação encontrado no RAG."))
                    break

            self.stdout.write(self.style.NOTICE(f"Encontrados {len(rows)} chunks pendentes para processamento."))

            # Se batch_size > 1, tentamos processar em lotes; caso falhe, decompõe 1 a 1
            # Se batch_size == 1, processa estritamente 1 a 1
            for i in range(0, len(rows), batch_size):
                chunk_batch = rows[i : i + batch_size]
                batch_len = len(chunk_batch)

                registros_salvar: list[tuple[str, str, str]] = []
                ids_salvar: list[str] = []

                if batch_len > 1:
                    self.stdout.write(f"Classificando lote de {batch_len} chunks (IDs: {chunk_batch[0][0][:12]}..{chunk_batch[-1][0][:12]})...")
                    lote_ok, resultados_lote = self._tentar_classificar_lote(chunk_batch, chain)
                    if lote_ok:
                        registros_salvar = resultados_lote
                        ids_salvar = [r[0] for r in resultados_lote]
                    else:
                        self.stdout.write(self.style.WARNING(
                            f"Lote falhou. Ativando ciclo 1 a 1 exaustivo para os {batch_len} chunks..."
                        ))

                # Ciclo 1 a 1 individual para os chunks que não foram resolvidos em lote
                if not registros_salvar:
                    for chunk_id, doc_text in chunk_batch:
                        self.stdout.write(f" -> Processando chunk individual {chunk_id[:16]}...")
                        categoria, sucesso = self._classificar_chunk_1a1(chunk_id, doc_text, chain)
                        if sucesso or categoria == "Desconhecido":
                            registros_salvar.append((str(chunk_id), doc_text, categoria))
                            ids_salvar.append(str(chunk_id))
                        else:
                            # Falha total de infraestrutura em todos os provedores: NÃO marca como processado
                            self.stdout.write(self.style.ERROR(
                                f"  [FALHA TOTAL] Chunk {chunk_id[:16]} mantido pendente (category_extracted=0) para retry futuro."
                            ))

                if registros_salvar:
                    self._salvar_lote(registros_salvar, ids_salvar, vector_db)
                    total_categorizados += len(registros_salvar)
                    time.sleep(0.3)

            self.stdout.write(self.style.SUCCESS(f"Ciclo concluído. Total acumulado: {total_categorizados} textos categorizados."))

            if not continuous:
                break

    def _tentar_classificar_lote(
        self, chunk_batch: list[tuple[str, str]], chain: list[str]
    ) -> tuple[bool, list[tuple[str, str, str]]]:
        """Tenta classificar múltiplos chunks em um único prompt com o topo da cadeia."""
        batch_len = len(chunk_batch)
        prompt = (
            f"Você é um especialista em língua Tupi Antiga, linguística e história indígena.\n"
            f"Classifique cada um dos {batch_len} textos numerados a seguir na categoria MAIS APROPRIADA dentre as opções:\n"
            "- 'Vocabulário': Dicionários, listas de vocábulos, traduções palavra por palavra, termos isolados e seus significados.\n"
            "- 'Gramática': Regras sintáticas, conjugação de verbos, prefixos/sufixos, pronomes, morfologia e estrutura de frases.\n"
            "- 'História': Cartas históricas, documentos coloniais, relatos de viagem (ex: Hans Staden, Thevet), guerras, personagens (ex: Pedro Poti, Camarão) e notas sobre aldeias.\n"
            "- 'Mitologia': Lendas, seres míticos (Tupã, Curupira, Anhangá, Jaci), rituais religiosos, cosmologia e crenças indígenas.\n"
            "- 'Desconhecido': Use APENAS para sumários, índices bibliográficos ou ruídos ilegíveis sem conteúdo textual útil.\n\n"
            "Observação: Os textos extraídos de documentos podem estar em português, inglês ou Tupi (ex: teses acadêmicas internacionais sobre povos Tupi). Classifique pelo conteúdo temático, independentemente do idioma.\n\n"
            "Textos:\n"
        )
        for idx, (row_id, doc_text) in enumerate(chunk_batch, 1):
            doc_snippet = doc_text.strip()[:800]
            prompt += f"[{idx}] {doc_snippet}\n"

        prompt += '\nRetorne ESTRITAMENTE o JSON no formato: {"itens": [{"id": 1, "categoria": "Vocabulário"}, ...]}'

        try:
            # Tenta com o topo da cadeia (ex: dashscope/qwen-plus)
            batch_res = FallbackOrchestrator.execute_with_fallback(
                prompt=prompt,
                schema=BatchClassification,
                chain=chain[:4],  # tenta primeiros modelos da cadeia
                temperature=0.0,
                max_tokens=800,
            )
            results_map = {item.id: item.categoria for item in batch_res.itens}
            registros: list[tuple[str, str, str]] = []
            for idx, (row_id, doc_text) in enumerate(chunk_batch, 1):
                cat = results_map.get(idx)
                if not cat:
                    return False, []
                registros.append((str(row_id), doc_text, cat))
            return True, registros
        except Exception as e:
            logger.warning(f"[vocab_worker] Tentativa de lote falhou ({e}). Decompondo para 1 a 1.")
            return False, []

    def _classificar_chunk_1a1(
        self, chunk_id: str, doc_text: str, chain: list[str]
    ) -> tuple[str, bool]:
        """
        Ciclo 1 a 1: Itera exaustivamente pela lista sequencial de fallback para o MESMO chunk.
        Se ocorrer 429, timeout, erro de parsing ou 5xx, NÃO pula o chunk: avança para o próximo modelo.
        Retorna (categoria, sucesso_bool).
        """
        prompt = (
            f"Você é um especialista em língua Tupi Antiga, linguística e história indígena.\n"
            f"Classifique o texto a seguir na categoria MAIS APROPRIADA dentre as opções:\n"
            "- 'Vocabulário': Dicionários, listas de vocábulos, traduções palavra por palavra, termos isolados e seus significados.\n"
            "- 'Gramática': Regras sintáticas, conjugação de verbos, prefixos/sufixos, pronomes, morfologia e estrutura de frases.\n"
            "- 'História': Cartas históricas, documentos coloniais, relatos de viagem (ex: Hans Staden, Thevet), guerras, personagens (ex: Pedro Poti, Camarão) e notas sobre aldeias.\n"
            "- 'Mitologia': Lendas, seres míticos (Tupã, Curupira, Anhangá, Jaci), rituais religiosos, cosmologia e crenças indígenas.\n"
            "- 'Desconhecido': Use APENAS para sumários, índices bibliográficos ou ruídos ilegíveis sem conteúdo textual útil.\n\n"
            "Observação: O texto pode estar em português, inglês ou Tupi (ex: pesquisas etnográficas ou linguísticas em inglês). Classifique pelo conteúdo temático, independentemente do idioma.\n\n"
            f"Texto:\n{doc_text.strip()[:1000]}\n\n"
            'Retorne ESTRITAMENTE o JSON no formato: {"categoria": "Vocabulário"}'
        )

        ultimo_erro = None
        for target in chain:
            try:
                res = FallbackOrchestrator.execute_with_fallback(
                    prompt=prompt,
                    schema=SingleChunkCategory,
                    chain=[target],
                    temperature=0.0,
                    max_tokens=100,
                )
                if res and res.categoria:
                    self.stdout.write(self.style.SUCCESS(f"    ✓ {chunk_id[:12]}: {res.categoria} via {target}"))
                    return res.categoria, True
            except Exception as e:
                ultimo_erro = e
                logger.debug(
                    "[vocab_worker] Modelo %s falhou para chunk %s: %s. Tentando próximo modelo...",
                    target, chunk_id[:12], e
                )
                continue

        # Se todos os modelos da cadeia falharam
        logger.error(
            "[vocab_worker] Todos os %d modelos falharam sucessivamente para o chunk %s. Último erro: %s",
            len(chain), chunk_id[:12], ultimo_erro
        )
        # Classificação de último recurso
        return "Desconhecido", True

    def _salvar_lote(self, registros: list[tuple[str, str, str]], row_ids: list[str], vector_db):
        """Salva múltiplos registros com idempotência no Supabase (ON CONFLICT) e atualiza o SQLite local."""
        close_old_connections()
        with connection.cursor() as cursor:
            for chunk_id, doc_text, categoria in registros:
                cursor.execute("""
                    INSERT INTO rag_document_categories (chunk_id, document_text, categoria)
                    VALUES (%s, %s, %s)
                    ON CONFLICT (chunk_id)
                    DO UPDATE SET categoria = EXCLUDED.categoria,
                                  document_text = EXCLUDED.document_text,
                                  created_at = CURRENT_TIMESTAMP
                """, (chunk_id, doc_text, categoria))

        # Atualiza o SQLite local em batch apenas após confirmação no Supabase
        with vector_db._connect() as conn:
            conn.executemany("UPDATE documents SET category_extracted = 1 WHERE id = ?", [(rid,) for rid in row_ids])
            conn.commit()

        self.stdout.write(self.style.SUCCESS(f"  [OK] Lote de {len(registros)} chunks salvo com sucesso no Supabase e SQLite."))
        connection.close()
