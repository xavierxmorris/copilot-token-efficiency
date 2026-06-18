# CodeAct benchmark — raw results

Saved `tests/run_tests.py perf` output backing
[`../codeact-windows-evaluation.md`](../codeact-windows-evaluation.md). Each `*.json` is the harness's
own results file (baseline vs codeact, token counts from Copilot's process logs). Prompts are the exact
inputs used.

| File | Doc section | What it is |
|---|---|---|
| [`native-as-shipped-md.json`](native-as-shipped-md.json) | §1, "codeact — as shipped" | Native Windows, plugin **unported**. `md-heading-index`: baseline 112,232 in / 3 turns; codeact 674,449 in / 16 turns → **−501%** input. |
| [`native-ported-md.json`](native-ported-md.json) | §1, "codeact — fully ported" | Native Windows, **full port** applied. `md-heading-index`: baseline 112,825 in / 3 turns; codeact 479,926 in / 11 turns → **−325%** input. `status: valid`, `codeact_invoked: true`. |
| [`native-intermediate-allfiles.json`](native-intermediate-allfiles.json) | §1 corroboration | Native Windows, **intermediate port** (before `{{BACKEND_LIMITATIONS}}` was substituted). `all-files-inventory`: baseline 75,181 in / 2 turns; codeact 437,667 in / 10 turns → **−482%** input. (The `md-heading-index` arm in this run timed out → `baseline_failed`.) |
| [`wsl-clean-two.json`](wsl-clean-two.json) | §2, WSL | Clean Linux Copilot (1.0.63) in WSL, plugin **as shipped**. Both prompts ran cleanly in **2 turns each**, no thrash. Output tokens +17–29%; **input tokens not captured** in this Copilot build (`input_token_reduction_pct` is 0/absent). |
| [`prompts-two.json`](prompts-two.json) | — | The two fan-out prompts (`md-heading-index`, `all-files-inventory`). |
| [`prompts-md.json`](prompts-md.json) | — | The single `md-heading-index` prompt used for the saved ported re-run. |

## Caveats (see the doc's "Caveats & method")

- The harness runs **baseline with `--no-custom-instructions` and no plugin**; the **codeact arm keeps
  custom instructions on, loads the plugin, and appends *"Use codeact…"***. The arms aren't symmetric.
- `*_cost_est` uses a **fixed GPT-5.4 price basis** (`input×$2.50/M + output×$15/M`) regardless of the
  model actually used. The **% deltas are model-independent**; the dollar figures are a normalised proxy.
- Native = Copilot 1.0.64 (Opus-class default); WSL = 1.0.63 (Sonnet-class default). `n = 1` per cell on
  a ~20-file repo; baselines are non-deterministic.
