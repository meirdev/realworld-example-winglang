pub struct Config {
  url: str;
  authToken: str?;
}

pub struct Statement {
  sql: str;
  args: Array<str>?;
}

pub struct ResultSet {
  columns: Array<str>;
  columnTypes: Array<str>;
  rows: Array<Json>;
  rowsAffected: num;
  lastInsertRowid: num?;
}

pub interface Client {
  inflight execute(stmt: Statement): ResultSet;
}

pub class Db {
  config: Config;

  inflight client: Client;

  pub static extern "./db.js" inflight createClient(config: Config): Client;

  new(config: Config) {
    this.config = config;
  }

  inflight new() {
    this.client = Db.createClient(this.config);
  }

  pub inflight execute(sql: str, ...args: Array<Json>): ResultSet {
    return this.client.execute({
      sql: sql,
      args: unsafeCast(args),
    });
  }

  pub inflight execute2(sql: str, args: Json?): ResultSet {
    return this.client.execute({
      sql: sql,
      args: unsafeCast(args),
    });
  }
}
