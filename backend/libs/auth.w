bring cloud;
bring util;

bring jwt;

pub struct Token {
  id: num;
  username: str;
}

pub class Auth {
  pub static inflight getSecret(): str {
    return util.tryEnv("REALWORLD_SECRET") ?? "123456";
  }

  pub static inflight hash(password: str): str {
    return util.sha256(Auth.getSecret() + password);
  }

  pub static inflight signToken(data: Token): str {
    return jwt.sign(data, Auth.getSecret());
  }

  pub static inflight verifyToken(req: cloud.ApiRequest): Token {
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

    return Token.fromJson(jwt.verify(token, secret: Auth.getSecret()));
  }
}
