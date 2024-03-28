export default interface extern {
  createClient: (config: Config) => Promise<Client$Inflight>,
}
export interface Config {
  readonly authToken?: (string) | undefined;
  readonly url: string;
}
export interface Statement {
  readonly args?: ((readonly (string)[])) | undefined;
  readonly sql: string;
}
export interface ResultSet {
  readonly columnTypes: (readonly (string)[]);
  readonly columns: (readonly (string)[]);
  readonly lastInsertRowid?: (number) | undefined;
  readonly rows: (readonly (Readonly<any>)[]);
  readonly rowsAffected: number;
}
export interface Client$Inflight {
  readonly execute: (stmt: Statement) => Promise<ResultSet>;
}