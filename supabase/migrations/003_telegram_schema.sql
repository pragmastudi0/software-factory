-- ═══════════════════════════════════════════════════════════════════
--  003_telegram_schema.sql
--  Telegram Bot — Conversation State, Approvals & Notification Log
-- ═══════════════════════════════════════════════════════════════════

CREATE TYPE telegram_approval_status AS ENUM (
  'pending',
  'approved',
  'rejected',
  'postponed',
  'expired'
);

-- ────────────────────────────────────────────────────────────────────
-- TABLE: telegram_conversations
-- Per-user conversation state for the Telegram bot (state machine)
-- ────────────────────────────────────────────────────────────────────

CREATE TABLE telegram_conversations (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id          BIGINT NOT NULL UNIQUE,
  username         TEXT,
  first_name       TEXT,
  project_id       UUID REFERENCES projects(id) ON DELETE SET NULL,
  last_command     TEXT,
  -- State machine values:
  -- idle | awaiting_idea | awaiting_feedback_text | awaiting_improvement
  -- | awaiting_project_select | awaiting_command_args
  state            TEXT NOT NULL DEFAULT 'idle',
  context          JSONB DEFAULT '{}',
  message_history  JSONB DEFAULT '[]',
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_telegram_conv_chat_id ON telegram_conversations(chat_id);

-- ────────────────────────────────────────────────────────────────────
-- TABLE: telegram_approvals
-- Tracks approval requests sent to users via inline keyboards
-- Callback data format: {action}:{type}:{entity_id}:{approval_id}
-- ────────────────────────────────────────────────────────────────────

CREATE TABLE telegram_approvals (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id        BIGINT NOT NULL,
  approval_type  TEXT NOT NULL,
  -- Types: deploy | start_development | structural_change
  --        data_deletion | refactor | improvement
  entity_id      UUID,
  entity_type    TEXT,
  -- entity_type: project | deployment | task
  callback_data  TEXT NOT NULL UNIQUE,
  message_id     INTEGER,
  status         telegram_approval_status NOT NULL DEFAULT 'pending',
  context        JSONB DEFAULT '{}',
  expires_at     TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '24 hours'),
  responded_at   TIMESTAMPTZ,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_telegram_approvals_chat     ON telegram_approvals(chat_id, status);
CREATE INDEX idx_telegram_approvals_callback ON telegram_approvals(callback_data);
CREATE INDEX idx_telegram_approvals_entity   ON telegram_approvals(entity_id);

-- ────────────────────────────────────────────────────────────────────
-- TABLE: telegram_notification_log
-- Audit trail of every notification sent (prevents duplicates)
-- ────────────────────────────────────────────────────────────────────

CREATE TABLE telegram_notification_log (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chat_id      BIGINT NOT NULL,
  project_id   UUID REFERENCES projects(id) ON DELETE SET NULL,
  event_type   TEXT NOT NULL,
  message_id   INTEGER,
  message_text TEXT NOT NULL,
  sent_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_tg_notif_log_chat    ON telegram_notification_log(chat_id);
CREATE INDEX idx_tg_notif_log_project ON telegram_notification_log(project_id);
CREATE INDEX idx_tg_notif_log_event   ON telegram_notification_log(event_type, sent_at DESC);

-- ────────────────────────────────────────────────────────────────────
-- RLS
-- ────────────────────────────────────────────────────────────────────

ALTER TABLE telegram_conversations      ENABLE ROW LEVEL SECURITY;
ALTER TABLE telegram_approvals          ENABLE ROW LEVEL SECURITY;
ALTER TABLE telegram_notification_log   ENABLE ROW LEVEL SECURITY;

CREATE POLICY "authenticated_full_access_telegram_conversations"
  ON telegram_conversations FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_full_access_telegram_approvals"
  ON telegram_approvals FOR ALL TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_full_access_telegram_notification_log"
  ON telegram_notification_log FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- ────────────────────────────────────────────────────────────────────
-- updated_at trigger
-- ────────────────────────────────────────────────────────────────────

CREATE TRIGGER trg_telegram_conversations_updated_at
  BEFORE UPDATE ON telegram_conversations FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
