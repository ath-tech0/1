CREATE TABLE IF NOT EXISTS api_nonces (
  nonce_hash TEXT PRIMARY KEY,
  seen_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_api_nonces_seen_at ON api_nonces(seen_at);
