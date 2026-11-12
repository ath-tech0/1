ALTER TABLE licenses ADD COLUMN validity_days INTEGER;

CREATE TABLE IF NOT EXISTS ui_sessions (
  actor_telegram_id TEXT PRIMARY KEY,
  action TEXT NOT NULL,
  expires_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_ui_sessions_expires ON ui_sessions(expires_at);
