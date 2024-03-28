bring cloud;

bring "./base.w" as base;
bring "../libs" as libs;
bring "../schemas.w" as schemas;

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

    let getArticles = inflight (userId: num, articleSlug: str?) => {
      let result = db.execute(
        "SELECT * FROM articles",
      );
    };

    api.get("/api/articles", inflight () => {

    });

    api.get("/api/articles/:slug", inflight () => {
      // slug == feed
    });

    api.post("/api/articles", inflight (req) => {
      let var response = {};

      try {
        let token = libs.Auth.verifyToken(req);

        let body = schemas.NewArticleRequest.parseJson(req.body!);

        let result = db.execute(
          "INSERT INTO articles (slug, title, description, body, author_id) VALUES (?, ?, ?, ?, ?) RETURNING *",
          slugify(body.article.title),
          body.article.title,
          body.article.description,
          body.article.body,
          token.get("id").asStr(),
        );

        let article = result.rows.at(0);

        updateTags(article.get("id").asNum(), body.article.tagList);
      } catch error {
        response = schemas.GenericErrorModel {
          errors: [{
            body: error,
          }],
        };
      }

      return {
        body: Json.stringify(response),
      };
    });

    api.put("/api/articles/:slug", inflight () => {
      
    });

    api.delete("/api/articles/:slug", inflight () => {
      
    });

    api.post("/api/articles/:slug/comments", inflight () => {
      
    });

    api.get("/api/articles/:slug/comments", inflight () => {
      
    });

    api.delete("/api/articles/:slug/comments/:id", inflight () => {
      
    });

    api.post("/api/articles/:slug/favorite", inflight () => {
      
    });

    api.delete("/api/articles/:slug/favorite", inflight () => {
      
    });
  }
}
