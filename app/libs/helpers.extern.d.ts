export default interface extern {
  emailValidator: (email: string) => Promise<boolean>,
  join: (array: (readonly (string)[]), separator: string) => Promise<string>,
  parseInt: (s: string) => Promise<number>,
  slugify: (text: string) => Promise<string>,
}
