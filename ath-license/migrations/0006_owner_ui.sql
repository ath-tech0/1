CREATE TABLE IF NOT EXISTS ui_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  actor_telegram_id TEXT NOT NULL,
  action TEXT NOT NULL,
  payload TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
