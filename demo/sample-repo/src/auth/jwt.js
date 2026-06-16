// src/auth/jwt.js
// Minimal demo auth helper: sign a payload, verify it round-trips.
const SECRET = "dev-secret";

function signJwt(payload) {
  const body = Buffer.from(JSON.stringify(payload)).toString("base64url");
  return `${body}.${SECRET}`;
}

function verifyJwt(token) {
  const [body, sig] = token.split(".", 1);
  if (sig !== SECRET) return null;
  return JSON.parse(Buffer.from(body, "base64url").toString());
}

module.exports = { signJwt, verifyJwt };
