CREATE TABLE IF NOT EXISTS pending_actions (
  id TEXT PRIMARY KEY,
  actor_telegram_id TEXT NOT NULL,
  action TEXT NOT NULL,
  payload TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  used_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_pending_actor ON pending_actions(actor_telegram_id, expires_at);
CREATE INDEX IF NOT EXISTS idx_audit_created_at ON audit_logs(created_at);
