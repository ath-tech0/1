PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  telegram_id TEXT NOT NULL UNIQUE,
  username TEXT,
  role TEXT NOT NULL CHECK (role IN ('owner','reseller')),
  parent_id INTEGER REFERENCES users(id),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','suspended')),
  key_quota INTEGER NOT NULL DEFAULT 0,
  can_create_subreseller INTEGER NOT NULL DEFAULT 0,
  can_unlimited_key INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS licenses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  key_hash TEXT NOT NULL UNIQUE,
  key_last4 TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','revoked','suspended')),
  created_by INTEGER NOT NULL REFERENCES users(id),
  batch_id TEXT,
  created_at TEXT NOT NULL,
  expires_at TEXT,
  device_limit INTEGER,
  bound_device_hash TEXT,
  reset_count INTEGER NOT NULL DEFAULT 0,
  created_feature TEXT NOT NULL DEFAULT 'premium_access'
);

CREATE TABLE IF NOT EXISTS batches (
  id TEXT PRIMARY KEY,
  created_by INTEGER NOT NULL REFERENCES users(id),
  total_keys INTEGER NOT NULL,
  validity_days INTEGER,
  device_limit INTEGER,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS audit_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  actor_telegram_id TEXT NOT NULL,
  action TEXT NOT NULL,
  target TEXT,
  details TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_licenses_key_hash ON licenses(key_hash);
CREATE INDEX IF NOT EXISTS idx_licenses_created_by ON licenses(created_by);
CREATE INDEX IF NOT EXISTS idx_users_parent_id ON users(parent_id);
