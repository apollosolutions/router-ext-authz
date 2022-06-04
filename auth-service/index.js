import express from "express";
import { jwtVerify, createRemoteJWKSet } from "jose";
import { URL } from "url";

const jwks = createRemoteJWKSet(new URL(process.env.JWKS_ENDPOINT));

const app = express();

app.all("/", async (req, res) => {
  if (req.method === "OPTIONS") {
    res.json({ ok: true });
    return;
  }

  if (
    req.method === "GET" &&
    req.header("content-type") !== "application/json"
  ) {
    res.json({ ok: true });
    return;
  }

  const authorization = req.headers.authorization;
  if (!authorization?.startsWith("Bearer ")) {
    res.status(401);
    return;
  }

  const token = req.headers.authorization.split("Bearer ")[1];

  try {
    const { payload } = await jwtVerify(token, jwks, {
      issuer: "com.example.issuer",
      audience: "com.example.audience",
    });

    res.setHeader("x-user-id", payload.sub);
    res.setHeader("x-user-name", payload.name);

    res.json({ ok: true });
  } catch (e) {
    console.log(e);
    res.status(403);
  }
});

app.listen(4000, () => {
  console.log("auth server running on 4000");
});
