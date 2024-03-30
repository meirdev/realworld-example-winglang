export default interface extern {
  emailValidator: (email: string) => Promise<boolean>,
  parseInt: (s: string) => Promise<number>,
  slugify: (text: string) => Promise<string>,
  sorted: (a: (readonly (string)[])) => Promise<(readonly (string)[])>,
}
