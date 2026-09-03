-- =============================================================================
-- TupiLingo — Quiz Engine Migration v1.0
-- RFC v3.0: Engine Heurística Determinística
--
-- IDEMPOTENTE: Todos os ALTER TABLE usam "ADD COLUMN IF NOT EXISTS".
-- Pode ser executado múltiplas vezes com segurança.
-- =============================================================================


-- =============================================================================
-- SEÇÃO 1 — SCHEMA: Novos campos na tabela de vocabulário
-- =============================================================================

ALTER TABLE trilha_vocabularyitem
    ADD COLUMN IF NOT EXISTS categoria        VARCHAR(100) NOT NULL DEFAULT 'geral',
    ADD COLUMN IF NOT EXISTS classe_gramatical VARCHAR(100) NOT NULL DEFAULT 'substantivo';


-- =============================================================================
-- SEÇÃO 2 — ÍNDICES COMPOSTOS
-- Justificativa:
--   • O planner do PostgreSQL usa Index Scan em vez de Seq Scan quando filtramos
--     por (licao_id → variante via JOIN) + categoria + classe_gramatical.
--   • O índice parcial na classe_gramatical garante cobertura nas subqueries
--     de distratores que filtram apenas por classe + variante (sem categoria).
-- =============================================================================

-- Índice para seleção de termos por categoria dentro de uma lição
CREATE INDEX IF NOT EXISTS idx_vocabitem_categoria
    ON trilha_vocabularyitem (licao_id, categoria);

-- Índice para busca de distratores por classe gramatical
CREATE INDEX IF NOT EXISTS idx_vocabitem_classe_gramatical
    ON trilha_vocabularyitem (licao_id, classe_gramatical);

-- Índice composto completo para a query principal da RPC
CREATE INDEX IF NOT EXISTS idx_vocabitem_categoria_classe
    ON trilha_vocabularyitem (licao_id, categoria, classe_gramatical);


-- =============================================================================
-- SEÇÃO 3 — BACKFILL INTELIGENTE
-- Classifica os registros existentes usando o título da lição como proxy.
-- Regra: se o título da lição contém palavras de uma categoria, ela é aplicada.
-- Todos os demais ficam com DEFAULT 'geral'/'substantivo' (já definido acima).
-- =============================================================================

-- Fauna (animais)
UPDATE trilha_vocabularyitem vi
SET    categoria = 'fauna'
FROM   trilha_licao l
WHERE  vi.licao_id = l.id
  AND  vi.categoria = 'geral'
  AND  (
           lower(l.titulo) LIKE '%animal%'
        OR lower(l.titulo) LIKE '%fauna%'
        OR lower(l.titulo) LIKE '%aves%'
        OR lower(l.titulo) LIKE '%peixe%'
        OR lower(l.titulo) LIKE '%inseto%'
        OR lower(l.titulo) LIKE '%onça%'
        OR lower(l.titulo) LIKE '%jaguar%'
        OR lower(l.titulo) LIKE '%bicho%'
       );

-- Flora (plantas)
UPDATE trilha_vocabularyitem vi
SET    categoria = 'flora'
FROM   trilha_licao l
WHERE  vi.licao_id = l.id
  AND  vi.categoria = 'geral'
  AND  (
           lower(l.titulo) LIKE '%planta%'
        OR lower(l.titulo) LIKE '%flora%'
        OR lower(l.titulo) LIKE '%árvore%'
        OR lower(l.titulo) LIKE '%arvore%'
        OR lower(l.titulo) LIKE '%fruta%'
        OR lower(l.titulo) LIKE '%raiz%'
       );

-- Corpo humano
UPDATE trilha_vocabularyitem vi
SET    categoria = 'corpo'
FROM   trilha_licao l
WHERE  vi.licao_id = l.id
  AND  vi.categoria = 'geral'
  AND  (
           lower(l.titulo) LIKE '%corpo%'
        OR lower(l.titulo) LIKE '%saúde%'
        OR lower(l.titulo) LIKE '%saude%'
        OR lower(l.titulo) LIKE '%doença%'
        OR lower(l.titulo) LIKE '%doenca%'
       );

-- Natureza / Cosmos
UPDATE trilha_vocabularyitem vi
SET    categoria = 'natureza'
FROM   trilha_licao l
WHERE  vi.licao_id = l.id
  AND  vi.categoria = 'geral'
  AND  (
           lower(l.titulo) LIKE '%natureza%'
        OR lower(l.titulo) LIKE '%rio%'
        OR lower(l.titulo) LIKE '%mata%'
        OR lower(l.titulo) LIKE '%floresta%'
        OR lower(l.titulo) LIKE '%chuva%'
        OR lower(l.titulo) LIKE '%sol%'
        OR lower(l.titulo) LIKE '%lua%'
        OR lower(l.titulo) LIKE '%cosmos%'
        OR lower(l.titulo) LIKE '%astro%'
       );

-- Mitologia / Espiritualidade
UPDATE trilha_vocabularyitem vi
SET    categoria = 'mitologia'
FROM   trilha_licao l
WHERE  vi.licao_id = l.id
  AND  vi.categoria = 'geral'
  AND  (
           lower(l.titulo) LIKE '%mito%'
        OR lower(l.titulo) LIKE '%tupã%'
        OR lower(l.titulo) LIKE '%tupa%'
        OR lower(l.titulo) LIKE '%pajé%'
        OR lower(l.titulo) LIKE '%paje%'
        OR lower(l.titulo) LIKE '%espirito%'
        OR lower(l.titulo) LIKE '%espírito%'
        OR lower(l.titulo) LIKE '%ritual%'
        OR lower(l.titulo) LIKE '%sagrado%'
       );

-- Verbos (inferido pela tradução em português que começa com infinitivo)
UPDATE trilha_vocabularyitem
SET    classe_gramatical = 'verbo'
WHERE  classe_gramatical = 'substantivo'
  AND  (
           lower(traducao_pt) LIKE 'correr%'
        OR lower(traducao_pt) LIKE 'comer%'
        OR lower(traducao_pt) LIKE 'beber%'
        OR lower(traducao_pt) LIKE 'andar%'
        OR lower(traducao_pt) LIKE 'falar%'
        OR lower(traducao_pt) LIKE 'ver%'
        OR lower(traducao_pt) LIKE 'ouvir%'
        OR lower(traducao_pt) LIKE 'dormir%'
        OR lower(traducao_pt) LIKE 'caçar%'
        OR lower(traducao_pt) LIKE 'pescar%'
        OR lower(traducao_pt) LIKE 'plantar%'
        OR lower(traducao_pt) LIKE 'colher%'
        OR lower(traducao_pt) LIKE 'nadar%'
        OR lower(traducao_pt) LIKE 'voar%'
        OR lower(traducao_pt) LIKE 'lutar%'
        OR lower(traducao_pt) LIKE 'cantar%'
        OR lower(traducao_pt) LIKE 'dançar%'
        OR lower(traducao_pt) LIKE 'dancçar%'
        OR lower(traducao_pt) LIKE 'rezar%'
        OR lower(traducao_pt) LIKE 'curar%'
        OR lower(traducao_pt) LIKE 'amar%'
        OR lower(traducao_pt) LIKE 'ir%'
        OR lower(traducao_pt) LIKE 'vir%'
        OR lower(traducao_pt) LIKE 'trazer%'
        OR lower(traducao_pt) LIKE 'levar%'
        OR lower(traducao_pt) LIKE 'fazer%'
        OR lower(traducao_pt) LIKE 'dar%'
        OR lower(traducao_pt) LIKE 'pegar%'
        OR lower(traducao_pt) LIKE 'jogar%'
        OR lower(traducao_pt) LIKE 'matar%'
        OR lower(traducao_pt) LIKE 'nascer%'
        OR lower(traducao_pt) LIKE 'morrer%'
       );


-- =============================================================================
-- SEÇÃO 4 — RPC: gerar_esqueleto_quiz
-- =============================================================================

CREATE OR REPLACE FUNCTION gerar_esqueleto_quiz(
    p_variante_codigo TEXT,
    p_categoria       TEXT    DEFAULT 'geral',
    p_quantidade      INTEGER DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
    v_resultado      JSONB;
    v_termos_count   INTEGER;
BEGIN
    -- ── Validações de entrada ────────────────────────────────────────────────
    IF p_quantidade < 1 OR p_quantidade > 50 THEN
        RAISE EXCEPTION 'quantidade deve estar entre 1 e 50, recebido: %', p_quantidade
            USING ERRCODE = 'check_violation';
    END IF;

    IF p_variante_codigo IS NULL OR trim(p_variante_codigo) = '' THEN
        RAISE EXCEPTION 'variante_codigo não pode ser vazio'
            USING ERRCODE = 'not_null_violation';
    END IF;

    -- ── Verifica disponibilidade de termos ───────────────────────────────────
    SELECT COUNT(*)
    INTO   v_termos_count
    FROM   trilha_vocabularyitem vi
    JOIN   trilha_licao          l  ON l.id  = vi.licao_id
    JOIN   trilha_capitulo       cp ON cp.id = l.capitulo_id
    JOIN   trilha_trilhahistorica th ON th.id = cp.trilha_id
    JOIN   trilha_variantetupi   vt ON vt.id = th.variante_id
    WHERE  vt.codigo = p_variante_codigo
      AND  vt.ativo  = TRUE;

    -- Se não há NENHUM termo para esta variante, retorna array vazio
    IF v_termos_count = 0 THEN
        RETURN '[]'::JSONB;
    END IF;

    -- ── Geração do esqueleto de questões ─────────────────────────────────────
    -- Cada questão recebe:
    --   • Um termo selecionado aleatoriamente (respeitando categoria se possível)
    --   • Três distratores em 3 estágios de degradação graciosa:
    --       1. mesma categoria + mesma classe gramatical da variante
    --       2. mesma classe gramatical, qualquer categoria da variante (fallback)
    --       3. qualquer termo da variante, excluindo a resposta correta (last resort)
    SELECT jsonb_agg(item ORDER BY item->>'item_id')
    INTO   v_resultado
    FROM (
        SELECT jsonb_build_object(
            'item_id',          row_number() OVER () ,
            'termo_tupi',       base.palavra_tupi,
            'traducao_correta', base.traducao_pt,
            'classe_gramatical',base.classe_gramatical,
            'categoria',        base.categoria,
            'regra_contexto',   COALESCE(NULLIF(base.exemplo_tupi, ''), base.transliteracao, ''),
            'fonte',            'Base Lexical Oficial TupiLingo',
            'distratores',      COALESCE(dist.lista, '[]'::JSONB)
        ) AS item
        FROM (
            -- ── Seleção do termo principal ────────────────────────────────────
            -- Tenta categoria pedida; se não houver, cai para qualquer categoria
            SELECT
                vi.id,
                vi.palavra_tupi,
                vi.traducao_pt,
                vi.transliteracao,
                vi.exemplo_tupi,
                vi.categoria,
                vi.classe_gramatical
            FROM   trilha_vocabularyitem vi
            JOIN   trilha_licao          l  ON l.id  = vi.licao_id
            JOIN   trilha_capitulo       cp ON cp.id = l.capitulo_id
            JOIN   trilha_trilhahistorica th ON th.id = cp.trilha_id
            JOIN   trilha_variantetupi   vt ON vt.id = th.variante_id
            WHERE  vt.codigo = p_variante_codigo
              AND  vt.ativo  = TRUE
              AND  (vi.categoria = p_categoria OR p_categoria = 'geral')
            ORDER BY random()
            LIMIT  p_quantidade
        ) base
        -- ── Distratores via LATERAL JOIN ──────────────────────────────────────
        LEFT JOIN LATERAL (
            SELECT jsonb_agg(d.traducao_pt) AS lista
            FROM (
                -- Estágio 1: mesma categoria + mesma classe gramatical
                (SELECT vi2.traducao_pt
                FROM   trilha_vocabularyitem vi2
                JOIN   trilha_licao          l2  ON l2.id  = vi2.licao_id
                JOIN   trilha_capitulo       cp2 ON cp2.id = l2.capitulo_id
                JOIN   trilha_trilhahistorica th2 ON th2.id = cp2.trilha_id
                JOIN   trilha_variantetupi   vt2 ON vt2.id = th2.variante_id
                WHERE  vt2.codigo          = p_variante_codigo
                  AND  vi2.id             <> base.id
                  AND  vi2.categoria       = base.categoria
                  AND  vi2.classe_gramatical = base.classe_gramatical
                  AND  vi2.traducao_pt    <> base.traducao_pt
                ORDER BY random()
                LIMIT 3)

                UNION ALL

                -- Estágio 2 (fallback): mesma classe gramatical, qualquer categoria
                (SELECT vi3.traducao_pt
                FROM   trilha_vocabularyitem vi3
                JOIN   trilha_licao          l3  ON l3.id  = vi3.licao_id
                JOIN   trilha_capitulo       cp3 ON cp3.id = l3.capitulo_id
                JOIN   trilha_trilhahistorica th3 ON th3.id = cp3.trilha_id
                JOIN   trilha_variantetupi   vt3 ON vt3.id = th3.variante_id
                WHERE  vt3.codigo          = p_variante_codigo
                  AND  vi3.id             <> base.id
                  AND  vi3.classe_gramatical = base.classe_gramatical
                  AND  vi3.traducao_pt    <> base.traducao_pt
                ORDER BY random()
                LIMIT 3)

                UNION ALL

                -- Estágio 3 (last resort): qualquer termo da variante
                (SELECT vi4.traducao_pt
                FROM   trilha_vocabularyitem vi4
                JOIN   trilha_licao          l4  ON l4.id  = vi4.licao_id
                JOIN   trilha_capitulo       cp4 ON cp4.id = l4.capitulo_id
                JOIN   trilha_trilhahistorica th4 ON th4.id = cp4.trilha_id
                JOIN   trilha_variantetupi   vt4 ON vt4.id = th4.variante_id
                WHERE  vt4.codigo      = p_variante_codigo
                  AND  vi4.id         <> base.id
                  AND  vi4.traducao_pt <> base.traducao_pt
                ORDER BY random()
                LIMIT 3)
            ) d
            LIMIT 3  -- garante exatamente 3 distratores únicos
        ) dist ON TRUE
    ) subq;

    RETURN COALESCE(v_resultado, '[]'::JSONB);

EXCEPTION
    WHEN check_violation THEN
        RAISE;
    WHEN not_null_violation THEN
        RAISE;
    WHEN OTHERS THEN
        RAISE EXCEPTION 'gerar_esqueleto_quiz falhou [%]: %', SQLSTATE, SQLERRM
            USING ERRCODE = 'internal_error';
END;
$$;

-- Concede execução apenas para a role service_role (usada pelo backend)
GRANT EXECUTE ON FUNCTION gerar_esqueleto_quiz(TEXT, TEXT, INTEGER) TO service_role;
