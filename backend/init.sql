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
  title TEXT,
  description TEXT,
  body TEXT,
  created_at TEXT DEFAULT (strftime('%FT%R:%fZ', 'now', 'localtime')),
  updated_at TEXT DEFAULT (strftime('%FT%R:%fZ', 'now', 'localtime')),
  favorites_count INTEGER DEFAULT 0,
  author_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS comments (
  id INTEGER PRIMARY KEY,
  created_at TEXT DEFAULT (strftime('%FT%R:%fZ', 'now', 'localtime')),
  updated_at TEXT DEFAULT (strftime('%FT%R:%fZ', 'now', 'localtime')),
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
  follow_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, follow_id)
);

CREATE TABLE IF NOT EXISTS user_article_favorite (
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  article_id INTEGER NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, article_id)
);

CREATE TABLE IF NOT EXISTS article_tag (
  article_id INTEGER NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  tag_id INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (article_id, tag_id)
);

CREATE VIEW IF NOT EXISTS articles_view AS
  SELECT
    articles.*,
    json_group_array(tags.name) as tag_list,
    json_object(
      'username', author.username,
      'bio', author.bio,
      'image', author.image
    ) AS author_
  FROM articles
  LEFT JOIN users AS author ON (author.id = articles.author_id)
  LEFT JOIN article_tag ON (article_tag.article_id = articles.id)
  LEFT JOIN tags ON (tags.id = article_tag.tag_id)
  GROUP BY articles.id


CREATE VIEW IF NOT EXISTS comments_view AS
  SELECT
    *,
    json_object(
      'username', author.username,
      'bio', author.bio,
      'image', author.image
    ) AS author_
  FROM comments
  LEFT JOIN users AS author ON (author.id = comments.author_id)
