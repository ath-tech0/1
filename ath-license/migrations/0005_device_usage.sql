CREATE TABLE IF NOT EXISTS license_devices (
  license_id INTEGER NOT NULL REFERENCES licenses(id) ON DELETE CASCADE,
  device_hash TEXT NOT NULL,
  first_seen_at TEXT NOT NULL DEFAULT (datetime('now')),
  last_seen_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (license_id, device_hash)
);
CREATE INDEX IF NOT EXISTS idx_license_devices_license ON license_devices(license_id);
