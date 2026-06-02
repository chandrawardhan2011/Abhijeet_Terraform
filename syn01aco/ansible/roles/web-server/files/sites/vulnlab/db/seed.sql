-- Vulnerable lab seed data. Fake users, fake secrets, one flag.

CREATE TABLE IF NOT EXISTS users (
  id       INTEGER PRIMARY KEY,
  username TEXT NOT NULL,
  email    TEXT NOT NULL,
  password TEXT NOT NULL,
  role     TEXT NOT NULL DEFAULT 'user'
);

CREATE TABLE IF NOT EXISTS secrets (
  id       INTEGER PRIMARY KEY,
  owner_id INTEGER NOT NULL,
  content  TEXT NOT NULL,
  FOREIGN KEY (owner_id) REFERENCES users(id)
);

INSERT OR IGNORE INTO users (id, username, email, password, role) VALUES
  (1, 'alice', 'alice@lab.local', 'alice123',     'user'),
  (2, 'bob',   'bob@lab.local',   'hunter2',      'user'),
  (3, 'admin', 'admin@lab.local', 'S3cr3tP@ss!',  'admin');

INSERT OR IGNORE INTO secrets (id, owner_id, content) VALUES
  (1, 1, 'alice diary: forgot password again'),
  (2, 2, 'bob notes: order pizza for friday'),
  (3, 3, 'FLAG{vulnlab_idor_sqli_admin_secret}');
