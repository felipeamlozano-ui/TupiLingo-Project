-- =============================================================================
-- TupiLingo — Migration 02: Progressão Real, Estatísticas e Ofensiva (pg_cron)
-- =============================================================================

-- ── 1. CAMPOS DE OFENSIVA NO PERFIL DO USUÁRIO ─────────────────────────────────
ALTER TABLE users_userprofile
    ADD COLUMN IF NOT EXISTS streak_atual        INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS maior_streak        INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS ultimo_dia_estudado DATE,
    ADD COLUMN IF NOT EXISTS dias_estudados_total INTEGER NOT NULL DEFAULT 0;

-- ── 2. TABELA DE LOG DIÁRIO DE ESTUDO (MÉTRICAS 100% REAIS) ───────────────────
CREATE TABLE IF NOT EXISTS users_daily_study_log (
    id                     BIGSERIAL PRIMARY KEY,
    user_id                INTEGER NOT NULL REFERENCES users_userprofile(id) ON DELETE CASCADE,
    data                   DATE NOT NULL DEFAULT ((CURRENT_TIMESTAMP AT TIME ZONE 'America/Sao_Paulo')::date),
    xp_ganho               INTEGER NOT NULL DEFAULT 0,
    licoes_concluidas      INTEGER NOT NULL DEFAULT 0,
    exercicios_respondidos INTEGER NOT NULL DEFAULT 0,
    exercicios_corretos    INTEGER NOT NULL DEFAULT 0,
    tempo_estudo_segundos  INTEGER NOT NULL DEFAULT 0,
    created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT users_daily_study_log_user_data_uniq UNIQUE (user_id, data)
);

-- ── 3. TABELA DE AUDITORIA DE BAÚS DE RECOMPENSA COLETADOS ─────────────────────
CREATE TABLE IF NOT EXISTS trilha_userchestreward (
    id                  BIGSERIAL PRIMARY KEY,
    user_id             INTEGER NOT NULL REFERENCES users_userprofile(id) ON DELETE CASCADE,
    capitulo_id         INTEGER NOT NULL REFERENCES trilha_capitulo(id) ON DELETE CASCADE,
    milestone_index     INTEGER NOT NULL DEFAULT 1,
    recompensa_xp       INTEGER NOT NULL DEFAULT 75,
    recompensa_conchas  INTEGER NOT NULL DEFAULT 50,
    coletado_em         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT trilha_userchestreward_user_cap_milestone_uniq UNIQUE (user_id, capitulo_id, milestone_index)
);

-- ── 4. ÍNDICES DE ALTA PERFORMANCE (SCAN RÁPIDO & ZERO N+1) ────────────────────
CREATE INDEX IF NOT EXISTS idx_dailystudylog_user_data
    ON users_daily_study_log (user_id, data DESC);

CREATE INDEX IF NOT EXISTS idx_userlesson_user_status_perf
    ON users_userlesson (usuario_id, status);

CREATE INDEX IF NOT EXISTS idx_vocabprogress_user_rep_perf
    ON users_vocabularyprogress (usuario_id, repetitions);

CREATE INDEX IF NOT EXISTS idx_userchestreward_user_cap
    ON trilha_userchestreward (user_id, capitulo_id);

-- ── 5. FUNÇÃO SQL: RESET DIÁRIO DE OFENSIVAS QUEBRADAS (TIMEZONE BRASIL) ───────
CREATE OR REPLACE FUNCTION fn_check_and_reset_streaks()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    today_br date;
    yesterday_br date;
BEGIN
    today_br := (CURRENT_TIMESTAMP AT TIME ZONE 'America/Sao_Paulo')::date;
    yesterday_br := today_br - 1;

    -- Reseta streak para 0 dos usuários que não estudaram nem ontem nem hoje
    UPDATE users_userprofile
    SET streak_atual = 0,
        updated_at = NOW()
    WHERE streak_atual > 0
      AND (ultimo_dia_estudado IS NULL OR ultimo_dia_estudado < yesterday_br);
END;
$$;

-- ── 6. FUNÇÃO SQL: REGISTRO ATÔMICO DE ATIVIDADE & OFENSIVA ─────────────────────
CREATE OR REPLACE FUNCTION fn_record_user_activity(
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

    -- Registra / acumula no log diário de estudo
    INSERT INTO users_daily_study_log (
        user_id, data, xp_ganho, licoes_concluidas,
        exercicios_respondidos, exercicios_corretos, tempo_estudo_segundos, updated_at
    )
    VALUES (
        p_user_id, today_br, p_xp_ganho,
        CASE WHEN p_is_lesson_completed THEN 1 ELSE 0 END,
        p_exercicios_respondidos, p_exercicios_corretos, p_tempo_segundos, NOW()
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

-- ── 7. AGENDAMENTO AUTOMÁTICO PG_CRON (03:00 UTC = 00:00 BRASÍLIA) ─────────────
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        -- Remove job antigo caso exista para garantir idempotência
        PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'tupilingo_daily_streak_check';

        -- Agenda para rodar todo dia às 03:00 UTC (00:00 no fuso de Brasília)
        PERFORM cron.schedule('tupilingo_daily_streak_check', '0 3 * * *', 'SELECT fn_check_and_reset_streaks();');
        RAISE NOTICE 'Job pg_cron tupilingo_daily_streak_check agendado com sucesso!';
    ELSE
        RAISE WARNING 'Extensão pg_cron não está ativa nesta base.';
    END IF;
END $$;
