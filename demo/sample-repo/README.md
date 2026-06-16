# Sample repo — demo fixture

A deliberately tiny, throwaway project used by [`../demo-flow.md`](../demo-flow.md). The task
the demo runs is **"fix the failing auth test."**

## What's planted (and why)

| Planted | Where | Why it's here |
|---|---|---|
| **A real bug** | `src/auth/jwt.js` → `token.split(".", 1)` drops the signature segment | Gives the `task` subagent a genuine failure to catch, and a one‑line fix for the *Disciplined* run. |
| **A naming trap** | The helper is `verifyJwt`; there is **no** `validateToken` | A vague prompt ("fix the token validation") tends to hallucinate `validateToken` — that's the *wrong turn* whose cost the demo shows. |

## Run it

```bash
# from this folder (demo/sample-repo)
npm test        # 1 failing — this is expected before the demo's fix
```

**The correct fix** (keep it in your back pocket for Run B): change
`token.split(".", 1)` → `token.split(".")` in `src/auth/jwt.js`. After that, `npm test` is green.

## Tip for live demos

Copy this folder somewhere outside the repo before presenting, so the edits you make on stage
don't dirty `copilot-token-efficiency`:

```powershell
Copy-Item -Recurse demo/sample-repo "$env:TEMP/token-demo-scratch"
cd "$env:TEMP/token-demo-scratch"
```

No dependencies, no `npm install` — it uses Node's built‑in `node --test` (Node 18+).
