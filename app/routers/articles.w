bring cloud;

bring "./base.w" as base;
bring "../libs" as libs;
bring "../schemas.w" as schemas;

struct ArticleFilter {
  userId: str?;
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

    let slugify = inflight (title: str) => {
      return libs.Helpers.slugify(title);
    };

    let updateTags = inflight (articleId: num, tagList: Array<str>?) => {
      db.execute(
        "DELETE FROM article_tag WHERE article_id = ?",
        articleId,
      );

      if let tagList = tagList {
        for tag in tagList {
          try {
            let result = db.execute(
              "INSERT INTO tags (name) VALUES (?) RETURNING *",
              tag,
            );

            db.execute(
              "INSERT INTO article_tag (article_id, tag_id) VALUES (?, ?)",
              articleId,
              result.lastInsertRowid!
            );
          } catch {
            db.execute(
              "INSERT INTO article_tag SELECT tags.id AS tag_id, ? AS article_id FROM tags WHERE name = ?",
              articleId,
              tag,
            );
          }
        }
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
          LEFT JOIN user_article_favorite ON (user_article_favorite.user_id = articles.id)
          LEFT JOIN users AS author ON (author.id = articles.author_id)
          LEFT JOIN user_follow ON (user_follow.user_id = :userId AND user_follow.follow_id = articles.author_id)
          JOIN article_tag ON (article_tag.article_id = articles.id)
          LEFT JOIN tags ON (tags.id = article_tag.tag_id)
      )
      SELECT * FROM article_list
      ";

      if filter? {
        sql += " WHERE ";
      }

      if filter?.tag? {
        sql += " WHERE EXISTS (SELECT 1 FROM json_each(tag_list) WHERE value = ':tag') ";
      }

      if filter?.slug? {
        sql += " slug = :slug ";
      }

      if filter?.author? {
        sql += " json_extract(author, '$.username') = :author ";
      }

      if filter?.favorited? {
        sql += " favorited = :favorited ";
      }

      let resultCount = db.execute2("SELECT COUNT(*) AS count FROM ({sql})", {
        userId: filter?.userId,
        slug: filter?.slug,
        favorited: filter?.favorited,
        tag: filter?.tag,
        author: filter?.author,
        limit: filter?.limit,
        offset: filter?.offset,
      });

      sql += " ORDER BY id DESC ";

      if filter?.limit? {
        sql += " LIMIT :limit";
      }

      if filter?.offset? {
        sql += " OFFSET :offset";
      }

      let result = db.execute2(sql, {
        userId: filter?.userId,
        slug: filter?.slug,
        favorited: filter?.favorited,
        tag: filter?.tag,
        author: filter?.author,
        limit: filter?.limit,
        offset: filter?.offset,
      });

      let articles = MutArray<schemas.Article>[];

      for row in result.rows {
        articles.push(
          schemas.Article {
            author: {
              bio: row.get("author").get("bio").asStr(),
              following: row.get("author").get("following").asNum() == 1,
              image: row.get("author").get("image").asStr(),
              username: row.get("author").get("username").asStr(),
            },
            body: row.get("body").asStr(),
            createdAt: row.get("created_at").asStr(),
            description: row.get("description").asStr(),
            favorited: row.get("favorited").asNum() == 1,
            favoritesCount: row.get("favorites_count").asNum(),
            slug: row.get("slug").asStr(),
            title: row.get("title").asStr(),
            updatedAt: row.get("updated_at").asStr(),
          }
        );
      }

      return schemas.MultipleArticlesResponse {
        articles: unsafeCast(articles),
        articlesCount: resultCount.rows.at(0).get("count").asNum(),
      };
    };

    // api.get("/api/articles", inflight (req) => {
    //   let var response = {};

    //   let var userId: str? = nil;

    //   try {
    //     let token = libs.Auth.verifyToken(req);

    //     userId = token.get("id").asStr();
    //   } catch {
    //   }

    //   try {
    //     response = getArticles(
    //       userId: userId,
    //       author: req.query.tryGet("author"),
    //       favorited: req.query.tryGet("favorited"),
    //       limit: libs.Helpers.parseInt(req.query.tryGet("limit") ?? "20"),
    //       offset: libs.Helpers.parseInt(req.query.tryGet("offset") ?? "0"),
    //       slug: req.query.tryGet("slug"),
    //       tag: req.query.tryGet("tag"),
    //     );
    //   } catch error {
    //     response = schemas.GenericErrorModel {
    //       errors: [{
    //         body: error,
    //       }],
    //     };
    //   }

    //   return {
    //     body: Json.stringify(response),
    //   };
    // });

    // api.get("/api/articles/:slug", inflight (req) => {
    //   let var response = {};

    //   try {
    //     let token = libs.Auth.verifyToken(req);

    //     let slug = req.vars.get("slug");

    //     if slug == "feed" {
    //       response = getArticles(
    //         userId: token.get("id").asStr(),
    //         author: req.query.tryGet("author"),
    //         favorited: req.query.tryGet("favorited"),
    //         limit: libs.Helpers.parseInt(req.query.tryGet("limit") ?? "20"),
    //         offset: libs.Helpers.parseInt(req.query.tryGet("offset") ?? "0"),
    //         slug: req.query.tryGet("slug"),
    //         tag: req.query.tryGet("tag"),
    //       );
    //     } else {
    //       let articles = getArticles(
    //         userId: token.get("id").asStr(),
    //         slug: slug,
    //       );

    //       if articles.articlesCount == 0 {
    //         throw "not found";
    //       }

    //       response = schemas.SingleArticleResponse {
    //         article: articles.articles.at(0),
    //       };
    //     }
    //   } catch error {
    //     response = schemas.GenericErrorModel {
    //       errors: [{
    //         body: error,
    //       }],
    //     };
    //   }

    //   return {
    //     body: Json.stringify(response),
    //   };
    // });

    // api.post("/api/articles", inflight (req) => {
    //   let var response = {};

    //   try {
    //     let token = libs.Auth.verifyToken(req);

    //     let body = schemas.NewArticleRequest.parseJson(req.body!);

    //     let result = db.execute2(
    //       "INSERT INTO articles (slug, title, description, body, author_id) VALUES (:slug, :title, :description, :body, :author_id) RETURNING *",
    //       {
    //         slug: slugify(body.article.title),
    //         title: body.article.title,
    //         description: body.article.description,
    //         body: body.article.body,
    //         author_id: token.get("id").asStr()
    //       }
    //     );

    //     let article = result.rows.at(0);

    //     updateTags(article.get("id").asNum(), body.article.tagList);
    //   } catch error {
    //     response = schemas.GenericErrorModel {
    //       errors: [{
    //         body: error,
    //       }],
    //     };
    //   }

    //   return {
    //     body: Json.stringify(response),
    //   };
    // });

    // api.put("/api/articles/:slug", inflight (req) => {
    //   let var response = {};

    //   try {
    //     let token = libs.Auth.verifyToken(req);

    //     let body = schemas.UpdateArticleRequest.parseJson(req.body!);


    //   } catch error {
    //     response = schemas.GenericErrorModel {
    //       errors: [{
    //         body: error,
    //       }],
    //     };
    //   }

    //   return {
    //     body: Json.stringify(response),
    //   };
    // });

    api.delete("/api/articles/:slug", inflight () => {
      
    });

    api.post("/api/articles/:slug/comments", inflight () => {
      
    });

    api.get("/api/articles/:slug/comments", inflight () => {
      
    });

    api.delete("/api/articles/:slug/comments/:id", inflight () => {
      
    });

    api.post("/api/articles/:slug/favorite", inflight (req) => {
    });

    api.delete("/api/articles/:slug/favorite", inflight (req) => {
      return libs.Auth.loginRequired(req, (token) => {
        db.batch(
          [
            {
              sql: "DELETE FROM user_article_favorite WHERE user_id = :userId AND article_id = (SELECT id FROM articles WHERE slug = :slug)",
              args: {
                userId: token.id,
                slug: req.vars.get("slug"),
              },
            },
            {
              sql: "UPDATE articles SET favorites_count = favorites_count - 1 WHERE slug = :slug",
              args: {
                slug: req.vars.get("slug"),
              }
            },
          ],
        );

        return {
        };
      });
    });
  }
}
