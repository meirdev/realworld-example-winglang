pub struct Config {
  url: str;
  authToken: str?;
}

pub struct Statement {
  sql: str;
  args: Json?;
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
  inflight batch(stmt: Array<Statement>): Array<ResultSet>;
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

  pub inflight execute(sql: str, args: Json?): ResultSet {
    return this.client.execute({
      sql: sql,
      args: args ?? {},
    });
  }

  pub inflight batch(stmts: Array<Statement>): Array<ResultSet> {
    return this.client.batch(stmts);
  }

  pub inflight fetchOne(sql: str, args: Json?): Json? {
    return this.execute(sql, args).rows.tryAt(0);
  }

  pub inflight fetchAll(sql: str, args: Json?): Array<Json> {
    return this.execute(sql, args).rows;
  }
}
