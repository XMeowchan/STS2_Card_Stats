CREATE TABLE IF NOT EXISTS installs (
  client_hash TEXT PRIMARY KEY,
  first_seen_day TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS daily_activity (
  day TEXT NOT NULL,
  client_hash TEXT NOT NULL,
  mod_version TEXT,
  platform TEXT,
  created_at TEXT NOT NULL,
  PRIMARY KEY (day, client_hash)
);

CREATE INDEX IF NOT EXISTS idx_installs_first_seen_day
  ON installs(first_seen_day);

CREATE INDEX IF NOT EXISTS idx_daily_activity_client_hash
  ON daily_activity(client_hash);
