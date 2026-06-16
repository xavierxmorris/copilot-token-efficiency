# copilot-token-efficiency

Practical, **validated** techniques to maximize token efficiency in the **GitHub Copilot CLI** —
plus runnable scripts and switchable model profiles. Tips are mapped to features that
actually exist in the CLI (verified against **v1.0.63**), not generic advice.

> Built and validated against `@xavierxmorris`'s setup on 2026‑06‑16. Sources cited in
> [`docs/token-efficiency-guide.md`](docs/token-efficiency-guide.md).

## Quality first

The guide is split into two tiers so you never sacrifice answer quality by accident:

- **Tier A — zero quality loss.** Same answers, fewer tokens. (Caching, subagents, scoped
  `@file`, trimming unused tools, keeping max context smartly.)
- **Tier B — worth-it tradeoffs.** May lower quality; use deliberately. (Lower effort for
  routine work, cheaper model for low-stakes turns, compacting stale history.)

## TL;DR — the biggest levers

1. **Maximize prompt caching (zero quality loss).** Cached input bills at **~10%** (Anthropic)
   / up to **90% off** (OpenAI) for the **identical** output. Keep your prefix stable. See
   [`docs/prompt-caching.md`](docs/prompt-caching.md).
2. **Offload to subagents** (`explore`, `task`) — isolated context, summary-only return.
3. **Keep max context the smart way** — `contextTier: long_context` only when needed; keep
   auto-compaction on (threshold ~0.85–0.88), don't disable it.
4. **Trim only *unused* MCP tool definitions** (before the session — toggling mid-session busts the cache).
5. **Lower effort for routine work** (Tier B) — `xhigh → high/medium` saves the most reasoning tokens; keep `xhigh`/`max` for hard tasks.
6. **Avoid wrong turns — the biggest hidden cost.** A bad approach pollutes context and re-bills
   (at cache-read rate) on *every* later turn, anchors the model, and forces correction + cleanup —
   often **3–10× cost** plus a quality drop. Prevent with plan mode + `@file` + `explore`/`rubber-duck`;
   `/rewind` early to excise it. See the guide's *"real cost of a wrong turn"* section.

Full details: [`docs/token-efficiency-guide.md`](docs/token-efficiency-guide.md) ·
Caching deep dive: [`docs/prompt-caching.md`](docs/prompt-caching.md) ·
Reference setup analysis: [`docs/your-setup-analysis.md`](docs/your-setup-analysis.md).

## Two switchable profiles

| Profile | Default model | Effort | When |
|---|---|---|---|
| [`power`](examples/settings.power.json) | `claude-opus-4.8` | `max` (subagents GPT‑5.5 `xhigh`) | Maximum capability (documented default) |
| [`lean`](examples/settings.lean.json) | `claude-sonnet-4.6` | `medium` | Token-efficient everyday work |

Both use the **real** settings schema verified from the CLI package:
`model`, `effortLevel`, `contextTier`, and `subagents.agents.<agent-name>` with
per‑agent `model` / `effortLevel` / `contextTier`. Valid agents:
`explore, task, code-review, rubber-duck, research, general-purpose`.

## Quick start

```powershell
# 1. See what you're currently paying for (read-only)
./scripts/check-usage.ps1

# 2. Audit your config for token waste (read-only)
./scripts/audit-config.ps1

# 3. Switch profiles (backs up your settings.json first)
./scripts/switch-profile.ps1 power     # maximum capability
./scripts/switch-profile.ps1 lean      # frugal
./scripts/switch-profile.ps1 lean -WhatIf   # preview without writing
```

> Scripts target `~/.copilot` by default; override with `-CopilotDir`. PowerShell 5.1+
> (Windows) or PowerShell 7 (cross‑platform). `switch-profile.ps1` is the only script
> that writes — and it backs up first.

## What's inside

```
copilot-token-efficiency/
├── docs/
│   ├── token-efficiency-guide.md   # Tier A (zero loss) + Tier B (tradeoffs)
│   ├── prompt-caching.md           # Input-token caching deep dive + how to max it
│   └── your-setup-analysis.md      # Findings for the reference setup
├── examples/
│   ├── settings.power.json         # Opus 4.8 max + GPT-5.5 xhigh profile
│   ├── settings.lean.json          # Token-efficient profile
│   ├── mcp-config.minimal.json     # Trimmed MCP / tool allowlists
│   └── copilot-instructions.md     # Context-discipline custom instructions
└── scripts/
    ├── switch-profile.ps1          # Apply lean/power (with backup)
    ├── check-usage.ps1             # Token-posture dashboard (read-only)
    └── audit-config.ps1            # Flag token waste + fixes (read-only)
```

## The honest tradeoff

You can't have *both* "maximum capability by default" *and* "minimum tokens" — Opus 4.8 `max`
+ GPT‑5.5 `xhigh` is the most expensive configuration. This repo's stance: run **power** as
the default for quality, claw back tokens *within* it via discipline (compact/new,
subagents, scoped `@` context, trimmed MCP), and one‑command **switch to lean** when you
want to be frugal.

## License

MIT — see [LICENSE](LICENSE).
