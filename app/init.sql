CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY,
  username TEXT UNIQUE,
  email TEXT,
  password TEXT,
  bio TEXT,
  image TEXT
);

CREATE TABLE IF NOT EXISTS articles (
  id INTEGER PRIMARY KEY,
  slug TEXT UNIQUE,
  tilte TEXT,
  description TEXT,
  body TEXT,
  created_at TEXT DEFAULT (strftime('%FT%R:%f', 'now', 'localtime')),
  updated_at TEXT DEFAULT (strftime('%FT%R:%f', 'now', 'localtime')),
  favorites_count INTEGER DEFAULT 0,
  author_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS comments (
  id INTEGER PRIMARY KEY,
  created_at TEXT DEFAULT (strftime('%FT%R:%f', 'now', 'localtime')),
  updated_at TEXT DEFAULT (strftime('%FT%R:%f', 'now', 'localtime')),
  body TEXT,
  author_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  article_id INTEGER NOT NULL REFERENCES articles(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS tags (
  id INTEGER PRIMARY KEY,
  name UNIQUE
);

CREATE TABLE IF NOT EXISTS user_follow (
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  follow_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS user_article_favorite (
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  article_id INTEGER NOT NULL REFERENCES articles(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS article_tag (
  article_id INTEGER NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  tag_id INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE
);
