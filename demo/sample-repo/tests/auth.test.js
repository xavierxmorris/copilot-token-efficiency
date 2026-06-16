// tests/auth.test.js
const assert = require("node:assert");
const { test } = require("node:test");
const { signJwt, verifyJwt } = require("../src/auth/jwt");

test("round-trips a signed token", () => {
  const token = signJwt({ sub: "u_123" });
  const claims = verifyJwt(token);
  assert.strictEqual(claims?.sub, "u_123"); // fails until the split bug is fixed
});
