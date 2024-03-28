bring cloud;
bring util;

bring jwt;

pub class Auth {
  pub static inflight getSecret(): str {
    return util.tryEnv("SECRET") ?? "123456";
  }

  pub static inflight hash(password: str): str {
    return util.sha256(Auth.getSecret() + password);
  }

  pub static inflight signToken(data: Json): str {
    return jwt.sign(data, Auth.getSecret());
  }

  pub static inflight verifyToken(req: cloud.ApiRequest): Json {
    let var authorization = "";

    if req.headers?.has("Authorization") == true {
      authorization = req.headers?.get("Authorization")!;
    } elif req.headers?.has("authorization") == true {
      authorization = req.headers?.get("authorization")!;
    } else {
      throw "missing authorization";
    }

    if !authorization.startsWith("Token ") {
      throw "invalid authorization";
    }

    let token = authorization.substring("Token ".length);

    return jwt.verify(token, secret: Auth.getSecret());
  }
}
