bring cloud;

bring "./base.w" as base;
bring "../libs" as libs;
bring "../schemas.w" as schemas;

struct ArticleFilter {
  userId: num?;
  slug: str?;
  tag: str?;
  author: str?;
  favorited: str?;
  limit: num?;
  offset: num?;
}

pub class Articles extends base.Base {
  new(api: cloud.Api, db: libs.Db) {
    super(api, db);

    let newArticleFilter = inflight (query: Map<str>, userId: num?) => {
      return ArticleFilter {
        userId: userId,
        author: query.tryGet("author"),
        favorited: query.tryGet("favorited"),
        limit: libs.Helpers.parseInt(query.tryGet("limit") ?? "20"),
        offset: libs.Helpers.parseInt(query.tryGet("offset") ?? "0"),
        slug: query.tryGet("slug"),
        tag: query.tryGet("tag"),
      };
    };

    let updateTags = inflight (articleId: num, tagList: Array<str>?) => {
      if let tagList = tagList {
        let sqls = MutArray<libs.Statement>[
          {
            sql: "DELETE FROM article_tag WHERE article_id = :articleId",
            args: {
              articleId: articleId,
            },
          },
        ];

        for tag in tagList {
          db.execute(
            "INSERT INTO tags (name) VALUES (:name) ON CONFLICT DO NOTHING",
            {
              name: tag,
            },
          );

          sqls.push(
            {
              sql: "INSERT INTO article_tag (article_id, tag_id) VALUES (:articleId, (SELECT id FROM tags WHERE name = :name))",
              args: {
                articleId: articleId,
                name: tag,
              },
            },
          );
        }

        db.batch(unsafeCast(sqls));
      }
    };

    let getArticles = inflight (filter: ArticleFilter?): schemas.MultipleArticlesResponse => {
      let var sql = "
      SELECT
        *,
        IIF(user_article_favorite.user_id IS NULL, false, true) AS favorited,
        json_patch(author_, json_object('following', IIF(user_follow.follow_id IS NULL, false, true))) AS author
      FROM articles_view
      LEFT JOIN user_article_favorite ON (user_article_favorite.user_id = :userId AND user_article_favorite.article_id = articles_view.id)
      LEFT JOIN user_follow ON (user_follow.user_id = :userId AND user_follow.follow_id = articles_view.author_id)
      WHERE true
      ";

      if filter?.tag? {
        sql += " AND EXISTS (SELECT 1 FROM json_each(tag_list) WHERE value = :tag) ";
      }

      if filter?.slug? {
        sql += " AND slug = :slug ";
      }

      if filter?.author? {
        sql += " AND json_extract(author, '$.username') = :author ";
      }

      if filter?.favorited? {
        sql += " AND EXISTS (SELECT 1 FROM user_article_favorite WHERE user_id = (SELECT id FROM users WHERE username = :favorited) AND article_id = articles_view.id)";
      }

      let resultCount = db.fetchOne("SELECT COUNT(*) AS count FROM ({sql})", {
        userId: filter?.userId ?? 0,
        slug: filter?.slug ?? "",
        favorited: filter?.favorited ?? "",
        tag: filter?.tag ?? "",
        author: filter?.author ?? "",
        limit: filter?.limit ?? 20,
        offset: filter?.offset ?? 0,
      });

      sql += " ORDER BY id DESC ";

      if filter?.limit? {
        sql += " LIMIT :limit";
      }

      if filter?.offset? {
        sql += " OFFSET :offset";
      }

      let result = db.fetchAll(sql, {
        userId: filter?.userId ?? 0,
        slug: filter?.slug ?? "",
        favorited: filter?.favorited ?? "",
        tag: filter?.tag ?? "",
        author: filter?.author ?? "",
        limit: filter?.limit ?? 20,
        offset: filter?.offset ?? 0,
      });

      let articles = MutArray<schemas.Article>[];

      for row in result {
        let article = schemas.ArticleFullDb.fromJson(row);

        let author = schemas.ProfileDb.parseJson(article.author);
        let tagList = Json.parse(article.tag_list);

        articles.push(
          schemas.Article {
            author: {
              bio: author.bio,
              following: author.following == 1,
              image: author.image,
              username: author.username,
            },
            body: article.body,
            createdAt: article.created_at,
            description: article.description,
            favorited: article.favorited == 1,
            favoritesCount: article.favorites_count,
            slug: article.slug,
            title: article.title,
            updatedAt: article.updated_at,
            tagList: libs.Helpers.sorted(unsafeCast(tagList)),
          }
        );
      }

      return schemas.MultipleArticlesResponse {
        articles: unsafeCast(articles),
        articlesCount: resultCount?.get("count")?.asNum() ?? 0,
      };
    };

    let getArticle = inflight (userId: num?, slug: str?) => {
      let articles = getArticles(userId: userId, slug: slug);

      if articles.articles.length == 0 {
        throw "404: article not found";
      }

      return schemas.SingleArticleResponse {
        article: articles.articles.at(0),
      };
    };

    let getComments = inflight (userId: num?, slug: str?): schemas.MultipleCommentsResponse=> {
      let var sql = "
      SELECT
        *,
        json_patch(author_, json_object('following', IIF(user_follow.follow_id IS NULL, false, true))) AS author
      FROM comments_view
      LEFT JOIN user_follow ON (user_follow.user_id = :userId AND user_follow.follow_id = comments_view.author_id)
      ";

      if slug? {
        sql += " WHERE article_id = (SELECT id FROM articles WHERE slug = :slug) ";
      }

      let result = db.fetchAll(sql, {
        userId: userId ?? 0,
        slug: slug,
      });

      let comments = MutArray<schemas.Comment>[];

      for row in result {
        let comment = schemas.CommentWithProfileDb.fromJson(row);

        let author = schemas.ProfileDb.parseJson(comment.author);

        comments.push({
          id: comment.id,
          body: comment.body,
          createdAt: comment.created_at,
          updatedAt: comment.updated_at,
          author: {
            username: author.username,
            bio: author.bio,
            image: author.image,
            following: author.following == 1,
          },
        });
      }

      return schemas.MultipleCommentsResponse {
        comments: unsafeCast(comments),
      };
    };

    api.get("/api/articles", inflight (req) => {
      return libs.Middleware.loginRequired(false, req, (token) => {
        return getArticles(newArticleFilter(req.query, token?.id));
      });
    });

    api.get("/api/articles/:slug", inflight (req) => {
      return libs.Middleware.loginRequired(true, req, (token) => {
        let userId = token!.id;
        let slug = req.vars.get("slug");

        if slug == "feed" {
          return getArticles(newArticleFilter(req.query, userId));
        } else {
          return getArticle(userId, slug);
        }
      });
    });

    api.post("/api/articles", inflight (req) => {
      return libs.Middleware.loginRequired(true, req, (token) => {
        let userId = token!.id;

        let body = schemas.NewArticleRequest.parseJson(req.body!);

        if let result = db.fetchOne(
          "
          INSERT INTO articles (slug, title, description, body, author_id)
          VALUES (:slug, :title, :description, :body, :author_id)
          RETURNING *
          ",
          {
            slug: libs.Helpers.slugify(body.article.title),
            title: body.article.title,
            description: body.article.description,
            body: body.article.body,
            author_id: userId,
          }
        ) {
          let article = schemas.ArticleDb.fromJson(result);

          updateTags(article.id, body.article.tagList);

          return getArticle(nil, article.slug);
        }
      });
    });

    api.put("/api/articles/:slug", inflight (req) => {
      return libs.Middleware.loginRequired(true, req, (token) => {
        let userId = token!.id;
        let slug = req.vars.get("slug");

        let body = schemas.UpdateArticleRequest.parseJson(req.body!);

        if let result = db.fetchOne("SELECT * FROM articles WHERE slug = :slug AND author_id = :userId", {
          slug: slug,
          userId: userId,
        }) {
          let article = schemas.ArticleDb.fromJson(result);

          let var newSlug = article.slug;

          if body.article.title? {
            newSlug = libs.Helpers.slugify(body.article.title!);
          }

          db.execute("
          UPDATE articles SET slug = :slug, title = :title, description = :description, body = :body
          WHERE id = :id
          ", {
            slug: newSlug,
            title: body.article.title ?? article.title,
            description: body.article.description ?? article.description,
            body: body.article.body ?? article.body,
            id: article.id,
          });

          return getArticle(nil, article.slug);
        }
      });
    });

    api.delete("/api/articles/:slug", inflight (req) => {
      return libs.Middleware.loginRequired(true, req, (token) => {
        let userId = token!.id;
        let slug = req.vars.get("slug");

        db.execute(
          "DELETE FROM articles WHERE slug = :slug AND author_id = :userId",
          {
            slug: slug,
            userId: userId,
          },
        );

        return {};
      });
    });

    api.post("/api/articles/:slug/comments", inflight (req) => {
      return libs.Middleware.loginRequired(true, req, (token) => {
        let userId = token!.id;
        let slug = req.vars.get("slug");

        let body = schemas.NewCommentRequest.parseJson(req.body!);

        db.execute(
          "
          INSERT INTO comments (body, article_id, author_id)
          VALUES (:body, (SELECT id FROM articles WHERE slug = :slug), :userId)
          ",
          {
            body: body.comment.body,
            slug: slug,
            userId: userId,
          },
        );

        let comments = getComments(userId, slug);

        return schemas.SingleCommentResponse {
          comment: comments.comments.at(0)
        };
      });
    });

    api.get("/api/articles/:slug/comments", inflight (req) => {
      return libs.Middleware.loginRequired(false, req, (token) => {
        let slug = req.vars.get("slug");

        return getComments(token?.id, slug);
      });
    });

    api.delete("/api/articles/:slug/comments/:id", inflight (req) => {
      return libs.Middleware.loginRequired(true, req, (token) => {
        let userId = token!.id;
        let id = req.vars.get("id");

        db.execute(
          "DELETE FROM comments WHERE id = :commentId AND author_id = :userId",
          {
            commentId: id,
            userId: userId,
          },
        );

        return {};
      });
    });

    api.post("/api/articles/:slug/favorite", inflight (req) => {
      return libs.Middleware.loginRequired(true, req, (token) => {
        let userId = token!.id;
        let slug = req.vars.get("slug");

        db.batch(
          [
            {
              sql: "INSERT INTO user_article_favorite (user_id, article_id) VALUES (:userId, (SELECT id FROM articles WHERE slug = :slug))",
              args: {
                userId: userId,
                slug: slug,
              },
            },
            {
              sql: "UPDATE articles SET favorites_count = favorites_count + 1 WHERE slug = :slug",
              args: {
                slug: slug,
              }
            },
          ],
        );

        return getArticle(userId, slug);
      });
    });

    api.delete("/api/articles/:slug/favorite", inflight (req) => {
      return libs.Middleware.loginRequired(true, req, (token) => {
        let userId = token!.id;
        let slug = req.vars.get("slug");

        db.batch(
          [
            {
              sql: "DELETE FROM user_article_favorite WHERE user_id = :userId AND article_id = (SELECT id FROM articles WHERE slug = :slug)",
              args: {
                userId: userId,
                slug: slug,
              },
            },
            {
              sql: "UPDATE articles SET favorites_count = favorites_count - 1 WHERE slug = :slug",
              args: {
                slug: slug,
              }
            },
          ],
        );

        return getArticle(userId, slug);
      });
    });
  }
}
