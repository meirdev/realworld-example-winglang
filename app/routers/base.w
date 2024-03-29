bring cloud;

bring "../libs" as libs;

pub class Base {
  new(api: cloud.Api, db: libs.Db) {
    nodeof(this).hidden = true;
  }
}
