# Token-efficiency guide for GitHub Copilot CLI

A practical, **validated** set of techniques to cut token consumption in the GitHub
Copilot CLI, mapped to features that actually exist in the tool (verified against
CLI **v1.0.63**). Every tip lists the real command/feature and why it saves tokens.

> Sources (checked 2026‑06‑16):
> - GitHub Copilot CLI docs — https://docs.github.com/en/copilot/how-tos/use-copilot-agents/use-copilot-cli
> - Anthropic prompt caching — https://platform.claude.com/docs/en/build-with-claude/prompt-caching (cache hits bill at ~10% of input → up to 90% input savings; 5‑min default window)
> - Feature names verified against the CLI's own `/help` and package on this machine.

---

## The mental model

Every turn you pay for: **system prompt + tool definitions + conversation history + your message + the model's reasoning/output.** Token efficiency = keep each of those small and reuse the cacheable parts.

| Cost bucket | Biggest lever |
|---|---|
| Reasoning/output | Model + **effort level** (Opus/`max` and GPT‑5.5/`xhigh` are the heaviest) |
| Conversation history | `/compact`, `/new`, subagents (isolated context) |
| Tool definitions | Number of MCP servers/tools loaded; use `tools` allowlists |
| Repeated context | Prompt caching — keep stable context up front, don't restate it |

---

## 1. Right-size the model and effort (biggest lever)

Effort level multiplies reasoning tokens on **every** turn. Opus 4.8 at `max` and
GPT‑5.5 at `xhigh` produce the best results and the largest bills.

- **Do:** keep a lean default (`claude-sonnet-4.6` / `medium`, or `gpt-5.5` / `medium`) and switch up only for hard tasks.
- **How:** `/model` to change model, `effortLevel` in `settings.json`, or `/model auto` to let Copilot pick.
- Valid effort levels seen in the model list: `low, medium, high, xhigh` (GPT‑5.5) and `low, medium, high, xhigh, max` (Opus 4.8).

## 2. Offload to subagents (isolated context)

Subagents run in a **separate context window** and return only a summary — the verbose
work never enters your main transcript.

- **`explore`** — codebase Q&A without polluting main context. Cheap model by default.
- **`task`** — runs tests/builds/installs; returns "passed/failed" + full output only on failure.
- **`research` / `general-purpose`** — heavier, separate context.
- **How:** these are invoked automatically; route per-agent models via `subagents.agents.<name>` (see below).

## 3. Compact and reset aggressively

- **`/compact`** — summarises conversation history to reclaim context tokens (optionally focus it: `/compact keep auth changes`).
- **`/new`** — start a fresh conversation between unrelated tasks instead of dragging a bloated transcript.
- **`/context`** — visualise current token usage by bucket (system, tool defs, history). Use it to find bloat.
- **`/usage`** — session usage metrics.

## 4. Trim tool definitions

Every enabled MCP server injects its tool schemas into the system prompt **on every turn**.

- Use a `tools` allowlist per MCP server to load only the tools you use (see `examples/mcp-config.minimal.json`).
- Disable servers you aren't using this session via `/mcp`.
- Check the `toolDefinitions` line in `/context` to quantify the cost.

## 5. Scope context precisely

- **`@path/to/file`** adds just that file — far cheaper than letting the agent read whole directories.
- Ask for diffs/changed blocks, not whole files, in custom instructions.
- Prefer the `explore` subagent over loading many files into the main thread.

## 6. Spend zero tokens when you can

- **`!command`** runs a shell command directly with **no model call** (e.g. `!git status`). Free.
- **Plan mode** (`Shift+Tab`) lets you agree the approach before the model writes code, avoiding expensive wrong turns.

## 7. Preserve the prompt cache

Anthropic prompt caching reuses a stable prefix at ~10% of input cost. It's already on
for this CLI (Anthropic messages API). To benefit:

- Keep stable context (instructions, files) **up front**; put the changing ask **last**.
- Don't re-paste large blocks mid-session — edits before the cached prefix invalidate the cache.
- Keep custom instructions concise and stable.

## 8. Concise, durable custom instructions

A short `copilot-instructions.md` (see `examples/`) that enforces brevity and context
discipline pays for itself every turn by preventing re-explanation and over-reading.

---

## Quick reference

| Goal | Command / setting |
|---|---|
| See token usage | `/context`, `/usage` |
| Shrink history | `/compact`, `/new` |
| Cheaper turns | `/model`, `effortLevel`, `/model auto` |
| Isolate verbose work | `explore` / `task` subagents |
| Fewer tool tokens | `/mcp`, `tools` allowlist |
| Free actions | `!shell`, plan mode |
| Per-subagent routing | `subagents.agents.<name>` in `settings.json` |
