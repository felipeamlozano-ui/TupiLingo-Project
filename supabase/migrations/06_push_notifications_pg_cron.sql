-- =============================================================================
-- TupiLingo — Migration 06: Sistema de Notificações Android & pg_cron
-- =============================================================================

-- ── 1. TABELA DE TOKENS PUSH DOS DISPOSITIVOS ────────────────────────────────
CREATE TABLE IF NOT EXISTS users_push_tokens (
    id                             BIGSERIAL PRIMARY KEY,
    user_id                        INTEGER NOT NULL REFERENCES users_userprofile(id) ON DELETE CASCADE,
    fcm_token                      TEXT NOT NULL,
    device_os                      VARCHAR(20) NOT NULL DEFAULT 'android',
    streak_notifications_enabled   BOOLEAN NOT NULL DEFAULT TRUE,
    content_notifications_enabled  BOOLEAN NOT NULL DEFAULT TRUE,
    created_at                     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at                     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT users_push_tokens_user_token_uniq UNIQUE (user_id, fcm_token)
);

CREATE INDEX IF NOT EXISTS idx_push_tokens_user_id
    ON users_push_tokens(user_id);

-- ── 2. FILA DE NOTIFICAÇÕES (DISPATCH ATÔMICO) ──────────────────────────────
CREATE TABLE IF NOT EXISTS notification_queue (
    id                  BIGSERIAL PRIMARY KEY,
    user_id             INTEGER NOT NULL REFERENCES users_userprofile(id) ON DELETE CASCADE,
    title               VARCHAR(200) NOT NULL,
    body                TEXT NOT NULL,
    notification_type   VARCHAR(50) NOT NULL DEFAULT 'streak_reminder',
    payload             JSONB DEFAULT '{}'::jsonb,
    status              VARCHAR(20) NOT NULL DEFAULT 'pending',
    scheduled_for       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sent_at             TIMESTAMPTZ,
    error_message       TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notif_queue_status_sched
    ON notification_queue (status, scheduled_for);

CREATE INDEX IF NOT EXISTS idx_notif_queue_user
    ON notification_queue (user_id, status);

-- ── 3. FUNÇÃO: ENFILEIRAR LEMBRETES DE OFENSIVA (STREAK EM RISCO) ─────────────
-- Executada às 18:00 (Brasília) para alertar quem tem ofensiva ativa e ainda não praticou hoje.
CREATE OR REPLACE FUNCTION fn_queue_streak_reminders()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    today_br date;
    v_queued_count integer := 0;
BEGIN
    today_br := (CURRENT_TIMESTAMP AT TIME ZONE 'America/Sao_Paulo')::date;

    -- Enfileira notificação para usuários com streak ativo (> 0) que NÃO estudaram hoje
    INSERT INTO notification_queue (user_id, title, body, notification_type, payload, status)
    SELECT 
        u.id,
        '🔥 Sua ofensiva no TupiLingo está em perigo!',
        CASE 
            WHEN u.streak_atual = 1 THEN 'Você começou sua jornada ontem. Não perca seu ritmo: pratique 3 minutos de Tupi agora!'
            ELSE 'Você já conquistou ' || u.streak_atual || ' dias seguidos! Entre agora antes da meia-noite e mantenha o fogo aceso!'
        END,
        'streak_reminder',
        jsonb_build_object('streak_atual', u.streak_atual, 'target_route', '/home'),
        'pending'
    FROM users_userprofile u
    INNER JOIN users_push_tokens pt ON pt.user_id = u.id AND pt.streak_notifications_enabled = TRUE
    WHERE u.streak_atual > 0
      AND (u.ultimo_dia_estudado IS NULL OR u.ultimo_dia_estudado < today_br)
      -- Evita duplicidade no mesmo dia
      AND NOT EXISTS (
          SELECT 1 FROM notification_queue nq
          WHERE nq.user_id = u.id
            AND nq.notification_type = 'streak_reminder'
            AND nq.created_at::date = today_br
      );

    GET DIAGNOSTICS v_queued_count = ROW_COUNT;
    RETURN v_queued_count;
END;
$$;

-- ── 4. FUNÇÃO: ENFILEIRAR NOTIFICAÇÕES DE CONTEÚDO NOVO E DESAFIOS ─────────────
CREATE OR REPLACE FUNCTION fn_queue_new_content_notifications()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    today_br date;
    v_queued_count integer := 0;
BEGIN
    today_br := (CURRENT_TIMESTAMP AT TIME ZONE 'America/Sao_Paulo')::date;

    -- Envia lembrete semanal de novidades e curiosidades culturais
    INSERT INTO notification_queue (user_id, title, body, notification_type, payload, status)
    SELECT 
        u.id,
        '🌿 Novos Saberes de Pindorama!',
        'Capítulos, desafios temáticos e tesouros ancestrais esperam por você. Venha expandir seu vocabulário Tupi!',
        'new_content',
        jsonb_build_object('target_route', '/practice'),
        'pending'
    FROM users_userprofile u
    INNER JOIN users_push_tokens pt ON pt.user_id = u.id AND pt.content_notifications_enabled = TRUE
    WHERE NOT EXISTS (
        SELECT 1 FROM notification_queue nq
        WHERE nq.user_id = u.id
          AND nq.notification_type = 'new_content'
          AND nq.created_at > (NOW() - INTERVAL '6 days')
    );

    GET DIAGNOSTICS v_queued_count = ROW_COUNT;
    RETURN v_queued_count;
END;
$$;

-- ── 5. AGENDAMENTO NO PG_CRON DO SUPABASE ─────────────────────────────────────
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        -- Remove jobs antigos caso existam para idempotência
        PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'tupilingo_streak_reminder_daily';
        PERFORM cron.unschedule(jobid) FROM cron.job WHERE jobname = 'tupilingo_content_notification_weekly';

        -- 1. Lembrete diário de Streak: 21:00 UTC = 18:00 Horário de Brasília
        PERFORM cron.schedule(
            'tupilingo_streak_reminder_daily',
            '0 21 * * *',
            'SELECT fn_queue_streak_reminders();'
        );

        -- 2. Conteúdo novo e evento semanal: Todo sábado às 14:00 UTC = 11:00 Horário de Brasília
        PERFORM cron.schedule(
            'tupilingo_content_notification_weekly',
            '0 14 * * 6',
            'SELECT fn_queue_new_content_notifications();'
        );

        RAISE NOTICE 'pg_cron jobs tupilingo_streak_reminder_daily e content_notification_weekly agendados!';
    ELSE
        RAISE WARNING 'Extensão pg_cron não está habilitada nesta instância do banco.';
    END IF;
END $$;
