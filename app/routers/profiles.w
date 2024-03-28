bring cloud;

bring "./base.w" as base;
bring "../libs" as libs;
bring "../schemas.w" as schemas;

pub class Profiles extends base.Base {
  new(api: cloud.Api, db: libs.Db) {
    super(api, db);

    let getUserByUsername = inflight (currentUserId: str, username: str) => {
      let result = db.execute(
        "SELECT users.*, IIF(user_follow.follow_id IS NULL, false, true) AS following FROM users LEFT JOIN user_follow ON (user_follow.user_id = ?) WHERE username = ?",
        currentUserId,
        username,
      );

      if result.rows.length == 0 {
        throw "user not found";
      }

      return result.rows.at(0);
    };

    api.get("/api/profiles/:username", inflight (req) => {
      let var response = {};

      try {
        let token = libs.Auth.verifyToken(req);

        let var user = getUserByUsername(token.get("id").asStr(), req.vars.get("username"));

        response = schemas.ProfileResponse {
          profile: {
            username: user.get("username").asStr(),
            image: user.get("image").asStr(),
            bio: user.get("bio").asStr(),
            following: user.get("following").asNum() == 1,
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

    api.post("/api/profiles/:username/follow", inflight (req) => {
      let var response = {};

      try {
        let token = libs.Auth.verifyToken(req);

        let var user = getUserByUsername(token.get("id").asStr(), req.vars.get("username"));

        if user.get("following").asNum() == 0 {
          db.execute(
            "INSERT INTO user_follow (user_id, follow_id) VALUES (?, ?)",
            token.get("id").asStr(),
            user.get("id").asNum(),
          );
        }

        user = getUserByUsername(token.get("id").asStr(), req.vars.get("username"));

        response = schemas.ProfileResponse {
          profile: {
            username: user.get("username").asStr(),
            image: user.get("image").asStr(),
            bio: user.get("bio").asStr(),
            following: user.get("following").asNum() == 1,
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

    api.delete("/api/profiles/:username/follow", inflight (req) => {
      let var response = {};

      try {
        let token = libs.Auth.verifyToken(req);

        let var user = getUserByUsername(token.get("id").asStr(), req.vars.get("username"));

        if user.get("following").asNum() == 1 {
          db.execute(
            "DELETE FROM user_follow WHERE user_id = ? AND follow_id = ?",
            token.get("id").asStr(),
            user.get("id").asNum(),
          );
        }

        user = getUserByUsername(token.get("id").asStr(), req.vars.get("username"));

        response = schemas.ProfileResponse {
          profile: {
            username: user.get("username").asStr(),
            image: user.get("image").asStr(),
            bio: user.get("bio").asStr(),
            following: user.get("following").asNum() == 1,
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
