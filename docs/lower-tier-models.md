# Getting the most from lower-tier models

The cheap/fast tier — **Claude Haiku 4.5, GPT‑5 mini, GPT‑5.4 mini, Gemini 3.5 Flash,
MAI‑Code‑1‑Flash** — can do a large share of agent work at a fraction of the cost with
**negligible or no material quality loss on the right jobs** (tightly scoped, low‑stakes,
and mechanically or independently verified). The whole skill is (1) matching the job to the tier and
(2) constraining these models so they don't take a wrong turn (they wander more than frontier
models — see [`token-efficiency-guide.md`](token-efficiency-guide.md#the-real-cost-of-a-wrong-turn)).

> Pricing below is **indicative API list price** (live sources, 2026‑06‑16) shown only to
> convey the *relative* tier. The Copilot CLI may bill differently (premium‑request
> multipliers), but the speed/cost/capability ordering is what drives routing.

## The lower tier at a glance (as exposed in this CLI)

| Model (CLI id) | Effort range (CLI) | Character | Indicative price /M | Best at | Weak at |
|---|---|---|---|---|---|
| **Claude Haiku 4.5** (`claude-haiku-4.5`) | *no effort knob* (pre‑tuned) | Fast, strong‑for‑size (~73% SWE‑bench vs Sonnet ~77%), 200k ctx | ~$1 in / $5 out | Scoped edits, review triage, summarization, agent sub‑tasks | Frontier reasoning, subtle multi‑file debugging |
| **GPT‑5 mini** (`gpt-5-mini`) | low–high | Huge **400k** context, very cheap, solid function‑calling | ~$0.25 in / $2 out (cached **~$0.025**) | Large‑context exploration, tool/loop orchestration, classification | Deep ambiguous reasoning |
| **GPT‑5.4 mini** (`gpt-5.4-mini`) | low–**xhigh** | A mini with an effort dial you can push to xhigh | ~$0.75 in / $4.50 out | Same as GPT‑5 mini, but can push reasoning when a bounded task needs it | Still a mini ceiling |
| **Gemini 3.5 Flash** (`gemini-3.5-flash`) | low–high | Very low latency, broad general+code | low | Quick completion, summarize, extract, broad lookups | Depth / long‑horizon reasoning |
| **MAI‑Code‑1‑Flash** (`mai-code-1-flash-internal`) | low–high | Microsoft fast, code‑specialized small model (internal — no public specs) | n/a | Mechanical code tasks, snippets, boilerplate, quick edits | General/non‑code reasoning |

## Where the cheap tier shines (negligible quality loss)

Lower‑tier models match bigger ones on **well‑scoped, mechanical, verifiable** work — and
that's a big slice of agent time:

- Codebase exploration — *"where is X / how does Y work"* (the `explore` agent).
- Running tests / builds / lints and reporting pass-fail (the `task` agent).
- Summarizing files, logs, diffs.
- Mechanical edits with a clear pattern (rename, add a field, boilerplate, repetitive refactor).
- Classification, routing, extraction.
- First‑draft scaffolding you'll review anyway.

On these you lose little to nothing using Haiku/mini/flash **when the output is checked**
(a test run, a diff, a quick read) and the task doesn't need frontier reasoning. Watch for
*silent* failures — a small model may omit an edge case or misjudge relevance — so don't skip
the verification step.

## Where they take wrong turns (route up instead)

- Architecture / design trade‑offs.
- Subtle multi‑file debugging with an unclear root cause.
- Security‑sensitive logic.
- Ambiguous specs that need judgment.
- Long‑horizon planning.

Their failure mode **is** the wrong turn. Because they wander more on ambiguity, an
*under‑specified* cheap task can cost **more** than one good frontier turn once you add the
correction + cleanup. Match the tier to the job.

## How to max their CAPABILITY

1. **Tight scope, zero ambiguity.** They don't fill gaps as well as frontier models — give
   exact files (`@file`), exact acceptance criteria, and the precise change. Ambiguity →
   wandering.
2. **Few‑shot the pattern.** Show *one good* example of the edit/output to copy. For
   pattern‑sensitive tasks this is among the biggest levers — it pushes the model from
   *inventing* toward *imitating*. (A bad or incomplete example overfits it to the wrong
   pattern, so make the example correct.)
3. **Turn up the effort dial where it exists.** `gpt-5.4-mini` goes to **xhigh**;
   `gpt-5-mini` / `gemini-3.5-flash` / `mai-code-1-flash` to **high**. More reasoning budget
   helps on *bounded‑but‑harder* tasks — but use it only when the extra reasoning is cheaper
   than routing to a frontier model (a mini at xhigh *plus* a correction turn can erase the
   cost advantage). (Haiku has no knob — it's pre‑tuned.)
4. **Decompose.** Break a big task into small, independently verifiable steps. Small models
   excel step‑by‑step and struggle holistically.
5. **Ground with live docs.** Pull current docs (Microsoft Learn / Context7) so they don't
   hallucinate APIs — small models hallucinate more, so grounding pays off most here.
6. **Verify every step.** Pair the cheap doer with a check: a `task`‑agent test/build run, or a
   `code-review` pass on a stronger model. Cheap generation + **deterministic** verification
   (tests, builds, exact diffs, schema checks) often beats expensive one‑shot — but use a
   **stronger verifier** for judgment‑heavy or high‑stakes work, where a cheap verifier may
   share the doer's blind spots.

## How to max their EFFICIENCY

1. **Route them as subagents — the killer pattern.** The cheap model does the verbose grunt
   work in an **isolated context**; only a short summary returns to your expensive main
   thread. You get cheap tokens *and* a clean main context (no pollution). Configure in
   `settings.json` under `subagents.agents.*`. *Caveat:* each subagent still pays its own
   input/output/reasoning + tool tokens — only the **summary**, not the full transcript,
   returns to the main thread.
2. **Match tier to job:**
   - `explore` (read‑only, high‑volume reads) → default `gpt-5-mini` low/medium for large
     sweeps (verified 400k context, lowest price); escalate to `gpt-5.4-mini` high/xhigh for
     bounded synthesis or harder reasoning.
   - `task` (run commands, report) → cheapest: `gpt-5-mini` low / `mai-code-1-flash`.
   - `code-review` → **first‑pass/triage → Haiku** (fast); **final review, security‑sensitive,
     or complex multi‑file diffs → a stronger model** (`gpt-5.4-mini` high/xhigh or your
     frontier model). A cheap reviewer can share the author's blind spots.
   - **Main agent** → your frontier model, for the actual decisions and edits.
3. **Caching still applies — per subagent.** Each subagent has its **own** effective cache
   prefix, so savings apply only when *that* model/effort reuses a stable prefix within the
   TTL (a one‑shot subagent may see little benefit; output/reasoning tokens are always billed).
   Keep prefixes stable (see [`prompt-caching.md`](prompt-caching.md)). Where context *does*
   repeat, GPT‑5 mini's cached input (~$0.025/M) makes re‑reads cheap.
4. **Use big context deliberately.** GPT‑5 mini's 400k window lets you avoid premature
   compaction *when you genuinely need the context* — not as permission to dump irrelevant
   files (that still costs input tokens, can miss cache, and dilutes relevance).

## Example — a "cheap‑subagent" profile

Frontier model decides and edits; the cheap tier does the reading, running, and first drafts
in isolation; only summaries return to the main thread.

```json
{
  "model": "claude-opus-4.8",
  "effortLevel": "high",
  "subagents": {
    "agents": {
      "explore":     { "model": "gpt-5-mini",          "effortLevel": "medium" },
      "task":        { "model": "gpt-5-mini",          "effortLevel": "low" },
      "code-review": { "model": "gpt-5.4-mini",        "effortLevel": "high" },
      "research":    { "model": "gemini-3.5-flash",    "effortLevel": "high" }
    }
  }
}
```

> Escalate `explore` to `gpt-5.4-mini` (high/xhigh) for harder synthesis; reserve
> `claude-haiku-4.5` for `code-review` to **low‑risk, first‑pass triage** only.

(See [`examples/settings.lean.json`](../examples/settings.lean.json) for a full lean profile and
[`examples/settings.power.json`](../examples/settings.power.json) for the max‑reasoning one.)

## Example prompts that suit the cheap tier

```
✓ "Find every call site of chargeCard() and list file:line."            (explore / Haiku)
✓ "Run npm test; if it fails, paste the failing test names and the
   first stack frame only."                                            (task / gpt-5-mini)
✓ "Add a createdAt: Date field to the User interface in
   src/models/user.ts and to the 3 factory functions in the same file.
   Here's the exact pattern: <example>."                               (mai-code-1-flash)

✗ "Figure out why checkout is flaky and fix it."  → ambiguous + multi-step → route up.
```

## Bottom line

Lower‑tier models aren't *worse* — they're *narrower*. Routed to scoped, verifiable,
high‑volume work as **isolated subagents**, they cut cost sharply with **negligible quality
loss**. Push them past their lane (ambiguous, multi‑step, high‑stakes) and they take wrong
turns — which, per the previous section, is the most expensive thing of all.

---

*Sources (live, 2026‑06‑16): Anthropic Claude Haiku 4.5 specs/pricing; OpenAI GPT‑5 mini /
GPT‑5.4 mini specs/pricing; Google Gemini 3.5 Flash. MAI‑Code‑1‑Flash is a Microsoft internal
model exposed in this CLI; exact specs aren't publicly documented, so only its behavioral
character is described. Verify current numbers against each provider's pricing page.*
