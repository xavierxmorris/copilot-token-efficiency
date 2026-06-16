// src/auth/jwt.js
// DEMO FIXTURE — contains one PLANTED bug. See demo/sample-repo/README.md.
const SECRET = process.env.JWT_SECRET || "dev-secret";

function signJwt(payload) {
  const body = Buffer.from(JSON.stringify(payload)).toString("base64url");
  return `${body}.${SECRET}`;
}

// The real helper is verifyJwt — there is NO validateToken (planted naming trap).
// PLANTED BUG: split limit of 1 drops the signature segment, so verification always fails.
// Correct fix: token.split(".")  (remove the `, 1`).
function verifyJwt(token) {
  const [body, sig] = token.split(".", 1); // <-- planted bug
  if (sig !== SECRET) return null;
  return JSON.parse(Buffer.from(body, "base64url").toString());
}

module.exports = { signJwt, verifyJwt };
