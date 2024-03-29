bring cloud;

bring "./base.w" as base;
bring "../libs" as libs;
bring "../schemas.w" as schemas;

pub class Profiles extends base.Base {
  new(api: cloud.Api, db: libs.Db) {
    super(api, db);

    let profileToResponse = inflight (profile: schemas.ProfileDb) => {
      return schemas.ProfileResponse {
        profile: {
          username: profile.username,
          image: profile.image,
          bio: profile.bio,
          following: profile.following == 1,
        },
      };
    };

    let getProfile = inflight (currentUserId: num, username: str) => {
      if let result = db.fetchOne(
        "
        SELECT
          users.*,
          IIF(user_follow.follow_id IS NULL, false, true) AS following
        FROM users
        LEFT JOIN user_follow ON (user_follow.user_id = :currentUserId)
        WHERE username = :username",
        {
          currentUserId: currentUserId,
          username: username,
        },
      ) {
        return schemas.ProfileDb.fromJson(result);
      }

      throw "404: not found";
    };

    api.get("/api/profiles/:username", inflight (req) => {
      return libs.Auth.loginRequired(req, (token) => {
        let profile = getProfile(token.id, req.vars.get("username"));

        return {
          body: Json.stringify(profileToResponse(profile)),
        };
      });
    });

    api.post("/api/profiles/:username/follow", inflight (req) => {
      return libs.Auth.loginRequired(req, (token) => {
        db.execute(
          "
          INSERT INTO user_follow (user_id, follow_id)
          VALUES (:userId, (SELECT id FROM users WHERE username = :username))",
          {
            userId: token.id,
            username: req.vars.get("username"),
          },
        );

        let profile = getProfile(token.id, req.vars.get("username"));

        return {
          body: Json.stringify(profileToResponse(profile)),
        };
      });
    });

    api.delete("/api/profiles/:username/follow", inflight (req) => {
      return libs.Auth.loginRequired(req, (token) => {
        db.execute(
          "
          DELETE FROM user_follow
          WHERE user_id = :userId AND follow_id = (SELECT id FROM users WHERE username = :username)",
          {
            userId: token.id,
            followId: req.vars.get("username"),
          },
        );

        let profile = getProfile(token.id, req.vars.get("username"));

        return {
          body: Json.stringify(profileToResponse(profile)),
        };
      });
    });
  }
}
