pub struct User {
  email: str;
  token: str;
  username: str;
  bio: str;
  image: str;
}

pub struct LoginUser {
  email: str;
  password: str;
}

pub struct LoginUserRequest {
  user: LoginUser;
}

pub struct NewUser {
  username: str;
  email: str;
  password: str;
}

pub struct NewUserRequest {
  user: NewUser;
}

pub struct UpdateUser {
  email: str?;
  username: str?;
  password: str?;
  bio: str?;
  image: str?;
}

pub struct UpdateUserRequest {
  user: UpdateUser;
}

pub struct UserResponse {
  user: User;
}

pub struct Profile {
  username: str;
  bio: str;
  image: str;
  following: bool;
}

pub struct ProfileResponse {
  profile: Profile;
}

pub struct NewArticle {
  title: str;
  description: str;
  body: str;
  tagList: Array<str>?;
}

pub struct NewArticleRequest {
  article: NewArticle;
}

pub struct UpdateArticle {
  title: str?;
  description: str?;
  body: str?;
}

pub struct UpdateArticleRequest {
  article: UpdateArticle;
}

pub struct Article {
  slug: str;
  tilte: str;
  description: str;
  body: str;
  tagList: Array<str>?;
  createdAt: str;
  updatedAt: str;
  favorited: bool;
  favoritesCount: num;
  author: Profile;
}

pub struct SingleArticleResponse {
  article: Article;
}

pub struct MultipleArticlesResponse {
  articles: Array<Article>;
  articlesCount: num;
}

pub struct NewComment {
  body: str;
}

pub struct NewCommentRequest {
  comment: NewComment;
}

pub struct Comment {
  id: num;
  createdAt: str;
  updatedAt: str;
  body: str;
  author: Profile;
}

pub struct SingleCommentResponse {
  comment: Comment;
}

pub struct MultipleCommentsResponse {
  comment: Array<Comment>;
}

pub struct TagsResponse {
  tags: Array<str>;
}

pub struct Error {
  body: str;
}

pub struct GenericErrorModel {
  errors: Array<Error>;
}
