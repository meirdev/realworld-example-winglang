bring cloud;
bring fs;
bring http;

bring "./libs" as libs;
bring "./routers" as routers;

let database = new libs.Db(
  url: "file:../database.db"
);

new cloud.OnDeploy(inflight () => {
  for createTable in fs.readFile("./init.sql").split("\n\n") {
    database.execute(createTable);
  }
});

let api = new cloud.Api(cors: true);

new routers.Articles(api, database);
new routers.Profiles(api, database);
new routers.Tags(api, database);
new routers.Users(api, database);

test "demo" {
  let response = http.get("{api.url}/api/articles");

  assert(response.status == 200);
}
