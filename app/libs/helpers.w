pub class Helpers {
  pub static extern "./helpers.js" inflight emailValidator(email: str): bool;
  pub static extern "./helpers.js" inflight slugify(text: str): str;
  pub static extern "./helpers.js" inflight join(array: Array<str>, separator: str): str;
  pub static extern "./helpers.js" inflight parseInt(s: str): num;
}
