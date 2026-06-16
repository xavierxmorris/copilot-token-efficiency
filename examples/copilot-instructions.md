# Context-discipline instructions (token-saving)

Drop this in `~/.copilot/copilot-instructions.md` (global) or a repo's
`.github/copilot-instructions.md`. Concise, durable instructions reduce repeated
back-and-forth and keep the model from re-deriving the same context every turn.

## Output discipline
- Be concise. Prefer the shortest correct answer. No filler, no recap, no process narration.
- For code changes, show only the diff or the changed block — not whole files.
- Use structured output (tables, bullets) over prose when listing.

## Context discipline
- Read only the files needed for the task. Use `@path/to/file` to scope context instead of dumping directories.
- For codebase questions, prefer the `explore` subagent (cheap, separate context) over loading files into the main thread.
- Run verbose commands (tests, builds, installs) via the `task` subagent so only the summary returns to the main context.
- Batch independent tool calls in one turn rather than serial round-trips.

## Model discipline
- Use a lean default model/effort for routine work; reserve max-effort Opus / xhigh GPT-5.5 for genuinely hard tasks.
- Don't restate large stable context mid-session — it breaks prompt caching. Keep stable context up front, put the changing ask last.

## Housekeeping
- At natural milestones, suggest `/compact` to summarise history and reclaim context tokens.
- Between unrelated tasks, start `/new` rather than carrying a bloated transcript.
