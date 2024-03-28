export default interface extern {
  emailValidator: (email: string) => Promise<boolean>,
  join: (s: (readonly (string)[]), separator: string) => Promise<string>,
  slugify: (text: string) => Promise<string>,
}
