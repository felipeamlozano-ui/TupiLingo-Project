-- =============================================================================
-- TupiLingo — Migration 03: Native PostgreSQL Extensions
-- RFC v3.2: pgvector (RAG Semântico), pg_trgm (Fuzzy Matching Global),
--           pg_jsonschema (Validação Estrutural da IA) e unaccent.
--
-- IDEMPOTENTE: Seguro para execuções repetidas.
-- =============================================================================

-- ── SEÇÃO 1: ATIVAÇÃO DE EXTENSÕES NATIVAS ───────────────────────────────────
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS pg_jsonschema;

-- ── SEÇÃO 2: PGVECTOR NO ACERVO RAG & VOCABULÁRIO ────────────────────────────
-- 1. Coluna vetorial de 384 dimensões (FastEmbed / all-MiniLM-L6-v2)
ALTER TABLE rag_document_categories
    ADD COLUMN IF NOT EXISTS embedding vector(384);

ALTER TABLE trilha_vocabularyitem
    ADD COLUMN IF NOT EXISTS embedding vector(384);

-- 2. Índices HNSW ultrarrápidos para busca por similaridade de cosseno (< 3ms)
CREATE INDEX IF NOT EXISTS idx_rag_doc_cat_hnsw
    ON rag_document_categories
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

CREATE INDEX IF NOT EXISTS idx_trilha_vocab_hnsw
    ON trilha_vocabularyitem
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- 3. Índices de Trigramas para busca textual e fuzzy matching
CREATE INDEX IF NOT EXISTS idx_vocabitem_palavra_trgm
    ON trilha_vocabularyitem
    USING gin (palavra_tupi gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_vocabitem_traducao_trgm
    ON trilha_vocabularyitem
    USING gin (traducao_pt gin_trgm_ops);


-- ── SEÇÃO 3: RPC - BUSCA SEMÂNTICA NO RAG VIA PGVECTOR ───────────────────────
CREATE OR REPLACE FUNCTION buscar_chunks_rag_semantico(
    p_embedding   vector(384),
    p_categorias  TEXT[]   DEFAULT NULL,
    p_limite      INTEGER  DEFAULT 3,
    p_threshold   REAL     DEFAULT 0.35
)
RETURNS TABLE (
    id            INTEGER,
    chunk_id      TEXT,
    document_text TEXT,
    categoria     TEXT,
    similaridade  REAL
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
    -- Se embedding for nulo, faz amostragem resiliente por categoria
    IF p_embedding IS NULL THEN
        RETURN QUERY
        SELECT r.id, r.chunk_id, r.document_text, r.categoria, 0.5::REAL AS similaridade
        FROM   rag_document_categories r
        WHERE  (p_categorias IS NULL OR r.categoria = ANY(p_categorias))
          AND  length(r.document_text) > 60
        ORDER BY random()
        LIMIT  p_limite;
        RETURN;
    END IF;

    RETURN QUERY
    SELECT 
        r.id,
        r.chunk_id,
        r.document_text,
        r.categoria,
        (1.0 - (r.embedding <=> p_embedding))::REAL AS similaridade
    FROM rag_document_categories r
    WHERE (p_categorias IS NULL OR r.categoria = ANY(p_categorias))
      AND (r.embedding IS NOT NULL)
      AND (1.0 - (r.embedding <=> p_embedding)) >= p_threshold
    ORDER BY r.embedding <=> p_embedding
    LIMIT p_limite;
END;
$$;

GRANT EXECUTE ON FUNCTION buscar_chunks_rag_semantico(vector(384), TEXT[], INTEGER, REAL)
    TO service_role, anon, authenticated;


-- ── SEÇÃO 4: RPC - VALIDAÇÃO FUZZY GLOBAL VIA PG_TRGM ────────────────────────
CREATE OR REPLACE FUNCTION validar_resposta_fuzzy_trgm(
    p_resposta_usuario  TEXT,
    p_resposta_esperada TEXT,
    p_limiar_correto    REAL DEFAULT 0.90,
    p_limiar_quase      REAL DEFAULT 0.65
)
RETURNS TABLE (
    status           TEXT,
    similaridade     REAL,
    resposta_correta TEXT,
    mensagem         TEXT
)
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_norm_u TEXT;
    v_norm_e TEXT;
    v_sim    REAL;
BEGIN
    v_norm_u := lower(unaccent(trim(COALESCE(p_resposta_usuario, ''))));
    v_norm_e := lower(unaccent(trim(COALESCE(p_resposta_esperada, ''))));

    IF v_norm_u = '' OR v_norm_e = '' THEN
        RETURN QUERY SELECT 'wrong'::TEXT, 0.0::REAL, p_resposta_esperada, 'Resposta vazia.'::TEXT;
        RETURN;
    END IF;

    -- Correspondência exata normalizada (sem diacríticos, caixa baixa)
    IF v_norm_u = v_norm_e THEN
        RETURN QUERY SELECT 'correct'::TEXT, 1.0::REAL, p_resposta_esperada, 'Correto! 🎉'::TEXT;
        RETURN;
    END IF;

    -- Cálculo de similaridade trigram
    v_sim := similarity(v_norm_u, v_norm_e);

    IF v_sim >= p_limiar_correto THEN
        RETURN QUERY SELECT 'correct'::TEXT, v_sim, p_resposta_esperada, 'Correto! 🎉'::TEXT;
    ELSIF v_sim >= p_limiar_quase THEN
        RETURN QUERY SELECT 
            'almost'::TEXT, 
            v_sim, 
            p_resposta_esperada, 
            format('Quase lá! Faltou uma letra ou acento em "%s". Você digitou "%s".', p_resposta_esperada, p_resposta_usuario);
    ELSE
        RETURN QUERY SELECT 
            'wrong'::TEXT, 
            v_sim, 
            p_resposta_esperada, 
            format('Incorreto. A resposta correta era: "%s".', p_resposta_esperada);
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION validar_resposta_fuzzy_trgm(TEXT, TEXT, REAL, REAL)
    TO service_role, anon, authenticated;


-- ── SEÇÃO 5: RPC - VALIDAÇÃO ESTRUTURAL DE PAYLOAD VIA PG_JSONSCHEMA ─────────
CREATE OR REPLACE FUNCTION validar_quiz_payload_jsonschema(
    p_payload JSONB
)
RETURNS TABLE (
    valido BOOLEAN,
    erros  TEXT
)
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_schema JSONB := '{
        "type": "object",
        "required": ["questoes"],
        "properties": {
            "questoes": {
                "type": "array",
                "minItems": 1,
                "items": {
                    "type": "object",
                    "required": ["id", "tipo", "enunciado", "explicacao"],
                    "properties": {
                        "id": {"type": "integer"},
                        "tipo": {
                            "type": "string",
                            "enum": ["escolha_multipla", "completar", "associacao", "traducao_livre"]
                        },
                        "enunciado": {"type": "string", "minLength": 5},
                        "explicacao": {"type": "string", "minLength": 3}
                    }
                }
            }
        }
    }'::jsonb;
    v_is_valid BOOLEAN := FALSE;
    v_validation_err TEXT := NULL;
BEGIN
    -- Executa validação caso pg_jsonschema esteja disponível
    BEGIN
        v_is_valid := jsonb_matches_schema(v_schema, p_payload);
        IF NOT v_is_valid THEN
            v_validation_err := 'Payload viola o schema contratual de questões.';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        -- Fallback de formato defensivo se a extensão pg_jsonschema não estiver ativa no nó
        v_is_valid := (
            p_payload IS NOT NULL 
            AND p_payload ? 'questoes' 
            AND jsonb_typeof(p_payload->'questoes') = 'array'
            AND jsonb_array_length(p_payload->'questoes') > 0
        );
        IF NOT v_is_valid THEN
            v_validation_err := 'Payload inválido: formato básico incorreto.';
        END IF;
    END;

    RETURN QUERY SELECT v_is_valid, v_validation_err;
END;
$$;

GRANT EXECUTE ON FUNCTION validar_quiz_payload_jsonschema(JSONB)
    TO service_role, anon, authenticated;
