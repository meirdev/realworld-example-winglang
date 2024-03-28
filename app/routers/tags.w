bring cloud;

bring "./base.w" as base;
bring "../libs" as libs;
bring "../schemas.w" as schemas;

pub class Tags extends base.Base {
  new(api: cloud.Api, db: libs.Db) {
    super(api, db);

    api.get("/api/tags", inflight () => {
      let var response = {};

      try {
        let result = db.execute("SELECT * FROM tags");

        let tags = MutArray<str>[];

        for item in result.rows {
          tags.push(item.get("name").asStr());
        }

        response = schemas.TagsResponse {
          tags: unsafeCast(tags),
        };
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
  }
}
