import express from "express";
import { exportJWK, SignJWT, jwtVerify, importPKCS8, importSPKI } from "jose";
import { readFile } from "fs/promises";

const privatePEM = await readFile("./privatekey.pem", "ascii");
const privateKey = await importPKCS8(privatePEM, "RS256");

const publicPEM = await readFile("./publickey.pem", "ascii");
const publicKey = await importSPKI(publicPEM, "RS256");

const publicJwk = await exportJWK(publicKey);
const jwks = { keys: [publicJwk] };

const app = express();

app.get("/.well-known/jwks", async (req, res) => {
  res.json(jwks);
});

app.post("/login", express.json(), async (req, res) => {
  const jwt = await new SignJWT(req.body)
    .setProtectedHeader({ alg: "RS256" })
    .setIssuer("com.example.issuer")
    .setAudience("com.example.audience")
    .setIssuedAt()
    // .setExpirationTime("2h") // TODO: removing this to make it easier to mint tokens for the README
    .sign(privateKey);

  res.send(jwt);
});

app.post("/verify", express.json(), async (req, res) => {
  const { payload } = await jwtVerify(req.body.jwt, publicKey);
  res.json({ payload });
});

app.listen(4005, () => {
  console.log("jwks service running http://localhost:4005");
});

process.on("SIGTERM", () => {
  process.exit(0);
});
