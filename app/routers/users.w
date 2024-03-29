bring cloud;

bring "./base.w" as base;
bring "../libs" as libs;
bring "../schemas.w" as schemas;

pub class Users extends base.Base {
  new(api: cloud.Api, db: libs.Db) {
    super(api, db);

    let checkUsername = inflight (username: str, exclude: str?) => {
      if db.fetchOne(
        "SELECT * FROM users WHERE username = :username AND username != :exclude",
        {
          username: username,
          exclude: exclude ?? "",
        }
      )? {
        throw "username is already taken";
      }
    };

    let checkEmail = inflight (email: str, exclude: str?) => {
      if !libs.Helpers.emailValidator(email) {
        throw "invalid email address";
      }

      if db.fetchOne(
        "SELECT * FROM users WHERE email = :email AND email != :exclude",
        {
          email: email,
          exclude: exclude ?? "",
        }
      )? {
        throw "email already in use";
      }
    };

    let userToResponse = inflight (user: schemas.UserDb) => {
      return schemas.UserResponse {
        user: {
          username: user.username,
          email: user.email,
          bio: user.bio,
          image: user.image,
          token: libs.Auth.signToken({
            id: user.id,
            username: user.username,
          }),
        },
      };
    };

    let getUser = inflight (id: num) => {
      if let result = db.fetchOne(
        "SELECT * FROM users WHERE id = :id",
        {
          id: id,
        },
      ) {
        return schemas.UserDb.fromJson(result);
      }

      throw "404: not found";
    };

    api.post("/api/users/login", inflight (req) => {
      let body = schemas.LoginUserRequest.parseJson(req.body!);

      if let result = db.fetchOne(
        "SELECT * FROM users WHERE email = :email AND password = :password", {
          email: body.user.email,
          password: libs.Auth.hash(body.user.password),
        },
      ) {
        let user = schemas.UserDb.fromJson(result);

        return {
          body: Json.stringify(userToResponse(user)),
        };
      }

      throw "401: unauthorized";
    });

    api.post("/api/users", inflight (req) => {
      let body = schemas.NewUserRequest.parseJson(req.body!);

      checkUsername(body.user.username);
      checkEmail(body.user.email);

      if let result = db.fetchOne(
        "INSERT INTO users (username, email, password, bio, image) VALUES (:username, :email, :password, '', '') RETURNING *",
        {
          username: body.user.username,
          email: body.user.email,
          password: libs.Auth.hash(body.user.password),
        },
      ) {
        let user = schemas.UserDb.fromJson(result);

        return {
          body: Json.stringify(userToResponse(user)),
        };
      }
    });

    api.get("/api/user", inflight (req) => {
      return libs.Auth.loginRequired(req, (token) => {
        let user = getUser(token.id);

        return {
          body: Json.stringify(userToResponse(user)),
        };
      });
    });

    api.put("/api/user", inflight (req) => {
      return libs.Auth.loginRequired(req, (token) => {
        let body = schemas.UpdateUserRequest.parseJson(req.body!);

        let user = getUser(token.id);

        if let username = body.user.username {
          checkUsername(username, user.username);
        }

        if let email = body.user.email {
          checkEmail(email, user.email);
        }

        if let result = db.fetchOne(
          "UPDATE users SET password = :password, username = :username, email = :email, bio = :bio, image = :image WHERE id = :id RETURNING *",
          {
            password: body.user.password ?? user.password,
            username: body.user.username ?? user.username,
            email: body.user.email ?? user.email,
            bio: body.user.bio ?? user.bio,
            image: body.user.image ?? user.image,
            id: user.id,
          },
        ) {
          let user = schemas.UserDb.fromJson(result);

          return {
            body: Json.stringify(userToResponse(user)),
          };
        }
      });
    });
  }
}
