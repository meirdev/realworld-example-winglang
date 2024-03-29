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
      WITH article_list AS (
        SELECT
          articles.*,
          IIF(user_article_favorite.user_id IS NULL, false, true) AS favorited,
          json_group_array(tags.name) as tag_list,
          json_object(
            'username', author.username,
            'bio', author.bio,
            'image', author.image,
            'following', IIF(user_follow.follow_id IS NULL, false, true)
          ) AS author
        FROM articles
        LEFT JOIN users AS author ON (author.id = articles.author_id)
        LEFT JOIN article_tag ON (article_tag.article_id = articles.id)
        LEFT JOIN tags ON (tags.id = article_tag.tag_id)
        LEFT JOIN user_article_favorite ON (user_article_favorite.user_id = :userId AND user_article_favorite.article_id = articles.id)
        LEFT JOIN user_follow ON (user_follow.user_id = :userId AND user_follow.follow_id = articles.author_id)
        GROUP BY articles.id
      )
      SELECT * FROM article_list WHERE article_list.id IS NOT NULL 
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
        sql += " AND favorited = :favorited ";
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

    let getComments = inflight (userId: num?, slug: str?): schemas.MultipleCommentsResponse=> {
      let var sql = "
      SELECT
        *,
        json_object(
          'username', author.username,
          'bio', author.bio,
          'image', author.image,
          'following', IIF(user_follow.follow_id IS NULL, false, true)
        ) AS author
      FROM comments
      LEFT JOIN users AS author ON (author.id = comments.author_id)
      LEFT JOIN user_follow ON (user_follow.user_id = :userId AND user_follow.follow_id = comments.author_id)
      ";

      if slug? {
        sql += " WHERE article_id = (SELECT id FROM articles WHERE slug = :slug) ";
      }

      let result = db.fetchAll(sql, {
        userId: userId,
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
      return libs.Auth.loginNotRequired(req, (token) => {
        let articles = getArticles(newArticleFilter(req.query, token?.id));

        return {
          body: Json.stringify(articles),
        };
      });
    });

    api.get("/api/articles/:slug", inflight (req) => {
      return libs.Auth.loginRequired(req, (token) => {
        let slug = req.vars.get("slug");

        if slug == "feed" {
          let articles = getArticles(newArticleFilter(req.query, token.id));

          return {
            body: Json.stringify(articles),
          };
        } else {
          let articles = getArticles(userId: token.id, slug: slug);

          if articles.articlesCount == 0 {
            throw "404: not found";
          }

          return {
            body: Json.stringify(schemas.SingleArticleResponse {
              article: articles.articles.at(0),
            }),
          };
        }
      });
    });

    api.post("/api/articles", inflight (req) => {
      return libs.Auth.loginRequired(req, (token) => {
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
            author_id: token.id,
          }
        ) {
          let article = schemas.ArticleDb.fromJson(result);

          log("{Json.stringify(article)}");

          updateTags(article.id, body.article.tagList);

          let articles = getArticles(slug: article.slug);

          return {
            body: Json.stringify(schemas.SingleArticleResponse {
              article: articles.articles.at(0),
            }),
          };
        }
      });
    });

    api.put("/api/articles/:slug", inflight (req) => {
      return libs.Auth.loginRequired(req, (token) => {
        let slug = req.vars.get("slug");

        let body = schemas.UpdateArticleRequest.parseJson(req.body!);

        return {};
      });
    });

    api.delete("/api/articles/:slug", inflight (req) => {
      return libs.Auth.loginRequired(req, (token) => {
        let slug = req.vars.get("slug");

        db.execute(
          "DELETE FROM articles WHERE slug = :slug AND author_id = :userId",
          {
            slug: slug,
            userId: token.id,
          },
        );

        return {};
      });
    });

    api.post("/api/articles/:slug/comments", inflight (req) => {
      return libs.Auth.loginRequired(req, (token) => {
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
            userId: token.id,
          },
        );

        let comments = getComments(token.id, slug);

        return {
          body: Json.stringify(schemas.SingleCommentResponse {
            comment: comments.comments.at(0)
          }),
        };
      });
    });

    api.get("/api/articles/:slug/comments", inflight (req) => {
      return libs.Auth.loginNotRequired(req, (token) => {
        let slug = req.vars.get("slug");

        let comments = getComments(token?.id, slug);

        return {
          body: Json.stringify(comments),
        };
      });
    });

    api.delete("/api/articles/:slug/comments/:id", inflight (req) => {
      return libs.Auth.loginRequired(req, (token) => {
        let id = req.vars.get("id");

        db.execute(
          "DELETE FROM comments WHERE id = :commentId AND author_id = :userId",
          {
            commentId: id,
            userId: token.id,
          },
        );

        return {};
      });
    });

    api.post("/api/articles/:slug/favorite", inflight (req) => {
      return libs.Auth.loginRequired(req, (token) => {
        let slug = req.vars.get("slug");

        db.batch(
          [
            {
              sql: "INSERT INTO user_article_favorite (user_id, article_id) VALUES (:userId, (SELECT id FROM articles WHERE slug = :slug))",
              args: {
                userId: token.id,
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

        let articles = getArticles(slug: slug);

        return {
          body: Json.stringify(schemas.SingleArticleResponse {
            article: articles.articles.at(0),
          }),
        };
      });
    });

    api.delete("/api/articles/:slug/favorite", inflight (req) => {
      return libs.Auth.loginRequired(req, (token) => {
        let slug = req.vars.get("slug");

        db.batch(
          [
            {
              sql: "DELETE FROM user_article_favorite WHERE user_id = :userId AND article_id = (SELECT id FROM articles WHERE slug = :slug)",
              args: {
                userId: token.id,
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

        let articles = getArticles(slug: slug);

        return {
          body: Json.stringify(schemas.SingleArticleResponse {
            article: articles.articles.at(0),
          }),
        };
      });
    });
  }
}
