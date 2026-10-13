-- =============================================================================
-- TupiLingo — Migration 07: SEC-P0 & SEC-P1 Forensic Hardening (RLS, RPC & Vault Security)
-- =============================================================================
-- 1. Revoga acesso público/anon/authenticated a funções SECURITY DEFINER críticas:
--    - fn_record_user_activity
--    - get_secret (Supabase Vault)
--    - fn_check_and_reset_streaks
--    - get_user_weakest_vocabulary
--    - enfileirar_respostas_pgmq
--    - drenar_fila_historico_pgmq
--    - fn_queue_streak_reminders
--    - fn_queue_new_content_notifications
-- 2. Define search_path fixo e seguro (public, pg_temp) contra Search Path Hijacking.
-- 3. Restringe execução ao service_role / backend Django e superusuário postgres.
-- 4. Ativação sistemática e preventiva de Row Level Security (RLS) em todas as tabelas.
-- 5. Corrige mapeamento de identidade RLS em users_userprofile (auth.uid() = supabase_uid).
-- 6. Corrige isolamento relacional em todas as tabelas de progresso e nivelamento:
--    - users_daily_study_log (user_id)
--    - users_historicoresposta (user_id)
--    - users_userlesson (usuario_id) e trilha_userlesson
--    - trilha_userchestreward (user_id)
--    - nivelamento_uservariantelevel (user_id)
--    - nivelamento_testattempt (user_id)
--    - users_userachievement (user_id)
--    - users_vocabularyprogress (usuario_id)
--    - users_cosmetics / users_cosmetic_purchases (user_id)
--    - users_filaexerciciousuario (usuario_id)
-- 7. Garante proteção do catálogo educacional para leitura pública e bloqueio de escrita.
-- =============================================================================

-- ── 1. HARDENING DE RPC: fn_record_user_activity ─────────────────────────────
-- Previne injeção direta de XP, streak e ofensiva arbitrária via PostgREST público.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'users_daily_study_log' AND column_name = 'created_at'
    ) THEN
        ALTER TABLE users_daily_study_log ALTER COLUMN created_at SET DEFAULT NOW();
    END IF;
END $$;

CREATE OR REPLACE FUNCTION public.fn_record_user_activity(
    p_user_id integer,
    p_xp_ganho integer,
    p_tempo_segundos integer,
    p_is_lesson_completed boolean,
    p_exercicios_respondidos integer,
    p_exercicios_corretos integer
)
RETURNS TABLE (
    out_streak_atual integer,
    out_maior_streak integer,
    out_xp_total integer,
    out_streak_incremented boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    today_br date;
    yesterday_br date;
    v_last_studied date;
    v_current_streak integer;
    v_max_streak integer;
    v_total_xp integer;
    v_streak_incremented boolean := false;
BEGIN
    today_br := (CURRENT_TIMESTAMP AT TIME ZONE 'America/Sao_Paulo')::date;
    yesterday_br := today_br - 1;

    -- Bloqueia a linha do usuário para garantir consistência transacional estrita
    SELECT ultimo_dia_estudado, streak_atual, maior_streak, xp_total
    INTO v_last_studied, v_current_streak, v_max_streak, v_total_xp
    FROM users_userprofile
    WHERE id = p_user_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'UserProfile com id % não foi encontrado', p_user_id;
    END IF;

    -- Regras canônicas da Ofensiva (Streak)
    IF v_last_studied IS NULL THEN
        v_current_streak := 1;
        v_streak_incremented := true;
    ELSIF v_last_studied = today_br THEN
        -- Já estudou hoje: mantém streak sem duplicar
        v_streak_incremented := false;
    ELSIF v_last_studied = yesterday_br THEN
        -- Dia consecutivo: incrementa
        v_current_streak := v_current_streak + 1;
        v_streak_incremented := true;
    ELSE
        -- Mais de um dia sem estudar: sequência quebrou
        v_current_streak := 1;
        v_streak_incremented := true;
    END IF;

    -- Atualiza maior streak se superado
    IF v_current_streak > v_max_streak THEN
        v_max_streak := v_current_streak;
    END IF;

    v_total_xp := v_total_xp + p_xp_ganho;

    -- Atualiza dados de UserProfile
    UPDATE users_userprofile
    SET streak_atual = v_current_streak,
        maior_streak = v_max_streak,
        ultimo_dia_estudado = today_br,
        dias_estudados_total = CASE 
            WHEN v_last_studied = today_br THEN dias_estudados_total 
            ELSE dias_estudados_total + 1 
        END,
        xp_total = v_total_xp,
        updated_at = NOW()
    WHERE id = p_user_id;

    -- Registra / acumula no log diário de estudo com created_at garantido
    INSERT INTO users_daily_study_log (
        user_id, data, xp_ganho, licoes_concluidas,
        exercicios_respondidos, exercicios_corretos, tempo_estudo_segundos, created_at, updated_at
    )
    VALUES (
        p_user_id, today_br, p_xp_ganho,
        CASE WHEN p_is_lesson_completed THEN 1 ELSE 0 END,
        p_exercicios_respondidos, p_exercicios_corretos, p_tempo_segundos, NOW(), NOW()
    )
    ON CONFLICT (user_id, data)
    DO UPDATE SET
        xp_ganho = users_daily_study_log.xp_ganho + EXCLUDED.xp_ganho,
        licoes_concluidas = users_daily_study_log.licoes_concluidas + EXCLUDED.licoes_concluidas,
        exercicios_respondidos = users_daily_study_log.exercicios_respondidos + EXCLUDED.exercicios_respondidos,
        exercicios_corretos = users_daily_study_log.exercicios_corretos + EXCLUDED.exercicios_corretos,
        tempo_estudo_segundos = users_daily_study_log.tempo_estudo_segundos + EXCLUDED.tempo_estudo_segundos,
        updated_at = NOW();

    out_streak_atual := v_current_streak;
    out_maior_streak := v_max_streak;
    out_xp_total := v_total_xp;
    out_streak_incremented := v_streak_incremented;
    RETURN NEXT;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.fn_record_user_activity(integer, integer, integer, boolean, integer, integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.fn_record_user_activity(integer, integer, integer, boolean, integer, integer) FROM anon;
REVOKE EXECUTE ON FUNCTION public.fn_record_user_activity(integer, integer, integer, boolean, integer, integer) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.fn_record_user_activity(integer, integer, integer, boolean, integer, integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.fn_record_user_activity(integer, integer, integer, boolean, integer, integer) TO postgres;


-- ── 2. HARDENING DE RPC: get_secret (SUPABASE VAULT) ─────────────────────────
-- Previne vazamento de segredos armazenados no vault.decrypted_secrets via PostgREST público.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = 'get_secret'
    ) THEN
        REVOKE EXECUTE ON FUNCTION public.get_secret(text) FROM PUBLIC;
        REVOKE EXECUTE ON FUNCTION public.get_secret(text) FROM anon;
        REVOKE EXECUTE ON FUNCTION public.get_secret(text) FROM authenticated;
        GRANT EXECUTE ON FUNCTION public.get_secret(text) TO service_role;
        GRANT EXECUTE ON FUNCTION public.get_secret(text) TO postgres;

        -- Proteção contra Search Path Hijacking
        ALTER FUNCTION public.get_secret(text)
            SET search_path = public, pg_temp;

        RAISE NOTICE 'get_secret revogada com sucesso de PUBLIC, anon e authenticated. search_path fixado.';
    END IF;
END $$;


-- ── 3. HARDENING DE RPC: fn_check_and_reset_streaks ──────────────────────────
-- Previne reset ou manipulação concorrente indevida de ofensivas de usuários.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = 'fn_check_and_reset_streaks'
    ) THEN
        REVOKE EXECUTE ON FUNCTION public.fn_check_and_reset_streaks() FROM PUBLIC;
        REVOKE EXECUTE ON FUNCTION public.fn_check_and_reset_streaks() FROM anon;
        REVOKE EXECUTE ON FUNCTION public.fn_check_and_reset_streaks() FROM authenticated;
        GRANT EXECUTE ON FUNCTION public.fn_check_and_reset_streaks() TO service_role;
        GRANT EXECUTE ON FUNCTION public.fn_check_and_reset_streaks() TO postgres;

        ALTER FUNCTION public.fn_check_and_reset_streaks()
            SET search_path = public, pg_temp;

        RAISE NOTICE 'fn_check_and_reset_streaks revogada de PUBLIC/anon/authenticated.';
    END IF;
END $$;


-- ── 4. HARDENING DE RPC: get_user_weakest_vocabulary ─────────────────────────
-- Impede que um usuário autenticado consulte o histórico de erros e fraquezas de outro.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = 'get_user_weakest_vocabulary'
    ) THEN
        REVOKE EXECUTE ON FUNCTION public.get_user_weakest_vocabulary(integer, integer) FROM PUBLIC;
        REVOKE EXECUTE ON FUNCTION public.get_user_weakest_vocabulary(integer, integer) FROM anon;
        REVOKE EXECUTE ON FUNCTION public.get_user_weakest_vocabulary(integer, integer) FROM authenticated;
        GRANT EXECUTE ON FUNCTION public.get_user_weakest_vocabulary(integer, integer) TO service_role;
        GRANT EXECUTE ON FUNCTION public.get_user_weakest_vocabulary(integer, integer) TO postgres;

        ALTER FUNCTION public.get_user_weakest_vocabulary(integer, integer)
            SET search_path = public, pg_temp;

        RAISE NOTICE 'get_user_weakest_vocabulary restrita a service_role e postgres.';
    END IF;
END $$;


-- ── 5. HARDENING DE FILA PGMQ & NOTIFICAÇÕES CRON ────────────────────────────
-- Impede injeção ou drenagem não autorizada de histórico de respostas e disparos em massa.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = 'enfileirar_respostas_pgmq'
    ) THEN
        REVOKE EXECUTE ON FUNCTION public.enfileirar_respostas_pgmq(jsonb) FROM PUBLIC;
        REVOKE EXECUTE ON FUNCTION public.enfileirar_respostas_pgmq(jsonb) FROM anon;
        REVOKE EXECUTE ON FUNCTION public.enfileirar_respostas_pgmq(jsonb) FROM authenticated;
        GRANT EXECUTE ON FUNCTION public.enfileirar_respostas_pgmq(jsonb) TO service_role;
        GRANT EXECUTE ON FUNCTION public.enfileirar_respostas_pgmq(jsonb) TO postgres;

        ALTER FUNCTION public.enfileirar_respostas_pgmq(jsonb)
            SET search_path = public, pg_temp;
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = 'drenar_fila_historico_pgmq'
    ) THEN
        REVOKE EXECUTE ON FUNCTION public.drenar_fila_historico_pgmq(integer) FROM PUBLIC;
        REVOKE EXECUTE ON FUNCTION public.drenar_fila_historico_pgmq(integer) FROM anon;
        REVOKE EXECUTE ON FUNCTION public.drenar_fila_historico_pgmq(integer) FROM authenticated;
        GRANT EXECUTE ON FUNCTION public.drenar_fila_historico_pgmq(integer) TO service_role;
        GRANT EXECUTE ON FUNCTION public.drenar_fila_historico_pgmq(integer) TO postgres;

        ALTER FUNCTION public.drenar_fila_historico_pgmq(integer)
            SET search_path = public, pg_temp;
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = 'fn_queue_streak_reminders'
    ) THEN
        REVOKE EXECUTE ON FUNCTION public.fn_queue_streak_reminders() FROM PUBLIC;
        REVOKE EXECUTE ON FUNCTION public.fn_queue_streak_reminders() FROM anon;
        REVOKE EXECUTE ON FUNCTION public.fn_queue_streak_reminders() FROM authenticated;
        GRANT EXECUTE ON FUNCTION public.fn_queue_streak_reminders() TO service_role;
        GRANT EXECUTE ON FUNCTION public.fn_queue_streak_reminders() TO postgres;

        ALTER FUNCTION public.fn_queue_streak_reminders()
            SET search_path = public, pg_temp;
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = 'fn_queue_new_content_notifications'
    ) THEN
        REVOKE EXECUTE ON FUNCTION public.fn_queue_new_content_notifications() FROM PUBLIC;
        REVOKE EXECUTE ON FUNCTION public.fn_queue_new_content_notifications() FROM anon;
        REVOKE EXECUTE ON FUNCTION public.fn_queue_new_content_notifications() FROM authenticated;
        GRANT EXECUTE ON FUNCTION public.fn_queue_new_content_notifications() TO service_role;
        GRANT EXECUTE ON FUNCTION public.fn_queue_new_content_notifications() TO postgres;

        ALTER FUNCTION public.fn_queue_new_content_notifications()
            SET search_path = public, pg_temp;
    END IF;
END $$;


-- ── 6. ATIVAÇÃO PREVENTIVA DE ROW LEVEL SECURITY (RLS) ───────────────────────
-- Garante que todas as tabelas privadas e de catálogo tenham RLS ativo sem depender de migrations anteriores.

DO $$
DECLARE
    tbl text;
    tables text[] := ARRAY[
        'users_userprofile',
        'users_daily_study_log',
        'users_historicoresposta',
        'users_userlesson',
        'trilha_userlesson',
        'trilha_userchestreward',
        'nivelamento_uservariantelevel',
        'nivelamento_testattempt',
        'nivelamento_birdbraincalibrationlog',
        'users_userachievement',
        'users_vocabularyprogress',
        'users_cosmetics',
        'users_cosmetic_purchases',
        'users_filaexerciciousuario',
        'users_push_tokens',
        'notification_queue',
        'ai_thematic_semantic_cache',
        'trilha_variantetupi',
        'trilha_trilhahistorica',
        'trilha_trilha',
        'trilha_capitulo',
        'trilha_licao',
        'trilha_storyblock',
        'trilha_exercicio',
        'trilha_vocabularyitem'
    ];
BEGIN
    FOREACH tbl IN ARRAY tables
    LOOP
        IF EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_name = tbl
        ) THEN
            EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', tbl);
        END IF;
    END LOOP;
END $$;


-- ── 7. CORREÇÃO DE POLÍTICA RLS EM users_userprofile ──────────────────────────
-- Compara auth.uid() com o campo real supabase_uid (UUID) e previne alteração de supabase_uid.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'users_userprofile'
    ) THEN
        DROP POLICY IF EXISTS p_user_profile_isolation ON users_userprofile;
        DROP POLICY IF EXISTS p_user_profile_sec_p0 ON users_userprofile;

        CREATE POLICY p_user_profile_sec_p0 ON users_userprofile
            FOR ALL TO authenticated
            USING (
                auth.uid()::text = supabase_uid::text
            )
            WITH CHECK (
                auth.uid()::text = supabase_uid::text
            );

        RAISE NOTICE 'Política RLS p_user_profile_sec_p0 aplicada com supabase_uid::text.';
    END IF;
END $$;


-- ── 8. CORREÇÃO DE POLÍTICAS RLS NAS TABELAS RELACIONADAS DE USUÁRIO ─────────
-- Subquery com users_userprofile para mapear auth.uid() -> users_userprofile.id

DO $$
BEGIN
    -- users_daily_study_log
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users_daily_study_log') THEN
        DROP POLICY IF EXISTS p_daily_log_isolation ON users_daily_study_log;
        DROP POLICY IF EXISTS p_daily_log_sec_p0 ON users_daily_study_log;

        CREATE POLICY p_daily_log_sec_p0 ON users_daily_study_log
            FOR ALL TO authenticated
            USING (
                user_id IN (SELECT id FROM users_userprofile WHERE supabase_uid::text = auth.uid()::text)
            )
            WITH CHECK (
                user_id IN (SELECT id FROM users_userprofile WHERE supabase_uid::text = auth.uid()::text)
            );
    END IF;

    -- users_historicoresposta (coluna real: user_id)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users_historicoresposta') THEN
        DROP POLICY IF EXISTS p_historico_resposta_isolation ON users_historicoresposta;
        DROP POLICY IF EXISTS p_historico_resposta_sec_p0 ON users_historicoresposta;

        CREATE POLICY p_historico_resposta_sec_p0 ON users_historicoresposta
            FOR ALL TO authenticated
            USING (
                user_id IN (SELECT id FROM users_userprofile WHERE supabase_uid::text = auth.uid()::text)
            )
            WITH CHECK (
                user_id IN (SELECT id FROM users_userprofile WHERE supabase_uid::text = auth.uid()::text)
            );
    END IF;

    -- users_userlesson (tabela padrão Django: users_userlesson, coluna: usuario_id)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users_userlesson') THEN
        DROP POLICY IF EXISTS p_user_lesson_isolation ON users_userlesson;
        DROP POLICY IF EXISTS p_user_lesson_sec_p0 ON users_userlesson;

        CREATE POLICY p_user_lesson_sec_p0 ON users_userlesson
            FOR ALL TO authenticated
            USING (
                usuario_id IN (SELECT id FROM users_userprofile WHERE supabase_uid::text = auth.uid()::text)
            )
            WITH CHECK (
                usuario_id IN (SELECT id FROM users_userprofile WHERE supabase_uid::text = auth.uid()::text)
            );
    END IF;

    -- trilha_userlesson (caso exista como alias ou legado)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'trilha_userlesson') THEN
        DROP POLICY IF EXISTS p_user_lesson_isolation ON trilha_userlesson;
        DROP POLICY IF EXISTS p_user_lesson_sec_p0 ON trilha_userlesson;

        CREATE POLICY p_user_lesson_sec_p0 ON trilha_userlesson
            FOR ALL TO authenticated
            USING (
                usuario_id IN (SELECT id FROM users_userprofile WHERE supabase_uid::text = auth.uid()::text)
            )
            WITH CHECK (
                usuario_id IN (SELECT id FROM users_userprofile WHERE supabase_uid::text = auth.uid()::text)
            );
    END IF;

    -- trilha_userchestreward
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'trilha_userchestreward') THEN
        DROP POLICY IF EXISTS p_user_chest_isolation ON trilha_userchestreward;
        DROP POLICY IF EXISTS p_user_chest_sec_p0 ON trilha_userchestreward;

        CREATE POLICY p_user_chest_sec_p0 ON trilha_userchestreward
            FOR ALL TO authenticated
            USING (
                user_id IN (SELECT id FROM users_userprofile WHERE supabase_uid::text = auth.uid()::text)
            )
            WITH CHECK (
                user_id IN (SELECT id FROM users_userprofile WHERE supabase_uid::text = auth.uid()::text)
            );
    END IF;

    -- nivelamento_uservariantelevel
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'nivelamento_uservariantelevel') THEN
        DROP POLICY IF EXISTS p_user_variante_level_isolation ON nivelamento_uservariantelevel;
        DROP POLICY IF EXISTS p_user_variante_level_sec_p0 ON nivelamento_uservariantelevel;

        CREATE POLICY p_user_variante_level_sec_p0 ON nivelamento_uservariantelevel
            FOR ALL TO authenticated
            USING (
                user_id IN (SELECT id FROM users_userprofile WHERE supabase_uid::text = auth.uid()::text)
            )
            WITH CHECK (
                user_id IN (SELECT id FROM users_userprofile WHERE supabase_uid::text = auth.uid()::text)
            );
    END IF;

    -- nivelamento_testattempt
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'nivelamento_testattempt') THEN
        DROP POLICY IF EXISTS p_test_attempt_isolation ON nivelamento_testattempt;
        DROP POLICY IF EXISTS p_test_attempt_sec_p0 ON nivelamento_testattempt;

        CREATE POLICY p_test_attempt_sec_p0 ON nivelamento_testattempt
            FOR ALL TO authenticated
            USING (
                user_id IN (SELECT id FROM users_userprofile WHERE supabase_uid::text = auth.uid()::text)
            )
            WITH CHECK (
                user_id IN (SELECT id FROM users_userprofile WHERE supabase_uid::text = auth.uid()::text)
            );
    END IF;

    -- users_userachievement
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users_userachievement') THEN
        DROP POLICY IF EXISTS p_user_achievement_isolation ON users_userachievement;
        DROP POLICY IF EXISTS p_user_achievement_sec_p0 ON users_userachievement;

        CREATE POLICY p_user_achievement_sec_p0 ON users_userachievement
            FOR ALL TO authenticated
            USING (
                user_id IN (SELECT id FROM users_userprofile WHERE supabase_uid::text = auth.uid()::text)
            )
            WITH CHECK (
                user_id IN (SELECT id FROM users_userprofile WHERE supabase_uid::text = auth.uid()::text)
            );
    END IF;

    -- users_vocabularyprogress (coluna: usuario_id)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users_vocabularyprogress') THEN
        DROP POLICY IF EXISTS p_vocab_progress_isolation ON users_vocabularyprogress;
        DROP POLICY IF EXISTS p_vocab_progress_sec_p0 ON users_vocabularyprogress;

        CREATE POLICY p_vocab_progress_sec_p0 ON users_vocabularyprogress
            FOR ALL TO authenticated
            USING (
                usuario_id IN (SELECT id FROM users_userprofile WHERE supabase_uid::text = auth.uid()::text)
            )
            WITH CHECK (
                usuario_id IN (SELECT id FROM users_userprofile WHERE supabase_uid::text = auth.uid()::text)
            );
    END IF;

    -- users_cosmetics
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users_cosmetics') THEN
        DROP POLICY IF EXISTS p_cosmetics_isolation ON users_cosmetics;
        DROP POLICY IF EXISTS p_cosmetics_sec_p0 ON users_cosmetics;

        CREATE POLICY p_cosmetics_sec_p0 ON users_cosmetics
            FOR ALL TO authenticated
            USING (
                user_id IN (SELECT id FROM users_userprofile WHERE supabase_uid::text = auth.uid()::text)
            )
            WITH CHECK (
                user_id IN (SELECT id FROM users_userprofile WHERE supabase_uid::text = auth.uid()::text)
            );
    END IF;

    -- users_cosmetic_purchases
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users_cosmetic_purchases') THEN
        DROP POLICY IF EXISTS p_purchases_isolation ON users_cosmetic_purchases;
        DROP POLICY IF EXISTS p_purchases_sec_p0 ON users_cosmetic_purchases;

        CREATE POLICY p_purchases_sec_p0 ON users_cosmetic_purchases
            FOR ALL TO authenticated
            USING (
                user_id IN (SELECT id FROM users_userprofile WHERE supabase_uid::text = auth.uid()::text)
            )
            WITH CHECK (
                user_id IN (SELECT id FROM users_userprofile WHERE supabase_uid::text = auth.uid()::text)
            );
    END IF;

    -- users_filaexerciciousuario (coluna: usuario_id)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users_filaexerciciousuario') THEN
        DROP POLICY IF EXISTS p_fila_exercicio_isolation ON users_filaexerciciousuario;
        DROP POLICY IF EXISTS p_fila_exercicio_sec_p0 ON users_filaexerciciousuario;

        CREATE POLICY p_fila_exercicio_sec_p0 ON users_filaexerciciousuario
            FOR ALL TO authenticated
            USING (
                usuario_id IN (SELECT id FROM users_userprofile WHERE supabase_uid::text = auth.uid()::text)
            )
            WITH CHECK (
                usuario_id IN (SELECT id FROM users_userprofile WHERE supabase_uid::text = auth.uid()::text)
            );
    END IF;

    -- users_push_tokens (user_id)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users_push_tokens') THEN
        DROP POLICY IF EXISTS p_push_tokens_isolation ON users_push_tokens;
        DROP POLICY IF EXISTS p_push_tokens_sec_p0 ON users_push_tokens;

        CREATE POLICY p_push_tokens_sec_p0 ON users_push_tokens
            FOR ALL TO authenticated
            USING (
                user_id IN (SELECT id FROM users_userprofile WHERE supabase_uid::text = auth.uid()::text)
            )
            WITH CHECK (
                user_id IN (SELECT id FROM users_userprofile WHERE supabase_uid::text = auth.uid()::text)
            );
    END IF;

    -- notification_queue (user_id)
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notification_queue') THEN
        DROP POLICY IF EXISTS p_notif_queue_isolation ON notification_queue;
        DROP POLICY IF EXISTS p_notif_queue_sec_p0 ON notification_queue;

        CREATE POLICY p_notif_queue_sec_p0 ON notification_queue
            FOR SELECT TO authenticated
            USING (
                user_id IN (SELECT id FROM users_userprofile WHERE supabase_uid::text = auth.uid()::text)
            );
    END IF;
END $$;


-- ── 9. POLÍTICAS DO CATÁLOGO EDUCACIONAL (LEITURA PÚBLICA, ESCRITA RESTRITA) ─

DO $$
BEGIN
    -- trilha_variantetupi
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'trilha_variantetupi') THEN
        DROP POLICY IF EXISTS p_read_variante ON trilha_variantetupi;
        CREATE POLICY p_read_variante ON trilha_variantetupi
            FOR SELECT TO anon, authenticated
            USING (ativo = true);
    END IF;

    -- trilha_trilhahistorica
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'trilha_trilhahistorica') THEN
        DROP POLICY IF EXISTS p_read_trilha ON trilha_trilhahistorica;
        CREATE POLICY p_read_trilha ON trilha_trilhahistorica
            FOR SELECT TO anon, authenticated
            USING (publicada = true);
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
            USING (true);
    END IF;

    -- trilha_vocabularyitem
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'trilha_vocabularyitem') THEN
        DROP POLICY IF EXISTS p_read_vocab ON trilha_vocabularyitem;
        CREATE POLICY p_read_vocab ON trilha_vocabularyitem
            FOR SELECT TO anon, authenticated
            USING (true);
    END IF;
END $$;


-- ── 10. GRANTS SISTEMÁTICOS DE TABELA E SEQUÊNCIA PARA ROLES POSTGREST ────────
-- PostgREST exige permissões de tabela para que as políticas RLS possam ser avaliadas.
-- anon recebe SELECT nas tabelas de catálogo educacional, e NENHUM acesso às tabelas privadas.
-- authenticated recebe ALL nas tabelas de usuário (filtradas por RLS) e SELECT no catálogo.

DO $$
DECLARE
    tbl text;
    private_tables text[] := ARRAY[
        'users_userprofile',
        'users_daily_study_log',
        'users_historicoresposta',
        'users_userlesson',
        'trilha_userchestreward',
        'nivelamento_uservariantelevel',
        'nivelamento_testattempt',
        'nivelamento_birdbraincalibrationlog',
        'users_userachievement',
        'users_vocabularyprogress',
        'users_cosmetics',
        'users_cosmetic_purchases',
        'users_filaexerciciousuario',
        'users_push_tokens',
        'notification_queue'
    ];
    catalog_tables text[] := ARRAY[
        'trilha_variantetupi',
        'trilha_trilhahistorica',
        'trilha_capitulo',
        'trilha_licao',
        'trilha_storyblock',
        'trilha_exercicio',
        'trilha_vocabularyitem'
    ];
BEGIN
    -- Tabelas privadas de usuário
    FOREACH tbl IN ARRAY private_tables
    LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = tbl) THEN
            EXECUTE format('REVOKE ALL ON public.%I FROM anon;', tbl);
            EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON public.%I TO authenticated;', tbl);
            EXECUTE format('GRANT ALL ON public.%I TO service_role, postgres;', tbl);
        END IF;
    END LOOP;

    -- Catálogo educacional
    FOREACH tbl IN ARRAY catalog_tables
    LOOP
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = tbl) THEN
            EXECUTE format('GRANT SELECT ON public.%I TO anon, authenticated;', tbl);
            EXECUTE format('REVOKE INSERT, UPDATE, DELETE ON public.%I FROM anon, authenticated;', tbl);
            EXECUTE format('GRANT ALL ON public.%I TO service_role, postgres;', tbl);
        END IF;
    END LOOP;

    -- Sequências públicas (necessárias para inserções gerarem IDs)
    GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;
    GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO service_role;
END $$;

