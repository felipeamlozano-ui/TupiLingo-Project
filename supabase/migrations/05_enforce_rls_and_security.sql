-- =============================================================================
-- TupiLingo — Migration 05: Defense-in-Depth Row Level Security (RLS) & Hardening
-- =============================================================================
-- Garante conformidade de segurança de classe mundial (Google / Big Tech standard)
-- protegendo todas as tabelas contra bypass do PostgREST via chave pública anon.
-- =============================================================================

-- ── 1. HABILITAÇÃO SISTEMÁTICA DE ROW LEVEL SECURITY (RLS) ───────────────────

DO $$
DECLARE
    tbl text;
    tables text[] := ARRAY[
        'users_userprofile',
        'users_daily_study_log',
        'users_historicoresposta',
        'trilha_userchestreward',
        'trilha_userlesson',
        'nivelamento_usercurrentexercise',
        'nivelamento_testattempt',
        'nivelamento_uservariantelevel',
        'ai_thematic_semantic_cache',
        'trilha_variantetupi',
        'trilha_trilha',
        'trilha_capitulo',
        'trilha_licao',
        'trilha_storyblock',
        'trilha_exercicio'
    ];
BEGIN
    FOREACH tbl IN ARRAY tables
    LOOP
        IF EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_name = tbl
        ) THEN
            EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', tbl);
            RAISE NOTICE 'RLS ativado com sucesso para: %', tbl;
        END IF;
    END LOOP;
END $$;


-- ── 2. POLÍTICAS DE ACESSO: CATÁLOGO EDUCACIONAL (LEITURA PÚBLICA) ───────────
-- Lições, variantes, capítulos e exercícios podem ser consultados por clientes,
-- mas NUNCA inseridos/alterados/deletados diretamente pelo client HTTP.

DO $$
BEGIN
    -- trilha_variantetupi
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'trilha_variantetupi') THEN
        DROP POLICY IF EXISTS p_read_variante ON trilha_variantetupi;
        CREATE POLICY p_read_variante ON trilha_variantetupi
            FOR SELECT TO anon, authenticated
            USING (ativo = true);
    END IF;

    -- trilha_trilha
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'trilha_trilha') THEN
        DROP POLICY IF EXISTS p_read_trilha ON trilha_trilha;
        CREATE POLICY p_read_trilha ON trilha_trilha
            FOR SELECT TO anon, authenticated
            USING (ativo = true);
    END IF;

    -- trilha_capitulo
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'trilha_capitulo') THEN
        DROP POLICY IF EXISTS p_read_capitulo ON trilha_capitulo;
        CREATE POLICY p_read_capitulo ON trilha_capitulo
            FOR SELECT TO anon, authenticated
            USING (publicado = true);
    END IF;

    -- trilha_licao
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'trilha_licao') THEN
        DROP POLICY IF EXISTS p_read_licao ON trilha_licao;
        CREATE POLICY p_read_licao ON trilha_licao
            FOR SELECT TO anon, authenticated
            USING (publicada = true);
    END IF;

    -- trilha_storyblock
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'trilha_storyblock') THEN
        DROP POLICY IF EXISTS p_read_storyblock ON trilha_storyblock;
        CREATE POLICY p_read_storyblock ON trilha_storyblock
            FOR SELECT TO anon, authenticated
            USING (true);
    END IF;

    -- trilha_exercicio
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'trilha_exercicio') THEN
        DROP POLICY IF EXISTS p_read_exercicio ON trilha_exercicio;
        CREATE POLICY p_read_exercicio ON trilha_exercicio
            FOR SELECT TO anon, authenticated
            USING (ativo = true);
    END IF;
END $$;


-- ── 3. POLÍTICAS DE ACESSO: ISOLAMENTO MULTI-TENANT DE USUÁRIO ────────────────
-- Garante que nenhum usuário logado consiga inspecionar ou alterar dados de outro.

DO $$
BEGIN
    -- users_userprofile (apenas o próprio usuário pode ver ou atualizar seu perfil)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users_userprofile') THEN
        DROP POLICY IF EXISTS p_user_profile_isolation ON users_userprofile;
        CREATE POLICY p_user_profile_isolation ON users_userprofile
            FOR ALL TO authenticated
            USING (auth.uid()::text = id::text OR auth.uid()::text = user_id::text)
            WITH CHECK (auth.uid()::text = id::text OR auth.uid()::text = user_id::text);
    END IF;

    -- users_daily_study_log
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users_daily_study_log') THEN
        DROP POLICY IF EXISTS p_daily_log_isolation ON users_daily_study_log;
        CREATE POLICY p_daily_log_isolation ON users_daily_study_log
            FOR ALL TO authenticated
            USING (auth.uid()::text = user_id::text)
            WITH CHECK (auth.uid()::text = user_id::text);
    END IF;

    -- users_historicoresposta (SRS logs)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users_historicoresposta') THEN
        DROP POLICY IF EXISTS p_historico_resposta_isolation ON users_historicoresposta;
        CREATE POLICY p_historico_resposta_isolation ON users_historicoresposta
            FOR ALL TO authenticated
            USING (auth.uid()::text = usuario_id::text)
            WITH CHECK (auth.uid()::text = usuario_id::text);
    END IF;

    -- trilha_userlesson
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'trilha_userlesson') THEN
        DROP POLICY IF EXISTS p_user_lesson_isolation ON trilha_userlesson;
        CREATE POLICY p_user_lesson_isolation ON trilha_userlesson
            FOR ALL TO authenticated
            USING (auth.uid()::text = usuario_id::text)
            WITH CHECK (auth.uid()::text = usuario_id::text);
    END IF;

    -- trilha_userchestreward
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'trilha_userchestreward') THEN
        DROP POLICY IF EXISTS p_user_chest_isolation ON trilha_userchestreward;
        CREATE POLICY p_user_chest_isolation ON trilha_userchestreward
            FOR ALL TO authenticated
            USING (auth.uid()::text = user_id::text)
            WITH CHECK (auth.uid()::text = user_id::text);
    END IF;

    -- nivelamento_uservariantelevel
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'nivelamento_uservariantelevel') THEN
        DROP POLICY IF EXISTS p_user_variante_level_isolation ON nivelamento_uservariantelevel;
        CREATE POLICY p_user_variante_level_isolation ON nivelamento_uservariantelevel
            FOR ALL TO authenticated
            USING (auth.uid()::text = user_id::text)
            WITH CHECK (auth.uid()::text = user_id::text);
    END IF;

    -- nivelamento_usercurrentexercise
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'nivelamento_usercurrentexercise') THEN
        DROP POLICY IF EXISTS p_user_current_ex_isolation ON nivelamento_usercurrentexercise;
        CREATE POLICY p_user_current_ex_isolation ON nivelamento_usercurrentexercise
            FOR ALL TO authenticated
            USING (auth.uid()::text = user_id::text)
            WITH CHECK (auth.uid()::text = user_id::text);
    END IF;
END $$;


-- ── 4. REVOGAÇÃO DE PRIVILÉGIOS DA ROLE ANON EM TABELAS INTERNAS DE IA/SRS ────
-- As tabelas de cache semântico de IA e logs de SRS só devem ser geridas pelo
-- backend Django via conexão autenticada ou service_role.

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'ai_thematic_semantic_cache') THEN
        REVOKE ALL ON ai_thematic_semantic_cache FROM anon;
        GRANT SELECT ON ai_thematic_semantic_cache TO authenticated;
        GRANT ALL ON ai_thematic_semantic_cache TO service_role;
        GRANT ALL ON ai_thematic_semantic_cache TO postgres;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users_daily_study_log') THEN
        REVOKE ALL ON users_daily_study_log FROM anon;
        GRANT SELECT ON users_daily_study_log TO authenticated;
        GRANT ALL ON users_daily_study_log TO service_role;
        GRANT ALL ON users_daily_study_log TO postgres;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users_historicoresposta') THEN
        REVOKE ALL ON users_historicoresposta FROM anon;
        GRANT SELECT ON users_historicoresposta TO authenticated;
        GRANT ALL ON users_historicoresposta TO service_role;
        GRANT ALL ON users_historicoresposta TO postgres;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'trilha_userchestreward') THEN
        REVOKE ALL ON trilha_userchestreward FROM anon;
        GRANT SELECT ON trilha_userchestreward TO authenticated;
        GRANT ALL ON trilha_userchestreward TO service_role;
        GRANT ALL ON trilha_userchestreward TO postgres;
    END IF;
END $$;
