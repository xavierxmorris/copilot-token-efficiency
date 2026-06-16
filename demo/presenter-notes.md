# Presenter notes — answer key (do NOT copy into the scratch demo)

This file is the cheat sheet for the demo in [`demo-flow.md`](demo-flow.md). It lives **outside**
[`sample-repo/`](sample-repo/) on purpose: the live scratch copy must not contain the solution,
or a strong model will read it and fix the bug instantly — undercutting the "wrong turn" beat.

## What's planted

| Planted | Where | Why |
|---|---|---|
| **A real bug** | `sample-repo/src/auth/jwt.js` → `token.split(".", 1)` drops the signature segment | Gives the `task` subagent a genuine failure to catch and a one-line fix for the *Disciplined* run. |
| **A naming trap** | The helper is `verifyJwt`; there is **no** `validateToken` | A vague prompt ("fix the token validation") tends to hallucinate `validateToken` — that's the *wrong turn* whose cost the demo shows. |

## The one-line fix (keep in your back pocket for Run B)

In `src/auth/jwt.js`, change:

```js
const [body, sig] = token.split(".", 1);   // bug: limit of 1 drops the signature
```

to:

```js
const [body, sig] = token.split(".");      // fix
```

## Expected test results

- **Before the fix (shipped state):** `tests 5 / pass 4 / fail 1` — only `round-trips a signed token` fails.
- **After the fix:** `tests 5 / pass 5 / fail 0`.

The four already-passing tests (`signJwt returns a string`, `signJwt output has a separator`,
`verifyJwt rejects a tampered token`, `verifyJwt rejects an empty token`) exist to give the test
run enough output that the `task`-subagent-vs-inline history contrast is visible.

## Why the contrast holds

Because the scratch copy carries **no** solution comments or README hints, the *Naive* vague
prompt (`"The auth tests are failing. Fix the token validation."`) has room to wander toward the
non-existent `validateToken`. The *Disciplined* run removes that room by naming the real helper,
the failing line, and the acceptance criteria.
