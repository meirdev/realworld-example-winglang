bring cloud;

bring "./base.w" as base;
bring "../libs" as libs;
bring "../schemas.w" as schemas;

pub class Users extends base.Base {
  new(api: cloud.Api, db: libs.Db) {
    super(api, db);

    let checkUsername = inflight (username: str, exclude: str?) => {
      let result = db.execute(
        "SELECT * FROM users WHERE username = ? AND username != ?",
        username,
        exclude ?? "",
      );

      if result.rows.length != 0 {
        throw "username is already taken";
      }
    };

    let checkEmail = inflight (email: str, exclude: str?) => {
      if !libs.Helpers.emailValidator(email) {
        throw "invalid email address";
      }

      let result = db.execute(
        "SELECT * FROM users WHERE email = ? AND email != ?",
        email,
        exclude ?? "",
      );

      if result.rows.length != 0 {
        throw "email already in use";
      }
    };

    api.post("/api/users/login", inflight (req) => {
      let var body: schemas.LoginUserRequest? = nil;

      try {
        body = schemas.LoginUserRequest.parseJson(req.body!);
      } catch error {
        return {
          status: 422,
          body: error,
        };
      }

      let result = db.execute2(
        "SELECT * FROM users WHERE email = :email AND password = :password",
        {
          email: body!.user.email,
          password: libs.Auth.hash(body!.user.password),
        }
      );

      if result.rows.length == 0 {
        return {
          status: 401,
          body: "incorrect email or password",
        };
      }

      let user = schemas.UserDb.fromJson(result.rows.at(0));

      return {
        body: Json.stringify(schemas.UserResponse {
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
        }),
      };
    });

    api.post("/api/users", inflight (req) => {
      let var body: schemas.NewUserRequest? = nil;

      try {
        body = schemas.NewUserRequest.parseJson(req.body!);

        checkUsername(body!.user.username);
        checkEmail(body!.user.email);
      } catch error {
        return {
          status: 422,
          body: error,
        };
      }

      let result = db.execute2(
        "INSERT INTO users (username, email, password, bio, image) VALUES (:username, :email, :password, '', '') RETURNING *",
        {
          username: body!.user.username,
          email: body!.user.email,
          password: libs.Auth.hash(body!.user.password),
        },
      );

      let user = schemas.UserDb.fromJson(result.rows.at(0));

      return {
        body: Json.stringify(schemas.UserResponse {
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
        }),
      };
    });

    api.get("/api/user", inflight (req) => {
      let var response = {};

      try {
        let token = libs.Auth.verifyToken(req);

        let result = db.execute2(
          "SELECT * FROM users WHERE id = :id",
          {
            id: token.id,
          },
        );

        let user = schemas.UserDb.fromJson(result.rows.at(0));

        response = schemas.UserResponse {
          user: {
            username: user.username,
            email: user.email,
            bio: user.bio,
            image: user.image,
            token: libs.Auth.signToken(token),
          }
        };
      } catch error {
        response = schemas.GenericErrorModel {
          errors: [{
            body: error,
          }],
        };
      }

      return {
        body: Json.stringify(response),
      };
    });

    api.put("/api/user", inflight (req) => {
      let var response = {};

      try {
        let var token = libs.Auth.verifyToken(req);

        let body = schemas.UpdateUserRequest.parseJson(req.body!);

        let var result = db.execute2(
          "SELECT * FROM users WHERE id = :id",
          {
            id: token.id,
          },
        );

        let var user = schemas.UserDb.fromJson(result.rows.at(0));

        let args = MutMap<str>{};

        if let password = body.user.password {
          args.set("password", password);
        }

        if let username = body.user.username {
          checkUsername(username, user.username);
          args.set("username", username);
        }

        if let email = body.user.email {
          checkEmail(email, user.email);
          args.set("email", email);
        }

        if let bio = body.user.bio {
          args.set("bio", bio);
        }

        if let image = body.user.image {
          args.set("image", image);
        }

        result = db.execute2(
          "UPDATE users SET password = :password, username = :username, email = :email, bio = :bio, image = :image WHERE id = :id RETURNING *",
          {
            password: args.tryGet("password") ?? user.password,
            username: args.tryGet("username") ?? user.username,
            email: args.tryGet("email") ?? user.email,
            bio: args.tryGet("bio") ?? user.bio,
            image: args.tryGet("image") ?? user.image,
            id: user.id,
          },
        );

        user = schemas.UserDb.fromJson(result.rows.at(0));

        token = {
          id: user.id,
          username: user.username,
        };

        response = schemas.UserResponse {
          user: {
            username: user.username,
            email: user.email,
            bio: user.bio,
            image: user.image,
            token: libs.Auth.signToken(token),
          }
        };
      } catch error {
        response = schemas.GenericErrorModel {
          errors: [{
            body: error,
          }],
        };
      }

      return {
        body: Json.stringify(response),
      };
    });
  }
}
