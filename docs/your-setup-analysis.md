# Your setup — analysis & validated findings

Snapshot of `@xavierxmorris`'s GitHub Copilot CLI configuration (v1.0.63), with each
token-efficiency tip validated against what's actually configured. Generated 2026‑06‑16.

## What's configured today

| Setting | Value | Token impact |
|---|---|---|
| Default model | `claude-opus-4.8` | Highest-tier model |
| Effort level | `xhigh` | **Heavy reasoning on every turn — biggest cost driver** |
| Context tier | (default) | Fine |
| Subagent models | none set → experiment defaults | `task`/general → GPT‑5.4, `explore` → GPT‑5.4‑mini (already cheap ✅) |
| Prompt caching | ON (Anthropic messages API) | Good — reuses stable prefix at ~10% input cost |
| MCP allowlist | ON (experiment) | Good — but see findings |
| MCP servers | `context7` (2 tools), `microsoft-learn` (all), `bluebird` (all) | Tool defs load every turn |

## Validated findings

1. **Effort level is your #1 lever.** Running `claude-opus-4.8` at `xhigh` by default
   means maximum reasoning tokens on even trivial turns. ✅ *Confirmed in
   `settings.json` (`model`, `effortLevel`).* → Use a lean default and switch up
   on demand (see profiles).

2. **Subagent defaults are already efficient.** `explore` uses GPT‑5.4‑mini and
   `task` uses GPT‑5.4 via experiment flags `copilot_cli_gpt_5_4_mini_for_explore`
   and `copilot_cli_gpt_5_4_for_subagents`. ✅ Keep using `explore`/`task` to keep
   verbose work out of the main context.

3. **Prompt caching is active** (`copilot_cli_anthropic_messages_api`). ✅ To benefit,
   keep stable context up front and avoid restating large blocks mid-session.

4. **MCP tool definitions are partly untrimmed.** `context7` is allowlisted to 2 tools,
   but `microsoft-learn` and `bluebird` load **all** their tools every turn. `bluebird`
   in particular exposes many code-search tools. → If a session isn't doing code search,
   disable `bluebird` via `/mcp`, or add a `tools` allowlist. Quantify via `/context`
   (`toolDefinitions`).

5. **No per-subagent overrides set.** You can now route each subagent explicitly via
   `subagents.agents.<name>` (schema confirmed in the CLI package). The example
   profiles do this.

## Recommended profiles

Two switchable profiles are provided in `examples/`:

- **`settings.power.json`** — your chosen default: Opus 4.8 `max` + GPT‑5.5 `xhigh`
  on heavy subagents. Maximum capability.
- **`settings.lean.json`** — token-efficient everyday alternative.

Switch with `scripts/switch-profile.ps1` (backs up your live `settings.json` first).
Audit anytime with `scripts/audit-config.ps1`.

## The honest tradeoff

You asked for *both* maximum token efficiency *and* Opus 4.8 max + GPT‑5.5 xhigh as the
default. Those pull in opposite directions: the power profile is the **most** token-hungry
configuration. The recommended pattern is **power as your default for quality**, plus the
discipline tips (compact/new, subagents, scoped `@` context, trimmed MCP) to claw back
tokens *within* that profile — and a one-command switch to **lean** when you want to be frugal.
