-- =============================================================================
-- TupiLingo — Migration 04: Semantic Cache, pg_prewarm, pgmq, Supabase Vault & SRS
-- =============================================================================

-- ── 1. EXPANSÃO DE CAMPOS DO USUÁRIO ─────────────────────────────────────────
ALTER TABLE users_userprofile
    ADD COLUMN IF NOT EXISTS conchas INTEGER NOT NULL DEFAULT 0;

-- ── 2. ATIVAÇÃO DE EXTENSÕES NATIVAS ──────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_prewarm;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;

-- Tentativa segura de ativar pgmq e pgsodium (se disponíveis no ambiente Supabase)
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pgmq;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Extensão pgmq não disponível ou sem privilégios: %', SQLERRM;
END $$;

DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pgsodium;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Extensão pgsodium não disponível ou sem privilégios: %', SQLERRM;
END $$;


-- ── 3. CACHE SEMÂNTICO DE TEMAS COM PGVECTOR ─────────────────────────────────
CREATE TABLE IF NOT EXISTS ai_thematic_semantic_cache (
    id            BIGSERIAL PRIMARY KEY,
    tema          TEXT NOT NULL,
    variante_id   INTEGER REFERENCES trilha_variantetupi(id) ON DELETE CASCADE,
    embedding     vector(384) NOT NULL,
    questoes      JSONB NOT NULL,
    termos_srs    JSONB NOT NULL DEFAULT '[]'::jsonb,
    hit_count     INTEGER NOT NULL DEFAULT 1,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_hit_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_thematic_cache_embedding_hnsw
    ON ai_thematic_semantic_cache
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

CREATE INDEX IF NOT EXISTS idx_thematic_cache_variante
    ON ai_thematic_semantic_cache (variante_id, last_hit_at DESC);

-- RPC: Busca no Cache Semântico (> 0.95 similaridade de cosseno)
CREATE OR REPLACE FUNCTION buscar_cache_semantico_tematico(
    p_embedding   vector(384),
    p_variante_id INTEGER,
    p_threshold   DOUBLE PRECISION DEFAULT 0.95
)
RETURNS TABLE (
    cache_id         BIGINT,
    tema             TEXT,
    questoes         JSONB,
    termos_srs       JSONB,
    similaridade     DOUBLE PRECISION
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH matches AS (
        SELECT
            c.id,
            c.tema,
            c.questoes,
            c.termos_srs,
            (1.0 - (c.embedding <=> p_embedding)) AS sim
        FROM ai_thematic_semantic_cache c
        WHERE (p_variante_id IS NULL OR c.variante_id = p_variante_id)
          AND (1.0 - (c.embedding <=> p_embedding)) >= p_threshold
        ORDER BY sim DESC
        LIMIT 1
    )
    SELECT
        m.id AS cache_id,
        m.tema,
        m.questoes,
        m.termos_srs,
        m.sim AS similaridade
    FROM matches m;

    -- Atualiza estatística de hits se encontrou
    UPDATE ai_thematic_semantic_cache
    SET hit_count = hit_count + 1,
        last_hit_at = NOW()
    WHERE id = (
        SELECT c.id FROM ai_thematic_semantic_cache c
        WHERE (p_variante_id IS NULL OR c.variante_id = p_variante_id)
          AND (1.0 - (c.embedding <=> p_embedding)) >= p_threshold
        ORDER BY (1.0 - (c.embedding <=> p_embedding)) DESC
        LIMIT 1
    );
END;
$$;


-- ── 4. AUDITORIA DE RESPOSTAS & FILA NATIVA PGMQ ──────────────────────────────
CREATE TABLE IF NOT EXISTS users_historicoresposta (
    id                 BIGSERIAL PRIMARY KEY,
    user_id            INTEGER NOT NULL REFERENCES users_userprofile(id) ON DELETE CASCADE,
    vocabulary_item_id INTEGER REFERENCES trilha_vocabularyitem(id) ON DELETE SET NULL,
    palavra_tupi       VARCHAR(200) NOT NULL,
    traducao_pt        VARCHAR(200),
    status             VARCHAR(20) NOT NULL, -- 'correct', 'almost', 'wrong'
    similaridade       DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    time_taken_seconds DOUBLE PRECISION NOT NULL DEFAULT 0.0,
    origem             VARCHAR(50) NOT NULL DEFAULT 'pratica_tematica',
    created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_histresp_user_status
    ON users_historicoresposta (user_id, status);

CREATE INDEX IF NOT EXISTS idx_histresp_palavra
    ON users_historicoresposta (palavra_tupi);

CREATE INDEX IF NOT EXISTS idx_histresp_created_at
    ON users_historicoresposta (created_at DESC);

-- Inicializa fila pgmq (se a extensão estiver disponível)
DO $$
BEGIN
    PERFORM pgmq.create('queue_historico_respostas');
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pgmq.create ignorado: %', SQLERRM;
END $$;

-- RPC: Enfileira lote de histórico para descarregamento assíncrono (< 2ms)
CREATE OR REPLACE FUNCTION enfileirar_respostas_pgmq(p_batch JSONB)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    item JSONB;
BEGIN
    -- Se pgmq estiver disponível, envia mensagem
    BEGIN
        PERFORM pgmq.send('queue_historico_respostas', p_batch);
        RETURN TRUE;
    EXCEPTION WHEN OTHERS THEN
        -- Fallback: grava diretamente de forma resiliente
        FOR item IN SELECT * FROM jsonb_array_elements(p_batch)
        LOOP
            INSERT INTO users_historicoresposta (
                user_id,
                vocabulary_item_id,
                palavra_tupi,
                traducao_pt,
                status,
                similaridade,
                time_taken_seconds,
                origem,
                created_at
            ) VALUES (
                (item->>'user_id')::INTEGER,
                (item->>'vocabulary_item_id')::INTEGER,
                COALESCE(item->>'palavra_tupi', 'desconhecido'),
                item->>'traducao_pt',
                COALESCE(item->>'status', 'wrong'),
                COALESCE((item->>'similaridade')::DOUBLE PRECISION, 0.0),
                COALESCE((item->>'time_taken_seconds')::DOUBLE PRECISION, 0.0),
                COALESCE(item->>'origem', 'pratica_tematica'),
                NOW()
            );
        END LOOP;
        RETURN TRUE;
    END;
END;
$$;

-- Função de dreno da fila pgmq (worker background ou cron)
CREATE OR REPLACE FUNCTION drenar_fila_historico_pgmq(p_batch_size INTEGER DEFAULT 50)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    msg RECORD;
    item JSONB;
    v_processados INTEGER := 0;
BEGIN
    FOR msg IN
        SELECT msg_id, read_ct, message
        FROM pgmq.read('queue_historico_respostas', 30, p_batch_size)
    LOOP
        FOR item IN SELECT * FROM jsonb_array_elements(msg.message)
        LOOP
            INSERT INTO users_historicoresposta (
                user_id,
                vocabulary_item_id,
                palavra_tupi,
                traducao_pt,
                status,
                similaridade,
                time_taken_seconds,
                origem,
                created_at
            ) VALUES (
                (item->>'user_id')::INTEGER,
                (item->>'vocabulary_item_id')::INTEGER,
                COALESCE(item->>'palavra_tupi', 'desconhecido'),
                item->>'traducao_pt',
                COALESCE(item->>'status', 'wrong'),
                COALESCE((item->>'similaridade')::DOUBLE PRECISION, 0.0),
                COALESCE((item->>'time_taken_seconds')::DOUBLE PRECISION, 0.0),
                COALESCE(item->>'origem', 'pratica_tematica'),
                NOW()
            );
            v_processados := v_processados + 1;
        END LOOP;

        PERFORM pgmq.delete('queue_historico_respostas', msg.msg_id);
    END LOOP;

    RETURN v_processados;
EXCEPTION WHEN OTHERS THEN
    RETURN 0;
END;
$$;


-- ── 5. REPETIÇÃO ESPAÇADA (SRS): MAPEAMENTO DE FRAQUEZAS ──────────────────────
-- Visão em tempo real (dados instantâneos da lição anterior)
CREATE OR REPLACE VIEW v_user_vocabulary_weaknesses AS
SELECT
    hr.user_id,
    COALESCE(vi.id, MIN(hr.vocabulary_item_id)) AS item_id,
    COALESCE(vi.palavra_tupi, hr.palavra_tupi) AS palavra_tupi,
    COALESCE(vi.traducao_pt, MIN(hr.traducao_pt)) AS traducao_pt,
    COALESCE(vi.categoria, 'geral') AS categoria,
    COUNT(*) FILTER (WHERE hr.status IN ('wrong', 'almost')) AS total_erros,
    COUNT(*) FILTER (WHERE hr.status = 'wrong') AS total_wrong,
    COUNT(*) FILTER (WHERE hr.status = 'almost') AS total_almost,
    COUNT(*) AS total_tentativas,
    AVG(hr.similaridade) AS media_similaridade_trgm,
    MAX(hr.created_at) AS ultimo_erro_em
FROM users_historicoresposta hr
LEFT JOIN trilha_vocabularyitem vi ON (
    hr.vocabulary_item_id = vi.id
    OR lower(trim(hr.palavra_tupi)) = lower(trim(vi.palavra_tupi))
)
WHERE hr.status IN ('wrong', 'almost')
GROUP BY hr.user_id, COALESCE(vi.id, hr.vocabulary_item_id), COALESCE(vi.palavra_tupi, hr.palavra_tupi), COALESCE(vi.traducao_pt, hr.traducao_pt), COALESCE(vi.categoria, 'geral');

-- Materialized View para agregação sob alta carga
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_user_vocabulary_weaknesses AS
SELECT * FROM v_user_vocabulary_weaknesses;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_user_vocab_weakness
    ON mv_user_vocabulary_weaknesses (user_id, palavra_tupi);

CREATE INDEX IF NOT EXISTS idx_mv_weakness_ranking
    ON mv_user_vocabulary_weaknesses (user_id, total_erros DESC, ultimo_erro_em DESC);

-- RPC: Obtém os termos mais fracos específicos do usuário para injeção no prompt
CREATE OR REPLACE FUNCTION get_user_weakest_vocabulary(
    p_user_id INTEGER,
    p_limit   INTEGER DEFAULT 3
)
RETURNS TABLE (
    item_id      BIGINT,
    palavra_tupi VARCHAR(200),
    traducao_pt  VARCHAR(200),
    categoria    VARCHAR(100),
    total_erros  BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    -- 1. Tenta buscar da visão de histórico de erros
    SELECT
        w.item_id::BIGINT,
        w.palavra_tupi::VARCHAR(200),
        w.traducao_pt::VARCHAR(200),
        w.categoria::VARCHAR(100),
        w.total_erros::BIGINT
    FROM v_user_vocabulary_weaknesses w
    WHERE w.user_id = p_user_id
    ORDER BY w.total_erros DESC, w.ultimo_erro_em DESC
    LIMIT p_limit;

    -- Se não encontrar nenhum ou menos do que o limite, a camada Django
    -- complementará usando o SM-2 (users_vocabularyprogress) ou termos da variante.
END;
$$;


-- ── 6. SUPABASE VAULT (PGSODIUM) ──────────────────────────────────────────────
-- Permite leitura descriptografada segura em tempo de execução via backend
CREATE OR REPLACE FUNCTION get_secret(secret_name TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    secret_val TEXT;
BEGIN
    -- Se a tabela vault.decrypted_secrets existir, lê o segredo
    BEGIN
        SELECT decrypted_secret INTO secret_val
        FROM vault.decrypted_secrets
        WHERE name = secret_name;
        
        IF secret_val IS NOT NULL THEN
            RETURN secret_val;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RETURN NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION get_secret(TEXT) TO service_role;


-- ── 7. SCRIPT PG_PREWARM: CARGA DE TABELAS & ÍNDICES NA RAM (SHARED_BUFFERS) ──
-- Elimina latência na primeira consulta mantendo estruturas críticas aquecidas
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_prewarm') THEN
        -- Tabelas do TRI e RAG
        PERFORM pg_prewarm('trilha_vocabularyitem');
        PERFORM pg_prewarm('rag_document_categories');
        PERFORM pg_prewarm('users_historicoresposta');
        PERFORM pg_prewarm('ai_thematic_semantic_cache');

        -- Índices HNSW
        PERFORM pg_prewarm('idx_thematic_cache_embedding_hnsw');
        RAISE NOTICE 'pg_prewarm executado com sucesso em tabelas e índices.';
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pg_prewarm ignorado ou incompleto: %', SQLERRM;
END $$;
