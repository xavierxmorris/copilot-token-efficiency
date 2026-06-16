# token-demo-scratch

A tiny auth helper used as a fixture for the token-efficiency demo
(see [`../demo-flow.md`](../demo-flow.md)). Two functions — `signJwt` and
`verifyJwt` — plus a small test suite.

## Run the tests

```bash
npm test    # Node's built-in runner (node --test) — no dependencies, Node 18+
```

One test currently fails. Fixing it is the task the demo walks through.

> 🔒 **Presenters:** the answer key (what's planted and the one-line fix) lives in
> [`../presenter-notes.md`](../presenter-notes.md) — kept *outside* this folder on purpose so
> that copying `sample-repo/` for a live demo doesn't hand the model the solution. Don't copy
> `presenter-notes.md` into your scratch copy.

No dependencies, no `npm install`.
