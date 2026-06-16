// tests/auth.test.js
const assert = require("node:assert");
const { test } = require("node:test");
const { signJwt, verifyJwt } = require("../src/auth/jwt");

test("signJwt returns a string", () => {
  assert.strictEqual(typeof signJwt({ sub: "u_123" }), "string");
});

test("signJwt output has a separator", () => {
  assert.ok(signJwt({ sub: "u_123" }).includes("."));
});

test("verifyJwt rejects a tampered token", () => {
  assert.strictEqual(verifyJwt("garbage.token"), null);
});

test("verifyJwt rejects an empty token", () => {
  assert.strictEqual(verifyJwt(""), null);
});

test("round-trips a signed token", () => {
  const token = signJwt({ sub: "u_123" });
  const claims = verifyJwt(token);
  assert.strictEqual(claims?.sub, "u_123");
});
