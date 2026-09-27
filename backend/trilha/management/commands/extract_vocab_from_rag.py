import json
import logging
import os
import re
import time
from typing import Literal, List, Tuple, Dict, Any, Optional
from django.core.management.base import BaseCommand
from django.db import connection, transaction, close_old_connections
from pydantic import BaseModel, Field, ValidationError

from app.ai.rag_service import get_db
from app.ai.router import ModelRouter
from app.ai.fallback import FallbackOrchestrator, AllModelsUnavailableError
from app.ai.ping_race import PingRaceRouter

logger = logging.getLogger("nivelamento.etl")

# ==============================================================================
# TAXONOMIA FECHADA (6 CATEGORIAS OFICIAIS — ZERO DESCONHECIDO)
# ==============================================================================
VALID_CATEGORIES = ("Vocabulário", "Gramática", "História", "Mitologia", "Toponímia", "Geral")
CategoryType = Literal["Vocabulário", "Gramática", "História", "Mitologia", "Toponímia", "Geral"]


class ItemCategory(BaseModel):
    id: int
    categoria: CategoryType = Field(..., description="Uma das 6 categorias oficiais da taxonomia fechada.")
    confianca: float = Field(default=0.95, ge=0.0, le=1.0, description="Nível de confiança da classificação (0.0 a 1.0).")


class BatchClassification(BaseModel):
    itens: List[ItemCategory]


class SingleChunkCategory(BaseModel):
    categoria: CategoryType = Field(..., description="Uma das 6 categorias oficiais da taxonomia fechada.")
    confianca: float = Field(default=0.95, ge=0.0, le=1.0, description="Nível de confiança da classificação (0.0 a 1.0).")


# ==============================================================================
# FALLBACK HEURÍSTICO REGEX DETERMINÍSTICO (ÚLTIMO RECURSO, MARCADO E NÃO-SILENCIOSO)
# ==============================================================================
def classificar_heuristico_regex(texto: str) -> tuple[str, float]:
    """
    Fallback determinístico baseado em regex quando todos os LLMs da cadeia falharem.
    
    ORDEM ESTRITA DE PRIORIDADE DELIBERADA (Regra 4.2):
      1. Gramática: regras morfossintáticas, conjugação verbal, posposições e pronomes (estrutural).
      2. Vocabulário: dicionários, glossários, verbetes, léxico e traduções diretas.
      3. Mitologia: cosmologia indígena, divindades, seres míticos, pajelança e rituais sagrados.
      4. Toponímia: nomes próprios de rios, serras, aldeias e acidentes geográficos indígenas.
      5. História: relatos de cronistas (Hans Staden, Thevet, L在本ry), cartas jesuíticas e guerras.
      6. Geral: ensaios antropológicos modernos, introduções e contexto etnográfico geral.
      
    Todo chunk classificado por esta função recebe confianca=0.3 e precisa_revisao=True.
    """
    txt = texto.lower()

    # 1. GRAMÁTICA (Prioridade 1)
    if re.search(
        r'\b(gram[aá]tica|sintaxe|morfolo|conjuga|prefixo|sufixo|pronome|posposi|part[ií]cula|'
        r'flex[aã]o|adjetiv|substantiv|verbo|transitividade|sintagma|ergativ|incorporação|marcador)\b',
        txt
    ):
        return "Gramática", 0.3

    # 2. VOCABULÁRIO (Prioridade 2)
    if re.search(
        r'\b(vocabul[aá]rio|dicion[aá]rio|gloss[aá]rio|l[eé]xico|significa|tradu[çc]|termo[s]?\s*:\s*|'
        r'verbete|palavra[s]?\b|sin[oô]nimo|nomenclatura|lexema|entrada)\b',
        txt
    ):
        return "Vocabulário", 0.3

    # 3. MITOLOGIA (Prioridade 3)
    if re.search(
        r'\b(tup[aã]|curupira|anhang[aá]|jaci|caipora|boitat[aá]|mitolog|lenda|cosmolog|ritual|'
        r'paj[eé]|pajelan|xam[aã]|cren[çc]a|sobrenatural|esp[ií]rito|jurupari|monan|sum[eé])\b',
        txt
    ):
        return "Mitologia", 0.3

    # 4. TOPONÍMIA (Prioridade 4)
    if re.search(
        r'\b(topon[ií]mia|top[oô]nimo|rio\s+[a-z]+|igarap[eé]|paran[aá]|itapema|pindorama|'
        r'serra\s+[a-z]+|ilha\s+[a-z]+|aldeia\s+[a-z]+|lugar|regi[aã]o|acidente\s+geogr[aá]fico|localidade)\b',
        txt
    ):
        return "Toponímia", 0.3

    # 5. HISTÓRIA (Prioridade 5)
    if re.search(
        r'\b(hist[oó]ria|hans\s+staden|thevet|jean\s+de\s+l[eé]ry|anchieta|n[oó]brega|poti|camar[aã]o|'
        r's[eé]culo\s+(xvi|xvii|xviii)|colonial|coloniza[çc]|guerra|jesu[ií]ta|cronista|expedi[çc]|capitania)\b',
        txt
    ):
        return "História", 0.3

    # 6. GERAL (Fallback padrão da taxonomia fechada)
    return "Geral", 0.3


def tentar_parse_tolerante(raw_content: str) -> Optional[Any]:
    """Tenta extrair e decodificar JSON tolerante a markdown, think tags e pontuação espúria."""
    content = re.sub(r'<think>.*?</think>', '', raw_content, flags=re.DOTALL).strip()
    try:
        return json.loads(content)
    except Exception:
        pass

    match = re.search(r'```(?:json)?\s*([\[\{].*?[\]\}])\s*```', content, re.DOTALL)
    if match:
        try:
            return json.loads(match.group(1))
        except Exception:
            pass

    match_braces = re.search(r'(\{.*\})', content, re.DOTALL) or re.search(r'(\[.*\])', content, re.DOTALL)
    if match_braces:
        try:
            return json.loads(match_braces.group(1))
        except Exception:
            pass

    return None


class Command(BaseCommand):
    help = (
        "Varre o banco vetorial SQLite (GraphRAG), classifica os chunks na taxonomia fechada de 6 categorias "
        "com FallbackOrchestrator resiliente, persistência de metadados de proveniência (LLM vs Heurístico) "
        "e garantia de idempotência no Supabase e SQLite."
    )

    def add_arguments(self, parser):
        parser.add_argument('--limit', type=int, default=50, help='Limite de chunks buscados por ciclo.')
        parser.add_argument('--offset', type=int, default=0, help='Offset para buscar chunks.')
        parser.add_argument('--batch-size', type=int, default=10, help='Tamanho do lote para tentativa inicial de batch.')
        parser.add_argument('--continuous', action='store_true', help='Executa em loop contínuo como worker.')
        parser.add_argument('--reprocess-all', action='store_true', help='Reprocessa todos os chunks ignorando category_extracted=1.')
        parser.add_argument('--reprocess-heuristic', action='store_true', help='Reprocessa apenas chunks classificados por heurística de baixa confiança.')

    def handle(self, *args, **options):
        limit = options['limit']
        offset = options['offset']
        batch_size = options['batch_size']
        continuous = options['continuous']
        reprocess_all = options['reprocess_all']
        reprocess_heuristic = options['reprocess_heuristic']

        self.stdout.write(self.style.NOTICE(
            f"=== Iniciando ETL de Classificação de Chunks RAG (TupiLingo) ===\n"
            f"Batch: {batch_size} | Limit: {limit} | Continuous: {continuous}\n"
            f"Reprocess All: {reprocess_all} | Reprocess Heuristic: {reprocess_heuristic}"
        ))

        vector_db = get_db()
        self._ensure_database_schemas(vector_db)

        if reprocess_all:
            with vector_db._connect() as conn:
                conn.execute("UPDATE documents SET category_extracted = 0")
                conn.commit()
            self.stdout.write(self.style.WARNING("Flag --reprocess-all ativa: todos os chunks marcados com category_extracted=0 no SQLite."))

        chain = ModelRouter.get_chain_for_task("vocab_extraction_cloud")
        self.stdout.write(self.style.SUCCESS(f"Cadeia de inferência configurada com {len(chain)} modelos:"))
        for idx, m in enumerate(chain, 1):
            is_fatal = PingRaceRouter.is_fatal_disabled(m)
            status_tag = " [FATAL 24h]" if is_fatal else ""
            self.stdout.write(f"  [{idx}] {m}{status_tag}")

        total_processados = 0
        distribuicao_categorias = {cat: 0 for cat in VALID_CATEGORIES}
        metodos_contagem = {"llm": 0, "heuristico": 0}

        while True:
            # 1. Busca chunks pendentes de classificação no SQLite
            with vector_db._connect() as conn:
                if reprocess_heuristic:
                    query = (
                        "SELECT id, document FROM documents "
                        "WHERE precisa_revisao = 1 OR metodo_classificacao = 'heuristico' "
                        "ORDER BY created_at DESC LIMIT ? OFFSET ?"
                    )
                else:
                    query = (
                        "SELECT id, document FROM documents "
                        "WHERE category_extracted = 0 "
                        "ORDER BY created_at DESC LIMIT ? OFFSET ?"
                    )
                rows = conn.execute(query, (limit, offset)).fetchall()

            if not rows:
                if continuous:
                    self.stdout.write(self.style.WARNING("Nenhum chunk pendente. Aguardando 10min (600s) para nova checagem..."))
                    time.sleep(600)
                    continue
                else:
                    self.stdout.write(self.style.SUCCESS("[OK] Nenhum chunk pendente de classificação no RAG."))
                    break

            self.stdout.write(self.style.NOTICE(f"\nProcessando {len(rows)} chunks pendentes..."))

            # 2. Processamento em lotes com fallback 1 a 1 para IDs faltantes
            for i in range(0, len(rows), batch_size):
                chunk_batch = rows[i : i + batch_size]
                batch_len = len(chunk_batch)

                # Estrutura: list[tuple[chunk_id, doc_text, categoria, metodo, confianca, precisa_revisao]]
                registros_salvar: list[tuple[str, str, str, str, float, bool]] = []
                ids_resolvidos: set[str] = set()

                if batch_len > 1:
                    self.stdout.write(f"\n-> Tentando lote de {batch_len} chunks (IDs: {chunk_batch[0][0][:10]}..{chunk_batch[-1][0][:10]})...")
                    lote_ok, resultados_lote = self._tentar_classificar_lote(chunk_batch, chain)
                    if lote_ok and resultados_lote:
                        for reg in resultados_lote:
                            registros_salvar.append(reg)
                            ids_resolvidos.add(reg[0])
                        self.stdout.write(self.style.SUCCESS(f"   [OK] Lote completo classificado com sucesso ({len(resultados_lote)} chunks)."))

                # 3. Processamento individual para chunks faltantes ou quando lote falhou
                chunks_restantes = [c for c in chunk_batch if c[0] not in ids_resolvidos]
                if chunks_restantes:
                    if batch_len > 1:
                        self.stdout.write(self.style.WARNING(
                            f"   Processando {len(chunks_restantes)} chunks individualmente via FallbackOrchestrator..."
                        ))
                    for chunk_id, doc_text in chunks_restantes:
                        cat, metodo, conf, precisa_rev = self._classificar_chunk_1a1(chunk_id, doc_text, chain)
                        registros_salvar.append((str(chunk_id), doc_text, cat, metodo, conf, precisa_rev))

                # 4. Salva com idempotência no Supabase e atualiza SQLite local
                if registros_salvar:
                    self._salvar_lote(registros_salvar, vector_db)
                    total_processados += len(registros_salvar)
                    for _, _, cat, metodo, _, _ in registros_salvar:
                        distribuicao_categorias[cat] = distribuicao_categorias.get(cat, 0) + 1
                        metodos_contagem[metodo] = metodos_contagem.get(metodo, 0) + 1

                time.sleep(0.1)

            self.stdout.write(self.style.SUCCESS(
                f"\nCiclo concluído. Total processado: {total_processados} chunks.\n"
                f"Métodos: LLM={metodos_contagem['llm']} | Heurístico={metodos_contagem['heuristico']}\n"
                f"Distribuição de categorias: {distribuicao_categorias}"
            ))

            if not continuous:
                break

        # Exibe métricas de telemetria do PingRaceRouter
        metrics = PingRaceRouter.get_circuit_metrics()
        self.stdout.write(self.style.NOTICE(f"\n=== Telemetria de Circuit Breakers por Provedor ===\n{json.dumps(metrics, indent=2, ensure_ascii=False)}"))

    def _ensure_database_schemas(self, vector_db):
        """Garante a integridade dos schemas no SQLite e no PostgreSQL / Supabase."""
        # 1. SQLite: Adiciona colunas se não existirem
        with vector_db._connect() as conn:
            cursor = conn.cursor()
            existing_cols = [row[1] for row in cursor.execute("PRAGMA table_info(documents)").fetchall()]
            
            novas_colunas = [
                ("category_extracted", "INTEGER DEFAULT 0"),
                ("categoria", "TEXT"),
                ("metodo_classificacao", "TEXT DEFAULT 'llm'"),
                ("confianca", "REAL DEFAULT 1.0"),
                ("precisa_revisao", "INTEGER DEFAULT 0"),
            ]
            for col_name, col_def in novas_colunas:
                if col_name not in existing_cols:
                    try:
                        cursor.execute(f"ALTER TABLE documents ADD COLUMN {col_name} {col_def}")
                    except Exception:
                        pass
            conn.commit()

        # 2. PostgreSQL / Supabase
        close_old_connections()
        with connection.cursor() as cursor:
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS rag_document_categories (
                    id SERIAL PRIMARY KEY,
                    chunk_id TEXT NOT NULL,
                    document_text TEXT NOT NULL,
                    categoria TEXT NOT NULL,
                    metodo_classificacao TEXT NOT NULL DEFAULT 'llm',
                    confianca DOUBLE PRECISION NOT NULL DEFAULT 1.0,
                    precisa_revisao BOOLEAN NOT NULL DEFAULT FALSE,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
                )
            """)
            cursor.execute("""
                CREATE UNIQUE INDEX IF NOT EXISTS idx_rag_document_categories_chunk_id 
                ON rag_document_categories (chunk_id)
            """)
            # Migrações idempotentes de colunas em bases já existentes
            for col, dtype, default in [
                ("metodo_classificacao", "TEXT", "'llm'"),
                ("confianca", "DOUBLE PRECISION", "1.0"),
                ("precisa_revisao", "BOOLEAN", "FALSE"),
            ]:
                cursor.execute(f"""
                    DO $$ 
                    BEGIN 
                        IF NOT EXISTS (
                            SELECT 1 FROM information_schema.columns 
                            WHERE table_name='rag_document_categories' AND column_name='{col}'
                        ) THEN 
                            ALTER TABLE rag_document_categories ADD COLUMN {col} {dtype} DEFAULT {default}; 
                        END IF; 
                    END $$;
                """)
        connection.close()

    def _tentar_classificar_lote(
        self, chunk_batch: list[tuple[str, str]], chain: list[str]
    ) -> tuple[bool, list[tuple[str, str, str, str, float, bool]]]:
        """
        Classifica um lote de chunks na taxonomia fechada de 6 categorias.
        Valida correspondência ID->Categoria. Retorna apenas IDs com categorização estritamente válida.
        """
        batch_len = len(chunk_batch)
        prompt = (
            f"Você é um especialista em línguas Tupi (Tupi Antigo, Contemporâneo, Tupinambá, Kamaiurá) e linguística indígena.\n"
            f"Classifique cada um dos {batch_len} textos numerados a seguir em EXATAMENTE UMA das 6 categorias oficiais abaixo:\n"
            "1. 'Vocabulário': Listas de palavras, traduções termo a termo, glossários, verbetes, léxico e significados.\n"
            "2. 'Gramática': Regras sintáticas, flexão e conjugação verbal, pronomes, prefixos, sufixos, posposições e morfologia.\n"
            "3. 'História': Documentos coloniais, cartas de personagens históricos (Pedro Poti, Camarão), relatos de viajantes (Hans Staden, Thevet) e guerras.\n"
            "4. 'Mitologia': Cosmologia, crenças sagradas, lendas, pajelança, rituais e seres míticos (Tupã, Curupira, Anhangá, Jaci).\n"
            "5. 'Toponímia': Nomes de lugares, rios, aldeias, serras, acidentes geográficos e etimologia de nomes geográficos de origem Tupi.\n"
            "6. 'Geral': Contextualização etnográfica geral, antropologia moderna, notas bibliográficas ou visão panorâmica.\n\n"
            "REGRA MANDATÓRIA: NUNCA retorne 'Desconhecido'. Se o texto for difícil, classifique como 'Geral'.\n\n"
            "Textos a classificar:\n"
        )
        id_to_doc = {}
        for idx, (row_id, doc_text) in enumerate(chunk_batch, 1):
            doc_snippet = doc_text.strip()[:600]
            id_to_doc[idx] = (row_id, doc_text)
            prompt += f"[{idx}] {doc_snippet}\n"

        prompt += '\nRetorne ESTRITAMENTE o JSON no formato: {"itens": [{"id": 1, "categoria": "Vocabulário", "confianca": 0.95}, ...]}'

        try:
            batch_res = FallbackOrchestrator.execute_with_fallback(
                prompt=prompt,
                schema=BatchClassification,
                chain=chain,
                temperature=0.0,
                max_tokens=900,
            )
            registros: list[tuple[str, str, str, str, float, bool]] = []
            for item in batch_res.itens:
                if item.id in id_to_doc and item.categoria in VALID_CATEGORIES:
                    row_id, doc_text = id_to_doc[item.id]
                    registros.append((str(row_id), doc_text, item.categoria, "llm", item.confianca, False))

            # Verifica se todos os IDs solicitados vieram no retorno
            if len(registros) == batch_len:
                return True, registros
            elif len(registros) > 0:
                # Lote parcial: aceita os resolvidos e delega os faltantes para 1 a 1
                return True, registros
            return False, []

        except Exception as e:
            logger.warning(f"[vocab_worker] Lote falhou via FallbackOrchestrator ({type(e).__name__}: {e}). Decompondo para 1 a 1.")
            return False, []

    def _classificar_chunk_1a1(
        self, chunk_id: str, doc_text: str, chain: list[str]
    ) -> tuple[str, str, float, bool]:
        """
        Classifica um chunk individual com failover exaustivo pelos LLMs.
        Se toda a cadeia falhar, aplica o fallback heurístico determinístico (Regra 4.2).
        Retorna: (categoria, metodo_classificacao, confianca, precisa_revisao).
        """
        prompt = (
            f"Você é um especialista em línguas Tupi e linguística indígena.\n"
            f"Classifique o texto a seguir em EXATAMENTE UMA das 6 categorias oficiais:\n"
            "- 'Vocabulário': Listas de palavras, traduções, glossários, verbetes, termos e significados.\n"
            "- 'Gramática': Regras sintáticas, conjugação verbal, pronomes, prefixos, sufixos, posposições e morfologia.\n"
            "- 'História': Documentos coloniais, cartas históricas, relatos de viajantes, conflitos e personagens.\n"
            "- 'Mitologia': Cosmologia, crenças sagradas, lendas, rituais, pajelança e seres míticos.\n"
            "- 'Toponímia': Nomes de lugares, rios, aldeias, serras e geografia de origem Tupi.\n"
            "- 'Geral': Contextualização etnográfica geral, antropologia moderna ou notas bibliográficas.\n\n"
            "REGRA MANDATÓRIA: NUNCA retorne 'Desconhecido'. Se houver dúvida, escolha 'Geral'.\n\n"
            f"Texto:\n{doc_text.strip()[:1000]}\n\n"
            'Retorne ESTRITAMENTE o JSON no formato: {"categoria": "Vocabulário", "confianca": 0.95}'
        )

        try:
            res = FallbackOrchestrator.execute_with_fallback(
                prompt=prompt,
                schema=SingleChunkCategory,
                chain=chain,
                temperature=0.0,
                max_tokens=120,
            )
            if res and res.categoria in VALID_CATEGORIES:
                self.stdout.write(self.style.SUCCESS(f"    [OK] {chunk_id[:12]}: {res.categoria} (LLM, conf={res.confianca:.2f})"))
                return res.categoria, "llm", res.confianca, False

        except Exception as e:
            logger.warning(
                "[vocab_worker] Falha total na cadeia LLM para o chunk %s (%s). Ativando fallback heurístico...",
                chunk_id[:12], type(e).__name__
            )

        # Fallback Heurístico Regex (Último recurso, marcado com precisa_revisao=True)
        cat_heuristica, conf_heuristica = classificar_heuristico_regex(doc_text)
        self.stdout.write(self.style.WARNING(
            f"    [HEURISTICO] {chunk_id[:12]}: {cat_heuristica} [regex, conf={conf_heuristica:.2f} -> FILA DE REVISÃO]"
        ))
        return cat_heuristica, "heuristico", conf_heuristica, True

    def _salvar_lote(
        self,
        registros: list[tuple[str, str, str, str, float, bool]],
        vector_db
    ) -> None:
        """Salva múltiplos registros com idempotência no Supabase (ON CONFLICT) e atualiza o SQLite local."""
        close_old_connections()
        with connection.cursor() as cursor:
            for chunk_id, doc_text, categoria, metodo, confianca, precisa_revisao in registros:
                cursor.execute("""
                    INSERT INTO rag_document_categories (
                        chunk_id, document_text, categoria, metodo_classificacao, confianca, precisa_revisao
                    )
                    VALUES (%s, %s, %s, %s, %s, %s)
                    ON CONFLICT (chunk_id)
                    DO UPDATE SET categoria = EXCLUDED.categoria,
                                  document_text = EXCLUDED.document_text,
                                  metodo_classificacao = EXCLUDED.metodo_classificacao,
                                  confianca = EXCLUDED.confianca,
                                  precisa_revisao = EXCLUDED.precisa_revisao,
                                  created_at = CURRENT_TIMESTAMP
                """, (chunk_id, doc_text, categoria, metodo, confianca, precisa_revisao))

        # Atualiza o SQLite local com as colunas de proveniência
        sqlite_params = [
            (categoria, metodo, confianca, 1 if precisa_revisao else 0, chunk_id)
            for chunk_id, _, categoria, metodo, confianca, precisa_revisao in registros
        ]
        with vector_db._connect() as conn:
            conn.executemany("""
                UPDATE documents 
                SET category_extracted = 1,
                    categoria = ?,
                    metodo_classificacao = ?,
                    confianca = ?,
                    precisa_revisao = ?
                WHERE id = ?
            """, sqlite_params)
            conn.commit()

        self.stdout.write(self.style.SUCCESS(f"  [OK] Lote de {len(registros)} chunks salvo com idempotência no Supabase e SQLite."))
        connection.close()
