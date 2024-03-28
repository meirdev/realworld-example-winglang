bring cloud;

bring "./base.w" as base;
bring "../libs" as libs;
bring "../schemas.w" as schemas;

pub class Users extends base.Base {
  new(api: cloud.Api, db: libs.Db) {
    super(api, db);

    let checkUsername = inflight (username: str, exclude: str?) => {
      if username.length < 3 {
        throw "username must be at least 3 characters";
      }

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

    let checkPassword = inflight (password: str) => {
      if password.length < 8 {
        throw "password must be at least 8 characters";
      }
    };

    api.post("/api/users/login", inflight (req) => {
      let var response = {};

      try {
        let body = schemas.LoginUserRequest.parseJson(req.body!);

        let result = db.execute(
          "SELECT * FROM users WHERE email = ? AND password = ?",
          body.user.email,
          libs.Auth.hash(body.user.password),
        );

        if result.rows.length == 0 {
          throw "incorrect email or password";
        }

        let user = result.rows.at(0);

        let token = libs.Auth.signToken({
          id: user.get("id").asNum(),
          username: user.get("username").asStr(),
        });

        response = schemas.UserResponse {
          user: {
            username: user.get("username").asStr(),
            email: user.get("email").asStr(),
            bio: user.get("bio").asStr(),
            image: user.get("image").asStr(),
            token: token,
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

    api.post("/api/users", inflight (req) => {
      let var response = {};

      try {
        let body = schemas.NewUserRequest.parseJson(req.body!);

        checkPassword(body.user.password);
        checkUsername(body.user.username);
        checkEmail(body.user.email);

        let result = db.execute(
          "INSERT INTO users (username, email, password, bio, image) VALUES (?, ?, ?, '', '') RETURNING *",
          body.user.username,
          body.user.email,
          libs.Auth.hash(body.user.password),
        );

        let user = result.rows.at(0);

        let token = libs.Auth.signToken({
          id: user.get("id").asNum(),
          username: user.get("username").asStr(),
        });

        response = schemas.UserResponse {
          user: {
            username: user.get("username").asStr(),
            email: user.get("email").asStr(),
            bio: "",
            image: "",
            token: token,
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

    api.get("/api/user", inflight (req) => {
      let var response = {};

      try {
        let token = libs.Auth.verifyToken(req);

        let result = db.execute(
          "SELECT * FROM users WHERE id = ?",
          token.get("id").asStr(),
        );

        let user = result.rows.at(0);

        response = schemas.UserResponse {
          user: {
            username: user.get("username").asStr(),
            email: user.get("email").asStr(),
            bio: "",
            image: "",
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

        let var result = db.execute(
          "SELECT * FROM users WHERE id = ?",
          token.get("id").asStr(),
        );

        let var user = result.rows.at(0);

        let args = MutMap<str>{};

        if let password = body.user.password {
          checkPassword(password);
          args.set("password", password);
        }

        if let username = body.user.username {
          checkUsername(username, user.get("username").asStr());
          args.set("username", username);
        }

        if let email = body.user.email {
          checkEmail(email, user.get("email").asStr());
          args.set("email", email);
        }

        if let bio = body.user.bio {
          args.set("bio", bio);
        }

        if let image = body.user.image {
          args.set("image", image);
        }

        result = db.execute(
          "UPDATE users SET password = ?, username = ?, email = ?, bio = ?, image = ? WHERE id = ? RETURNING *",
          args.tryGet("password") ?? user.get("password").asStr(),
          args.tryGet("username") ?? user.get("username").asStr(),
          args.tryGet("email") ?? user.get("email").asStr(),
          args.tryGet("bio") ?? user.get("bio").asStr(),
          args.tryGet("image") ?? user.get("image").asStr(),
          user.get("id").asNum(),
        );

        user = result.rows.at(0);

        token = libs.Auth.signToken({
          id: user.get("id").asNum(),
          username: user.get("username").asStr(),
        });

        response = schemas.UserResponse {
          user: {
            username: user.get("username").asStr(),
            email: user.get("email").asStr(),
            bio: user.get("bio").asStr(),
            image: user.get("image").asStr(),
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
