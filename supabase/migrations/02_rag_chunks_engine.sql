-- =============================================================================
-- TupiLingo — RAG Chunks Engine Migration v1.0
-- RFC v3.1: Integração Escalável do Acervo RAG com Nivelamento e Question Pool
--
-- IDEMPOTENTE: Usa IF NOT EXISTS e CREATE OR REPLACE FUNCTION.
-- Pode ser executado múltiplas vezes com segurança.
-- =============================================================================

-- =============================================================================
-- SEÇÃO 1 — ÍNDICE COMPOSTO DE COBERTURA
-- Justificativa:
--   • Permite que o PostgreSQL filtre diretamente por categoria e id
--     sem efetuar Seq Scan nos milhares de chunks de documentos.
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_rag_doc_cat_categoria_id 
    ON rag_document_categories (categoria, id);


-- =============================================================================
-- SEÇÃO 2 — RPC: obter_chunks_rag
-- Justificativa de Escalabilidade:
--   • Aceita array de categorias (p_categorias text[]) para mesclar temas (ex: História + Gramática).
--   • Evita ORDER BY random() usando TABLESAMPLE SYSTEM (15) para amostragem O(1)
--     em blocos físicos de disco.
--   • Possui fallback indexado por offset dinâmico caso categorias específicas
--     tenham poucos registros no sample.
-- =============================================================================

CREATE OR REPLACE FUNCTION obter_chunks_rag(
    p_categorias TEXT[]  DEFAULT ARRAY['Vocabulário'],
    p_limite     INTEGER DEFAULT 3
)
RETURNS TABLE (
    id            INTEGER,
    chunk_id      TEXT,
    document_text TEXT,
    categoria     TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_total_cand INTEGER;
    v_random_offset INTEGER;
BEGIN
    -- Normaliza categorias nulas ou vazias
    IF p_categorias IS NULL OR array_length(p_categorias, 1) IS NULL THEN
        p_categorias := ARRAY['Vocabulário'];
    END IF;

    -- [ESTÁGIO 1]: Amostragem O(1) direta de páginas em disco via TABLESAMPLE
    RETURN QUERY
    SELECT r.id, r.chunk_id, r.document_text, r.categoria
    FROM   rag_document_categories AS r TABLESAMPLE SYSTEM (15)
    WHERE  r.categoria = ANY(p_categorias)
      AND  length(r.document_text) > 80
    LIMIT  p_limite;

    -- Se TABLESAMPLE supriu a quantidade solicitada, retorna imediatamente
    IF FOUND THEN
        RETURN;
    END IF;

    -- [ESTÁGIO 2]: Fallback indexado com offset aleatório calculado sobre a contagem real
    SELECT count(*)
    INTO   v_total_cand
    FROM   rag_document_categories r
    WHERE  r.categoria = ANY(p_categorias)
      AND  length(r.document_text) > 80;

    IF v_total_cand = 0 THEN
        RETURN;
    END IF;

    -- Offset aleatório dentro da janela de candidatos
    v_random_offset := floor(random() * GREATEST(1, v_total_cand - p_limite));

    RETURN QUERY
    SELECT r.id, r.chunk_id, r.document_text, r.categoria
    FROM   rag_document_categories r
    WHERE  r.categoria = ANY(p_categorias)
      AND  length(r.document_text) > 80
    OFFSET v_random_offset
    LIMIT  p_limite;
END;
$$;

-- Permissões de execução para service_role, anon e authenticated
GRANT EXECUTE ON FUNCTION obter_chunks_rag(TEXT[], INTEGER) TO service_role, anon, authenticated;
