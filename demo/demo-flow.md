# Demo flow — *showing* the token save (VS Code + Copilot CLI)

A presenter-ready script for demonstrating the techniques in
[`../docs/token-efficiency-guide.md`](../docs/token-efficiency-guide.md) **live**, on screen,
on both surfaces — so the audience *sees* the tokens move instead of taking it on faith.

> Validated against GitHub Copilot CLI **v1.0.63** and VS Code Copilot Chat (mid‑2026).
> Sources are listed at the bottom with their checked dates. Surfaces change fast — if a
> menu label has moved, the *number* you're pointing at hasn't.

**The whole demo in one sentence:** run the *same* task twice — once naive, once disciplined —
and let the on‑screen token counters tell the story.

- ⏱️ Runs in **~17 minutes** (see [timing](#timing--talk-track)).
- 🎯 Works the same in VS Code and the CLI; do each beat in one surface, then the other.
- 🧰 Self‑contained — the [sample assets](#1-sample-task--planted-assets) paste straight in.

---

## Contents

1. [Sample task + planted assets](#1-sample-task--planted-assets)
2. [One‑time setup (both surfaces)](#2-one-time-setup-both-surfaces)
3. [Where the numbers live — the two scoreboards](#3-where-the-numbers-live--the-two-scoreboards)
4. [Scripted Run A — *Naive*](#4-scripted-run-a--naive)
5. [Scripted Run B — *Disciplined*](#5-scripted-run-b--disciplined)
6. [The reveal — side by side](#6-the-reveal--side-by-side)
7. [Screenshot checklist (per surface)](#7-screenshot-checklist-per-surface)
8. [Timing & talk track](#timing--talk-track)
9. [Troubleshooting](#8-troubleshooting)
10. [Sources](#sources)

---

## 1. Sample task + planted assets

Use a tiny, throwaway repo so the diff is legible from the back row. The task is deliberately
realistic: **"fix the failing auth test."** It contains one planted bug and one planted
ambiguity so the *Naive* run takes a believable wrong turn.

> ✅ **It's already scaffolded** under [`sample-repo/`](sample-repo/) — four files, no
> dependencies, runs on Node's built‑in `node --test` (Node 18+). The **answer key** is in
> [`presenter-notes.md`](presenter-notes.md), kept *outside* the fixture on purpose (see the
> [wrong‑turn note](#why-the-fixture-stays-spoiler-free) below). Copy the fixture **out** of
> this repo first so on‑stage edits don't dirty it — run from the repo root:
>
> ```powershell
> # from the repo root (…\copilot-token-efficiency)
> $scratch = Join-Path $env:TEMP "token-demo-scratch"
> Remove-Item -Recurse -Force $scratch -ErrorAction SilentlyContinue   # always start clean
> Copy-Item -Recurse demo\sample-repo $scratch
> Set-Location $scratch; npm test    # tests 5 / pass 4 / fail 1 — as designed
> ```
>
> ⚠️ Run `switch-profile.ps1` and anything under `scripts\` **from the repo**, not from
> `$scratch` (the fixture has no `scripts/`).

The fixture files (shown here for reference — they live, spoiler‑free, in
[`sample-repo/`](sample-repo/); the planted bug and fix are in
[`presenter-notes.md`](presenter-notes.md)):

**`src/auth/jwt.js`** — the helper is `verifyJwt`; there is deliberately no `validateToken`:

```js
// src/auth/jwt.js
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
```

**`tests/auth.test.js`** — five tests; only the round‑trip fails until the bug is fixed (the
extra passing tests give the run enough output that the subagent‑vs‑inline contrast is visible):

```js
// tests/auth.test.js  (abridged — see sample-repo/ for the full file)
test("signJwt returns a string", () => { /* passes */ });
test("signJwt output has a separator", () => { /* passes */ });
test("verifyJwt rejects a tampered token", () => { /* passes */ });
test("verifyJwt rejects an empty token", () => { /* passes */ });
test("round-trips a signed token", () => {
  const token = signJwt({ sub: "u_123" });
  const claims = verifyJwt(token);
  assert.strictEqual(claims?.sub, "u_123"); // the one that fails until the bug is fixed
});
```

**`package.json`**:

```json
{
  "name": "token-demo-scratch",
  "version": "1.0.0",
  "scripts": { "test": "node --test" }
}
```

Confirm it fails before you start (`npm test` → `tests 5 / pass 4 / fail 1`). The one‑line fix
and the full answer key are in [`presenter-notes.md`](presenter-notes.md) — read it once, then
present from memory.

#### Why the fixture stays spoiler-free

The scratch copy contains **no** solution comments and **no** README hint about the fix. That's
deliberate: in Run A you add the *whole folder* as context, and a strong model that can see
"the fix is `token.split(".")`" will just apply it — and your "wrong turn toward `validateToken`"
beat never happens. Keeping the answer in [`presenter-notes.md`](presenter-notes.md) (outside
`sample-repo/`, never copied to `$scratch`) preserves the room the model needs to wander in Run A.

---

## 2. One‑time setup (both surfaces)

Do this **before** you present — toggling models/tools mid‑session busts the prompt cache
(guide §A1), and you want a clean, repeatable baseline.

1. **Pick a hosted model**, not a local one. (Local models can leave the VS Code context ring
   gray at `0 / max` even on success — see [Troubleshooting](#8-troubleshooting).)
2. **Start from the `power` profile** so the contrast at the end is dramatic:
   ```powershell
   ./scripts/switch-profile.ps1 power   # backs up settings.json first
   ```
3. **Have both scoreboards open** (next section) and your font size up.
4. **Open the scratch repo** (not this one) in each surface so the auth task is the subject.
5. Optional but great: record two short clips, one per run, so the reveal is a clean cut.

---

## 3. Where the numbers live — the two scoreboards

The single most important slide: *teach the audience where to look first*, then every later
beat is just "watch that number move."

### VS Code (Copilot Chat)

| What | Exact click‑path | What it tells you |
|---|---|---|
| **Context‑window indicator** | The ring / progress bar next to the Chat input box. **Hover** it for `current / max tokens`. | Live fill of the window. Starts **visibly pre‑filled** (system prompt + tool schemas + reserved output buffer) before you type — *record the actual % during rehearsal; it varies by model/context size.* |
| **Chat Debug View** | Chat panel → overflow menu **`···`** (top‑right of the panel) → **Show Chat Debug View**. *(Label/location is version‑sensitive — confirm in your build.)* | Per‑request `prompt_tokens`, `completion_tokens`, `total_tokens`, **and cached/reused counts**. This is *the* place to prove caching in VS Code. |
| **Reasoning level** | Model picker dropdown under the Chat input → effort/reasoning selector (if your model exposes one). | Higher reasoning = more tokens/credits per turn (guide §B1). |
| **Scoped context** | **Add Context** → *Files & Folders* (or type `#` and pick the file) for one file, vs. dragging a whole folder in. | Smaller, more precise context (guide §A4). |

### Copilot CLI

| What | Exact command | What it tells you |
|---|---|---|
| **Context breakdown** | `/context` | Real‑time rows: custom instructions, system prompt, **tool definitions**, session history, repo memory. The "how full is the window" view. |
| **Usage graph** | `/usage` | Contribution‑style graph of **input / output / cache‑read / cache‑write** tokens for the session. |
| **Statusline** | (always on) | Mirrors `/context` + `/usage` live while you work. |
| **Free actions** | `!git status`, `/ask <q>` | `!` runs a shell command with **no model call**; `/ask` answers without adding to history (guide §A5). |

> Presenter tip: in the CLI, run `/context` **once now** and read the `toolDefinitions` row out
> loud. You'll come back to it after trimming tools and the number will be smaller.

---

## 4. Scripted Run A — *Naive*

The "how most people use it" run. **Narrate the mistakes as features** — the audience should
recognize their own habits. Do the run in **VS Code**, then repeat the key beats in the **CLI**.

> 🎙️ Frame: *"Watch the counters. I'm going to do everything slightly wrong, the way we all do
> when we're in a hurry."*

### A‑1 · Bloat the context

- **VS Code:** drag the **entire scratch folder** into Chat (not a single file). Hover the ring.
  → Point out the jump.
- **CLI:** `@.` (or add the whole directory) then `/context`. → Read the bigger history row.

### A‑2 · Ask vaguely (invite the wrong turn)

Same prompt on both surfaces — **no file named, no acceptance criteria**:

```
The auth tests are failing. Fix the token validation.
```

Let it run. With the vague prompt + whole‑folder context it will tend to reach for a
plausible‑sounding `validateToken` (which doesn't exist) and start editing around it.

### A‑3 · Let it ride

- Let a test fail, accept the *"let me try another way"* retry **once or twice**. Don't correct it.
- **VS Code:** open **Chat Debug View** → show `total_tokens` climbing each retry.
- **CLI:** `/usage` → show output tokens accumulating on thrown‑away work.

### A‑4 · Bust the cache (the silent tax)

- **VS Code:** switch the model in the picker mid‑thread → next turn, **Chat Debug View** shows
  **cached count drop toward 0**.
- **CLI:** `/model` switch → `/usage` cache‑read collapses.
- 🎙️ *"Every turn from here re‑bills the full prefix — including the wrong‑turn garbage still
  sitting in history."*

**Capture the final scoreboard** (see [shot list](#7-screenshot-checklist-per-surface)) before moving on.

---

## 5. Scripted Run B — *Disciplined*

Same task, same model, **clean session** (start a new chat / new CLI session so the cache prefix
and history are fresh). Now apply the guide.

> 🎙️ Frame: *"Same bug, same model. The only thing that changes is discipline."*

### B‑1 · Trim tools first (pre‑session) — guide §A3

- **CLI:** before asking anything, `/context` → note `toolDefinitions`. Disable an MCP server
  you won't need via `/mcp`, restart, `/context` again → **smaller baseline**. (Or point at
  [`../examples/mcp-config.minimal.json`](../examples/mcp-config.minimal.json).)
- **VS Code:** disable an unused tool/extension contributing to Chat → hover the ring → lower
  pre‑fill.

### B‑2 · Plan + scope precisely — guide §A4/§A5

- **VS Code:** enter **Plan** (or Agent) mode from the chat mode picker *(verify the control/label
  in your build — it may be `Shift+Tab` or a dropdown)* to agree the approach **before** editing.
  Add **only** the two relevant files via **Add Context → Files & Folders**: `src/auth/jwt.js`
  and `tests/auth.test.js`.
- **CLI:** plan mode (`Shift+Tab`), then `@src/auth/jwt.js @tests/auth.test.js`.

### B‑3 · Recon with `explore` **before** editing — guide §A2 *(CLI strength)*

Cheap, read‑only recon prevents the expensive wrong turn. Run it **before** any edit:

```
explore: explain how verifyJwt is used end-to-end. Cite file:line. Do NOT edit anything.
```

→ `/context` after: **main history barely moves** — the agent's file‑reading stayed in its own
window. (This is the beat the Naive run never gets.)

### B‑4 · Ground the ask (no room to hallucinate)

Now the surgical fix prompt — same on both surfaces:

```
@src/auth/jwt.js @tests/auth.test.js
verifyJwt() is the real helper (there is no validateToken). The round-trip test fails because
token.split(".", 1) drops the signature segment. Fix only verifyJwt in src/auth/jwt.js so the
test passes. Don't touch anything else. Done = `npm test` is green.
```

### B‑5 · Verify with `task`, and show the contrast — guide §A2

- **CLI:** after the edit, use **`task`** to run the tests:
  `run npm test and report pass/fail; full output only on failure`.
  → `/context`: history stays flat; the 5‑test output lived in the subagent.
- **Contrast beat:** run the *same* `npm test` **inline** (no `task` agent) and show
  `/context` / Chat Debug View jump. **That delta is the punchline.**

> 📸 **Capture the Disciplined scoreboard now** (see [shot list](#7-screenshot-checklist-per-surface)).
> Do it **before** the epilogue below — the next two steps deliberately change variables and bust
> the cache, so they must not be inside the measured A/B comparison.

---

### Epilogue (optional, *not* part of the measured A/B)

These show extra levers, but each one busts the prompt cache (guide §A1/§B1) — that's why they
come **after** you've captured the Run B numbers.

**E‑1 · Right‑size effort — guide §B1.** Drop reasoning `max → medium` for a mechanical edit
(VS Code picker / CLI `/model`) → fewer reasoning tokens, identical fix. Keep `max` for hard work.

**E‑2 · One‑command frugal switch.** From the **repo root** (not `$scratch`):

```powershell
.\scripts\switch-profile.ps1 lean
```

Re‑run `explore` / `task` → same workflow, cheaper models (Sonnet main + GPT‑5‑mini / 5.4‑mini
subagents).

---

## 6. The reveal — side by side

Put the two final scoreboards next to each other. This is the slide people screenshot.

**VS Code**

| Metric (Chat Debug View) | Run A — Naive | Run B — Disciplined |
|---|---|---|
| `total_tokens` (final turn) | _fill in_ | _fill in_ |
| Cached / reused tokens | low (busted) | high (stable prefix) |
| Context ring at finish | _% | _% |

**Copilot CLI**

| Metric (`/usage`) | Run A — Naive | Run B — Disciplined |
|---|---|---|
| Input tokens | _fill in_ | _fill in_ |
| Output tokens | _fill in_ | _fill in_ |
| Cache‑read tokens | low | high |
| `/context` history at finish | _fill in_ | _fill in_ |

🎙️ **Closing line (straight from the guide):** the highest‑ROI habits are **plan mode + `@file`
+ `explore`/`rubber‑duck`** — they're the rare levers that are *both* cheaper **and** higher
quality, because the biggest hidden cost is the [wrong turn](../docs/token-efficiency-guide.md#the-real-cost-of-a-wrong-turn),
which re‑bills on every later turn.

---

## 7. Screenshot checklist (per surface)

Tick these as you go; they're ordered to tell the story end‑to‑end. Filenames are suggestions —
keep Run A and Run B shots in separate folders so the reveal is a clean pair.

### VS Code

- [ ] `vscode-00-baseline-ring.png` — empty chat, ring already visibly pre‑filled (hover tooltip visible).
- [ ] `vscode-01-naive-folder.png` — whole folder added, ring jumped.
- [ ] `vscode-02-naive-debugview.png` — Chat Debug View with climbing `total_tokens` after retries.
- [ ] `vscode-03-cache-busted.png` — Debug View after mid‑thread model switch (cached ≈ 0).
- [ ] `vscode-04-disciplined-scoped.png` — two files only (Add Context), lower ring.
- [ ] `vscode-05-disciplined-debugview.png` — final Debug View, high cached / low total.
- [ ] `vscode-06-reveal.png` — A vs B side by side.

### Copilot CLI

- [ ] `cli-00-context-baseline.png` — `/context` showing `toolDefinitions` + system rows.
- [ ] `cli-01-tools-trimmed.png` — `/context` after `/mcp` trim (smaller toolDefinitions).
- [ ] `cli-02-naive-usage.png` — `/usage` mid‑Naive run, output tokens on wasted retries.
- [ ] `cli-03-subagent-flat.png` — `/context` after `task` ran tests (history stayed flat).
- [ ] `cli-04-inline-jump.png` — `/context` after same command inline (history jumped) — the contrast.
- [ ] `cli-05-usage-final.png` — `/usage` end of Disciplined run (high cache‑read).
- [ ] `cli-06-reveal.png` — A vs B `/usage` graphs side by side.

---

## Timing & talk track

| Beat | Focus | Surface | ~Time |
|---|---|---|---|
| Scoreboards | Where to look | Both | 2 min |
| Run A‑1…A‑4 | Naive: bloat, vague, ride, cache‑bust | VS Code → CLI | 6 min |
| Run B‑1…B‑2 | Trim tools, plan + scope | VS Code → CLI | 3 min |
| Run B‑3…B‑5 | Recon (`explore`) → fix → verify (`task`) + inline contrast | CLI | 4 min |
| Reveal | Side‑by‑side (capture **before** the epilogue) | Slide | 1 min |
| Epilogue (optional) | Effort drop + lean switch | Both | 1 min |

**One‑breath summary if you're short on time:** *baseline ring → drag whole folder (jumps) →
vague prompt (wrong turn) → switch model (cache dies) → new session, scope two files +
`explore` recon → grounded prompt → `task` to verify → counters stay flat → capture → side by
side.*

---

## 8. Troubleshooting

- **VS Code ring stays gray / `0 / max`.** Known UI bug with **local models** — the request
  can succeed while the ring never populates. Use a **hosted** model for the demo
  ([microsoft/vscode#313458](https://github.com/microsoft/vscode/issues/313458)).
- **Caching doesn't show savings.** The cache goes cold after ~5–10 idle minutes, and any
  change to model / effort / `contextTier` / MCP tools / instructions busts it. Don't fiddle
  mid‑run except where the script *wants* you to bust it (A‑4).
- **`/usage` numbers look flat between turns.** You may have compacted or rewound (both reset
  the cache). Start a fresh session for each run.
- **Subagent contrast underwhelms.** Make the test output genuinely verbose (e.g., add a couple
  more tests) so the inline‑vs‑`task` history delta is obvious.
- **Profiles didn't apply.** `switch-profile.ps1` writes to `~/.copilot` by default; pass
  `-CopilotDir` if yours lives elsewhere. It backs up `settings.json` first.

---

## Sources

Checked **2026‑06‑16**:

- Token‑efficiency guide (this repo) — [`../docs/token-efficiency-guide.md`](../docs/token-efficiency-guide.md)
- Prompt‑caching deep dive (this repo) — [`../docs/prompt-caching.md`](../docs/prompt-caching.md)
- GitHub Copilot CLI command reference — https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference
- GitHub Copilot CLI changelog (agents, context management) — https://github.blog/changelog/2026-01-14-github-copilot-cli-enhanced-agents-context-management-and-new-ways-to-install/
- Larger context windows + configurable reasoning levels — https://github.blog/changelog/2026-06-04-larger-context-windows-and-configurable-reasoning-levels-for-github-copilot/
- Decoding Copilot token costs in VS Code (Chat Debug View) — https://www.kenmuse.com/blog/decoding-copilot-token-costs-using-vs-code/
- Why Chat starts ~35% full — https://devactivity.com/insights/unpacking-copilot-s-context-window-why-your-software-development-software-starts-at-35-usage/
- VS Code local‑model context‑ring bug — https://github.com/microsoft/vscode/issues/313458
