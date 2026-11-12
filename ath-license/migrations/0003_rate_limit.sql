CREATE TABLE IF NOT EXISTS rate_limits (
  actor TEXT NOT NULL,
  window_start INTEGER NOT NULL,
  request_count INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY(actor, window_start)
);
