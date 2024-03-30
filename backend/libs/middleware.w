bring cloud;

bring "./auth.w" as auth;
bring "../schemas.w" as schemas;

pub class Middleware {
  pub static inflight loginRequired(required: bool, req: cloud.ApiRequest, fn: inflight (auth.Token?): Json): cloud.ApiResponse {
    try {
      let var token: auth.Token? = nil;

      try {
        token = auth.Auth.verifyToken(req);
      } catch error {
        if required {
          throw error;
        }
      }

      return {
        body: Json.stringify(fn(token)),
      };
    } catch error {
      return {
        status: 400,
        body: Json.stringify(schemas.GenericErrorModel {
          errors: [
            {
              body: error,
            },
          ],
        }),
      };
    }
  }
}
