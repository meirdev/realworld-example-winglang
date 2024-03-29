bring cloud;

bring "./base.w" as base;
bring "../libs" as libs;
bring "../schemas.w" as schemas;

pub class Tags extends base.Base {
  new(api: cloud.Api, db: libs.Db) {
    super(api, db);

    api.get("/api/tags", inflight () => {
      let tags = MutArray<str>[];

      for row in db.fetchAll("SELECT * FROM tags") {
        tags.push(schemas.TagDb.fromJson(row).name);
      }

      return {
        body: Json.stringify(schemas.TagsResponse {
          tags: unsafeCast(tags),
        }),
      };
    });
  }
}
