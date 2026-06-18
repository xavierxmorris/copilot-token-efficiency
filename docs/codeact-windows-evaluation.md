# CodeAct on Windows — a hands-on evaluation

An evaluation of the [`copilot-codeact-plugin`](https://github.com/jsturtevant/copilot-codeact-plugin)
("CodeAct") for the **GitHub Copilot CLI**, benchmarked on a real Windows machine and in WSL.
CodeAct collapses many tool calls into **one sandboxed Python run** so the conversation context is
replayed across fewer turns.

> Measured on 2026‑06‑18 against `@xavierxmorris`'s setup (Copilot CLI **v1.0.64** on Windows,
> **v1.0.63** in WSL Ubuntu 24.04, Python 3.14 / 3.12, Monty backend `pydantic-monty` 0.0.18). Every
> number came from the plugin's own `tests/run_tests.py perf` harness against a **copy of this repo**.
> The findings were cross‑checked by two independent review passes (GPT‑5.5 and Claude Opus 4.8),
> which corrected the original failure attribution — see **Caveats & method** at the end.

## TL;DR

- **Don't adopt it on native Windows today.** As shipped it is **broken on Windows** (the dispatch is
  Unix‑only) and makes things **~5–6× more expensive**. A small **port** (below) fixes the dispatch and
  takes roughly **a third** off the damage (−501% → −325% input) — but it's still **net‑negative**, because the way CodeAct passes inline
  Python (`--code '<python>'`) is fragile under PowerShell.
- The **mechanism is real**: given a correctly‑passed program, the Monty sandbox inventoried the whole
  working tree **in one call**. In a clean environment (WSL) it ran exactly as designed — **2 turns, no
  thrashing**.
- But on **small repos (~20 files)** it **didn't reduce output tokens** even when it worked (input/total
  weren't measurable in WSL), and in a **heavy
  MCP/agent setup** a single sandbox hiccup **cascades into a 10–16‑turn thrash**.
- The payoff only appears for **large fan‑out (30+ files) in a lean context** — which matches the
  plugin author's published **49–69%** numbers, not everyday work.

## What CodeAct is

Normally the agent loops *model → tool → model → tool …*, and every turn re‑sends the whole context
(system prompt, tool catalogs, prior messages). CodeAct instead has the model write **one Python
program** that chains `view`/`glob`/`grep`/`bash`/etc. and runs it in a sandbox
([Pydantic Monty](https://github.com/pydantic/monty) — a tiny Rust Python interpreter). Fewer turns →
the heavy context is replayed fewer times. With MCP servers loaded, each catalog adds to that per‑turn
context, so in theory the savings compound.

## The benchmark — same prompts, three environments

Two read‑only fan‑outs (read every file, parse it, aggregate). The harness runs each prompt twice —
**baseline** (plain Copilot, no plugin) and **codeact** (plugin loaded) — and reads token counts from
Copilot's process logs. *Read **Caveats & method** before quoting any single number — the arms aren't
perfectly symmetric and `n = 1` per cell.*

### 1. Native Windows — broken as shipped, still net‑negative after the port

Same prompt (`md-heading-index`, 9 markdown files), as shipped vs after my full port — both rows are
saved harness results ([`native-as-shipped-md.json`](codeact-bench-results/native-as-shipped-md.json),
[`native-ported-md.json`](codeact-bench-results/native-ported-md.json)), and the two baselines are
near‑identical, so it's a clean comparison:

| Arm | Input tok | Turns | Tools | Est. cost\* | Δ input |
|---|---:|---:|---:|---:|---:|
| baseline (as‑shipped run) | 112,232 | 3 | 2 | $0.30 | — |
| **codeact — as shipped** | **674,449** | **16** | 15 | $1.75 | **−501%** |
| baseline (fully‑ported run) | 112,825 | 3 | 2 | $0.30 | — |
| **codeact — fully ported** | **479,926** | **11** | 10 | $1.26 | **−325%** |

The port cut codeact's input blow‑up from **−501% to −325%** and turns from **16 to 11** — better, but
still **~4× baseline**. And it's **highly variable**: across saved runs the codeact arm ranged **10–16
turns and roughly −325% to −501%** input — never positive. The second prompt (`all-files-inventory`, ~20
files) corroborates: on an intermediate port it was **−482%** input (2 → 10 turns,
[`native-intermediate-allfiles.json`](codeact-bench-results/native-intermediate-allfiles.json)).
\*Cost is a normalised **GPT‑5.4** basis (see Caveats); the **% deltas are model‑independent**, the
dollar figures are not.

What the model actually did: it **did** invoke codeact (`codeact_invoked: true` in the saved run), but
the sandbox call failed (next section), and it then **thrashed** — probing its other tools
(`tool_search`, a `SELECT 1` SQL probe, a sub‑agent, shell `echo`s) for 11–16 turns instead of fixing
the program.

### 2. WSL (clean Linux Copilot) — works as designed

| Prompt | Arm | Output tok | Tools | Turns | Δ output | Δ turns |
|---|---|---:|---:|---:|---:|---:|
| md‑heading‑index | baseline | 730 | 3 | 3 | — | — |
| | **codeact** | 856 | **2** | **2** | −17% | **−33%** |
| all‑files‑inventory | baseline | 846 | 2 | 2 | — | — |
| | **codeact** | 1,095 | 2 | 2 | −29% | 0% |

Here CodeAct ran **cleanly in 2 turns — no thrashing**, collapsing one task from 3 turns to 2. It still
**didn't reduce output tokens** (it has to *write the program*, which adds output tokens); whether it
saved on input/total here is **unknown** — those weren't captured. *Input tokens couldn't
be read in the WSL build — Copilot 1.0.63 logs the field differently than 1.0.64 — so this uses output
tokens, turns, and tool calls. This run also used a different default model (see Caveats).*

### 3. The mechanism itself

Run directly with the real `python`, the Monty sandbox inventoried the **entire working tree** (path,
line count, keyword check, sorted) in **one execution**. The engine is sound; the problems are
everything *around* it.

## Why it's broken on native Windows (root cause)

Two layers fail. Both were reproduced on this machine.

**Layer 1 — the dispatch is Unix‑only (the plugin never runs at all):**

1. **`python3` is the broken Microsoft Store stub.** On stock Windows, `python3` is an app‑execution
   alias that just prints *"Python was not found…"*. Every install/dispatch script calls `python3`.
   The real interpreter here is `python` (`C:\Python314`).
2. **`scripts/codeact` is a bash script.** Copilot on Windows runs tool commands through **PowerShell**,
   and the default `bash` here is **WSL** — a different Linux environment with its own Python and no
   `uv`. So the bash dispatch can't run as written.
3. **The hook is wired bash‑only.** `hooks.json` registers `./hooks/pre-tool-use.sh`; the bundled
   `pre-tool-use.ps1` isn't referenced.

**Layer 2 — even with the dispatch fixed, passing the program is fragile (this is the real killer):**

The instructions tell the model to run `… codeact.py --code '<python>'`. Under PowerShell a
single‑quoted argument breaks two different ways, both verified here:

- **Inner single quotes split the argument.** `--code 'print(f"{x if c else 'na'}")'` → PowerShell
  passes two tokens and the backend errors with `unrecognized arguments: na}")` — **Monty never runs**.
- **The model's escape‑hatch also fails.** To dodge that, the model used escaped double quotes
  (`f"{\"yes\" if … else \"no\"}"`); Monty reads the `\` as a line continuation →
  `MontySyntaxError: Expected a newline after line continuation character`.

Either way the sandbox returns nothing, and in this heavy setup the failure **cascades into thrashing**.
*The robust fix is to pass the program via `--code-file` (write the program to a temp file, then run
`python …codeact.py --auto --code-file prog.py`) instead of a single‑quoted `--code` arg — that avoids
the shell entirely. (`--stdin` exists but expects a JSON payload, not raw Python.)* The port below does
**not** yet do this, which is why native stayed
net‑negative.

## The Windows port

A small, Windows‑only port in a local clone (the Unix path is untouched):

| File | Change | Effect |
|---|---|---|
| `scripts/preflight.ps1` | `python3` → `python`; check `$LASTEXITCODE` instead of a dead `try/catch` | preflight passes on Windows |
| `scripts/install-instructions.ps1` | `python3` → `python`; substitute `{{BACKEND_LIMITATIONS}}` (was left raw → the model never got the Monty rules); rewrite the **Invoke** line in *both* the instructions and agent files to `python "<dir>\skills\monty-codeact\scripts\codeact.py" … --code '<python>'` | **this is the actual dispatch fix** — the model invokes the backend on turn 1 |
| `scripts/codeact.cmd` *(new)* | a manual wrapper that resolves the backend and runs it with the real `python` (auto‑installs `pydantic-monty`) | convenience only — **not** on the model's path (the install rewrite calls `python …codeact.py` directly) |

This **fixes the dispatch** (proven: correct invocation on turn 1) and **adds the Monty guidance**, which
cut the worst of the blow‑up (−501% → −325% input, 16 → 11 turns) but didn't make it positive. It is **not enough** for a positive result, because of Layer 2 (the
`--code '<python>'` quoting) and the thrash‑on‑failure behaviour below. A genuinely robust port would
switch the Invoke line to `--code-file`.

## Monty is a real but narrow Python subset

Verified in the installed `pydantic-monty` 0.0.18 — and note the plugin's own `SKILL.md` is **stale**
here (it lists things that actually work):

- **Works:** f‑string format specs (`f"{5:>5}"` → `␣␣␣␣5`, `f"{x:.2f}"`), lambdas, `sort(key=…)`.
- **Fails:** `str.format()`, `class`, `match`/`case`, `os.path`/`os.walk`, and
  **backslash escapes inside f‑strings** (`f"{\"a\"}"`). Capable models still trip these, and the
  sandbox errors. *(Set comprehensions, `startswith(tuple)`, and format specs all work — the plugin's
  `SKILL.md` lists some of these as broken, but they aren't in 0.0.18.)*

## Why even the clean run didn't save tokens here

- **Modern Copilot batches well.** Baseline finished these in 2–3 turns, so there were few round‑trips
  to collapse. (The plugin targets **≥8 files** and says **<5 files** isn't worth it; these repos are
  ≥8, so CodeAct *was* indicated — it just had little to gain.)
- **CodeAct adds output tokens** — the model has to *write the program*. On a small fan‑out that meets
  or exceeds the reads it saves.

## What about MCP from inside the sandbox?

The sandbox **can** reach MCP servers, but narrowly. The plugin ships an `mcp_call()` bridge
(`scripts/mcp-bridge.py`):

- It registers `mcp_call` **only** when a **workspace MCP config** declares servers (`.mcp.json`,
  `.vscode/mcp.json`, or `.github/copilot/mcp.json`). In this eval there was none, so `mcp_call` wasn't
  even in the tool list.
- It does **not** reuse Copilot's already‑loaded MCP sessions, and it **re‑spawns** stdio servers with a
  stripped environment — so **HTTP servers like `microsoft-learn` are bridgeable**, but
  **token‑authenticated ones like `bluebird` generally won't work**.

So most of your live‑docs / code‑search turns get no benefit unless you re‑declare those servers
per‑project — and even then, only the ones that survive a stripped env.

## When CodeAct actually helps

- **Large fan‑out** — 30+ files, bulk edits, full‑project indexing — where baseline genuinely needs many
  sequential reads.
- **Built‑in tools** — `view`, `create`, `edit`, `glob`, `grep` (needs `rg`), `bash`, `sql`,
  `web_fetch`, `github_api`, plus the narrow `mcp_call` bridge above.
- **A lean context and a Unix‑like shell** (Linux/macOS/WSL, or a Windows port that uses `--code-file`).

The author's **49–69%** input‑token reductions were measured on a 30+ file fixture — exactly that
niche. Treat them as directional (a community, experimental plugin), not as everyday savings.

## Recommendation for this setup

**Skip it on native Windows for now.** If you want it:

1. Run Copilot in **WSL/Linux**, or apply the **port** above (and switch the Invoke line to `--code-file`).
2. Reserve it for **genuine 30+ file, built‑in‑tool batch jobs** — not routine work.
3. Keep **MCP lean** during those runs (the catalogs are both the context it saves *and* the trap it
   thrashes into on failure).

For day‑to‑day token savings, the levers in [`docs/token-efficiency-guide.md`](token-efficiency-guide.md)
(caching, scoped `@file`, subagents, trimming unused MCP tools, lower effort for routine work) are both
safer and bigger than CodeAct.

## Caveats & method

The comparison is honest but not perfectly controlled — quote it with these in mind:

- **Asymmetric arms.** The harness runs **baseline with `--no-custom-instructions` and no plugin**, but
  the **codeact arm keeps custom instructions on, loads the plugin, and appends *"Use codeact…"***. So
  part of codeact's per‑turn input is context the baseline never paid for.
- **Cost basis is fixed GPT‑5.4 pricing** (`input×$2.50/M + output×$15/M`). Native here likely ran the
  documented Opus default, so **actual** native cost is several× the figures shown. The **% input/turn
  deltas are model‑independent**; the **dollar amounts are a normalised proxy**.
- **Different builds/models per environment.** Native = Copilot 1.0.64 (Opus‑class default); WSL =
  1.0.63 (Sonnet‑class default). WSL's clean 2‑turn run reflects **both** a leaner context **and** a
  lighter model — don't attribute it to context alone.
- **Tiny sample.** Two prompts, `n = 1` per cell, on a ~20‑file repo; baselines are non‑deterministic
  (one `md-heading-index` baseline timed out). Treat the magnitudes as directional. The **direction is
  solid for native** (net‑negative across every run); for **WSL** the honest read is *operationally
  clean (2 turns, no thrash) but output‑token‑negative — total/input cost there is unknown* (not
  captured). Raw results: [`codeact-bench-results/`](codeact-bench-results/).
- **Input tokens** were captured on Windows (1.0.64) but not in WSL (1.0.63 log format).

## Reproduce it

```powershell
git clone https://github.com/jsturtevant/copilot-codeact-plugin
python -m pip install uv pydantic-monty       # uv + the Monty backend

# (Windows) apply the port: python3 -> python in scripts\preflight.ps1 and
# scripts\install-instructions.ps1, substitute {{BACKEND_LIMITATIONS}}, and rewrite the
# Invoke line to call python ...codeact.py (ideally via --code-file). See the port table above.

powershell -File plugins\codeact\scripts\install-instructions.ps1 -Backend monty
python plugins\codeact\tests\run_tests.py perf `
  --prompts prompts.json --workspace <copy-of-repo> `
  --plugin-dir plugins\codeact --min-token-reduction 0
```

Each prompt runs Copilot twice (~2 premium requests/prompt); always benchmark a **copy** (the harness
uses `--yolo`).

## Sources

- CodeAct plugin & published benchmarks — <https://github.com/jsturtevant/copilot-codeact-plugin>
- Pydantic Monty (default backend) — <https://github.com/pydantic/monty>
- CodeAct pattern background — <https://devblogs.microsoft.com/agent-framework/codeact-with-hyperlight/>
