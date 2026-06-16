# Token-efficiency guide for GitHub Copilot CLI

A practical, **validated** set of techniques to cut token consumption in the GitHub
Copilot CLI (verified against CLI **v1.0.63**), organised around one rule:

> **Never trade away answer quality unless the trade is clearly worth it.**

So the tips are split into two tiers:

- **Tier A — Zero quality loss.** Same answers, fewer tokens. Use all of these, always.
- **Tier B — Worth-it tradeoffs.** These *can* lower output quality; use them deliberately
  where the savings outweigh the (often negligible) cost.

> Sources (checked 2026‑06‑16):
> - GitHub Copilot CLI docs — https://docs.github.com/en/copilot/how-tos/use-copilot-agents/use-copilot-cli
> - Anthropic prompt caching — https://platform.claude.com/docs/en/build-with-claude/prompt-caching
> - OpenAI prompt caching — https://developers.openai.com/api/docs/guides/prompt-caching
> - Settings schema + compaction constants verified from the CLI package on this machine.
> - Recommendations validated by a GPT‑5.5 (xhigh) rubber-duck review.

---

## The mental model

Every turn you pay for: **tool definitions + system prompt + conversation history +
your message + the model's reasoning/output.** There are two ways to spend less:

1. **Pay less per token** (caching) and **spend fewer reasoning/output tokens** — *without
   dropping any context*. ← Tier A, no quality loss.
2. **Carry fewer/cheaper tokens** (smaller model, lower effort, summarised history). ←
   Tier B, a quality tradeoff.

| Cost bucket | Lever | Tier |
|---|---|---|
| Repeated input | **Prompt caching** — keep the prefix stable | A |
| Conversation history | Subagents (isolated context); compaction | A / B |
| Tool definitions | Trim **unused** MCP servers/tools | A |
| Reasoning/output | Model + **effort level** | B |

---

# Tier A — Zero quality loss

These change cost/latency only. The model's answer is **identical**.

## A1. Maximize prompt caching (the biggest free win)

Caching reuses your stable prefix at **~10% of input cost** (Anthropic) / up to **90% off**
(OpenAI) — for the **exact same output** (both providers confirm output is unchanged).

- Lock **model, effort, contextTier, MCP servers/tools, and instructions before you start** —
  changing any of them mid-session busts the whole cache (prefix order is `tools → system → messages`).
- **Front-load** large stable context with `@file` and reuse it; **append** new turns rather
  than editing earlier ones (`/rewind`/`/undo` and `/compact` reset the cache).
- Work in **bursts** — the cache goes cold after ~5–10 idle minutes (GPT‑5.5 keeps a 24h cache).

→ Full mechanics, pricing tables, and a checklist: [`prompt-caching.md`](prompt-caching.md).

## A2. Offload verbose work to subagents

Subagents run in a **separate context window** and return only a summary, so noisy output
never enters — or bloats — your main thread. The main answer keeps all the *relevant*
information, so quality is preserved (often improved).

- **`explore`** — codebase Q&A without polluting main context.
- **`task`** — runs tests/builds/installs; returns pass/fail + full output only on failure.
- **`research` / `general-purpose`** — heavier work in isolated context.

## A3. Trim only the tool definitions you don't use

Every enabled MCP server injects its tool schemas into the prefix **every turn**. Removing
servers/tools you *won't* use this session costs you nothing in capability.

- Add a `tools` allowlist per server (see `examples/mcp-config.minimal.json`).
- Disable unused servers via `/mcp`. Quantify the saving in `/context` (`toolDefinitions`).
- ⚠️ Do this **before** the session starts — toggling `/mcp` mid-session also busts the cache (A1).

## A4. Scope context precisely with `@file`

Pointing at the exact file is **more** precise than letting the agent read whole
directories — better grounding *and* fewer tokens.

## A5. Spend zero tokens when you can

- **`!command`** runs a shell command with **no model call** (e.g. `!git status`). Free.
- **`/ask`** asks a one-off side question **without** adding it to history (keeps the cached
  thread clean).
- **Plan mode** (`Shift+Tab`) agrees the approach before code is written — avoids expensive wrong turns.

## A6. Keep max context the smart way (no forced compaction)

You can hold a large window without dropping info:

- **`contextTier`** accepts `default` or `long_context`. Keep **`default`** until `/context`
  shows you're approaching the window, then switch to **`long_context`** so larger inputs are
  accepted before anything is summarised. *(Caveat: the long-context tier usually has a higher
  per‑token price — use it when you genuinely need the room, not by default.)*
- The CLI auto-compacts in the background at **~80%** of the token limit by default
  (buffer exhaustion at 95%, default limit 128k). **Keep auto-compaction enabled** (disabling
  it risks a hard truncation/stop at the limit). If you want it to retain more before
  summarising, nudge the threshold to **~0.85–0.88** (not higher) and confirm via `/context`.
- A concise, **stable** `copilot-instructions.md` steers every turn and stays cached (A1).

---

# Tier B — Worth-it tradeoffs (may lower quality)

Use these deliberately. Each notes when it's worth it and when it isn't.

## B1. Lower the effort level for routine work  ⭐ best tradeoff

`effortLevel` multiplies reasoning tokens every turn. Dropping `xhigh → high` (or `medium`)
**does** reduce reasoning depth — but on routine/mechanical work the quality difference is
usually negligible while the savings are large.

- **Worth it:** edits, refactors, lookups, boilerplate, summaries.
- **Keep `xhigh`/`max` for:** tricky debugging, architecture, multi-step reasoning.
- This is the single best place to save without touching context. Switch per task with `/model`.

## B2. Use a cheaper model for low-stakes turns

Smaller models (`gpt-5-mini`, `gemini-3.5-flash`, `gpt-5.4-mini`, `claude-haiku-4.5`) are
far cheaper but less capable on hard problems.

- **Worth it:** simple edits, file lookups, format conversions, quick questions.
- **Not worth it:** complex reasoning, subtle bugs — keep Opus/GPT‑5.5 there.
- Route per-subagent so grunt work goes cheap while the main agent stays strong (see profiles).

## B3. Compact stale history manually

`/compact` summarises history to reclaim tokens, but **loses nuance** and **resets the
cache** (A1).

- **Worth it:** the early transcript is genuinely stale and you're near the window.
- **Not worth it:** mid-task with a hot cache — you'd pay to rebuild the prefix. Prefer A6
  (long_context / threshold) to keep context instead.

## B4. Accept earlier compaction instead of `long_context`

Staying on `contextTier: default` and letting history compact sooner avoids the
long-context tier's higher per-token price — at the cost of some summarised history.
A cost-vs-fidelity trade; pick per session.

---

## The real cost of a wrong turn

A "wrong turn" — the agent picks a bad approach, edits the wrong file, hallucinates an
API, or misreads the task — is the **most expensive event** in agentic AI. Its cost is
rarely 1×; it compounds:

| Hidden cost | Why it hurts |
|---|---|
| **The wasted turn** | Reasoning + output + tool calls for work you throw away. At Opus `xhigh`, one big wrong turn can be thousands of output tokens at the high output rate. |
| **Context pollution (the big one)** | The wrong turn **stays in history**. Every later turn re-sends it — and once cached, you pay cache-read on garbage *every turn for the rest of the session*. |
| **Anchoring / quality drop** | The model sees its own earlier wrong reasoning and tends to stay consistent with it → worse answers downstream. A wrong turn doesn't just cost tokens, it **lowers quality**. |
| **Correction turns** | You explain the mistake, it re-reads, re-reasons, re-does — typically 2–3× the original work. |
| **Cleanup + cache reset** | Reverting bad edits, and `/rewind` / `/undo` to excise the turn, **bust the prompt cache** — so the next turn re-bills full input price. |

**Rule of thumb:** once pollution, correction, and cleanup are counted, a wrong turn
often costs **3–10× its own tokens** — and it quietly degrades every answer after it.

### How to minimize wrong turns

**Prevent (cheapest):**
1. **Plan first** — plan mode (`Shift+Tab`) / `/plan` to agree the approach before any code.
   A wrong *plan* costs a few hundred tokens; a wrong *implementation* costs thousands + cleanup.
2. **Ground it precisely** with `@file` — most wrong turns come from missing/wrong context or
   guessed assumptions. Give exact files; make ambiguous decisions explicit.
3. **State "done"** — clear acceptance criteria up front prevent the #1 cause: ambiguity.
4. **Make it ask, not guess** — for ambiguous forks, a cheap clarifying question beats an
   expensive wrong guess.
5. **De-risk with cheap agents** — `explore` (cheap) to verify how the code works *before* the
   expensive main agent edits; `rubber-duck` to sanity-check a plan before implementing.

**Catch early:**
6. **Watch and `Esc`** — stop a bad trajectory the moment you see it; don't let a long wrong
   turn finish.
7. **Reject with feedback** — when it proposes a wrong action, choose "No, and tell Copilot what
   to do differently" and steer inline, rather than letting it act then fixing.
8. **Verify each step** — have the `task` agent run tests/builds so a wrong turn fails *now*, not
   five turns later. Keep steps small and checkable.

**Contain the damage:**
9. **Excise, don't layer.** When a turn is clearly wrong, **`/rewind` or `/undo` to remove it**
   rather than appending corrections on top of the garbage. Yes, rewind resets the cache — but the
   polluted prefix would otherwise be re-billed (and keep biasing the model) *every* future turn,
   so removing it early is usually the cheaper, higher-quality choice.
10. **Commit known-good checkpoints** (git) so reverting bad file edits is one command, not manual.

> Where quality and cost align: a wrong turn is the rare thing that is both expensive *and*
> quality-lowering. The cheap prevention levers above (plan mode, `@file`, `explore` / `rubber-duck`)
> are the highest-ROI habits in this whole guide.

---

## Quick reference

| Goal | Command / setting | Tier |
|---|---|---|
| See token / cache usage | `/context`, `/usage` | A |
| Maximize caching | stable prefix; `@file`; bursts | A |
| Isolate verbose work | `explore` / `task` subagents | A |
| Fewer tool tokens | `/mcp`, `tools` allowlist (pre-session) | A |
| Free actions | `!shell`, `/ask`, plan mode | A |
| Keep max context | `contextTier: long_context` (when needed); threshold ~0.85–0.88 | A |
| Cheaper turns | `/model`, `effortLevel` (high/medium for routine) | B |
| Reclaim a stale window | `/compact` | B |
| Avoid wrong turns | plan mode, `@file`, `explore` / `rubber-duck`, `/rewind` early | A |
| Per-subagent routing | `subagents.agents.<name>` in `settings.json` | A/B |
