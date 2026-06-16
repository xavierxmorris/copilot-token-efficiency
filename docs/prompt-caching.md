# Deep dive: input-token / prompt caching (and how to max it)

**The single most important fact for quality:** prompt caching **does not change the
model's output at all** — it only makes the *input* cheaper and faster. Both providers
state this explicitly:

> "Prompt Caching does not influence the generation of output tokens or the final
> response… the output generated will be identical. Only the prompt itself is cached,
> while the actual response is computed anew each time." — OpenAI

> "The cache is refreshed for no additional cost each time the cached content is used."
> — Anthropic

So **maximizing cache hits is the #1 zero-quality-loss efficiency lever.** You pay less
for the exact same answer.

> Sources (fetched 2026‑06‑16):
> - Anthropic — https://platform.claude.com/docs/en/build-with-claude/prompt-caching
> - OpenAI — https://developers.openai.com/api/docs/guides/prompt-caching

---

## How it works (both providers)

A request's **prefix** is hashed and matched against recently-processed prefixes.
On a **cache hit**, the matched prefix is billed at the cheap cache-read rate; on a
**miss**, the full prompt is processed and the prefix is written to cache for next time.

Caching only matches an **exact prefix**. The prefix is assembled in this order:

```
tools  →  system  →  messages
```

(Anthropic states this order explicitly; OpenAI requires tools/images to be identical.)
**Anything you change earlier in that chain invalidates everything after it.** That is
the key to understanding what helps and what hurts.

## Savings & pricing

### Anthropic (Claude) — cache read = 0.1× base input (≈90% off)

| Model | Base input | 5‑min cache **write** (1.25×) | 1‑hr cache **write** (2×) | Cache **hit/read** (0.1×) | Output |
|---|---|---|---|---|---|
| Claude Opus 4.8 | $5 / MTok | $6.25 | $10 | **$0.50** | $25 |
| Claude Sonnet 4.6 | $3 / MTok | $3.75 | $6 | **$0.30** | $15 |
| Claude Haiku 4.5 | $1 / MTok | $1.25 | $2 | **$0.10** | $5 |

- **Cache read is 90% cheaper than fresh input.** A cache *write* costs 25% extra (5‑min)
  — so caching pays off as soon as a prefix is reused **≥ ~2–3 times**.
- **Minimum cacheable prefix:** ~1024 tokens (2048 for Haiku).

### OpenAI (GPT) — automatic, no extra fee

- Automatic on all requests ≥ **1024 tokens**, cached in 128‑token increments. No code, no write surcharge.
- Up to **~90% input cost** and **~80% latency** reduction on cached prefixes.
- `prompt_cache_key` improves routing; keep each unique prefix+key under ~15 req/min to avoid overflow.

## Cache lifetime (TTL / retention)

| Provider | Default lifetime | Extended option |
|---|---|---|
| Anthropic | **5 min** (refreshed free on every hit) | **1 hour** at 2× write price (`ttl: "1h"`) |
| OpenAI (in‑memory) | **5–10 min** idle, max 1 hr | — |
| OpenAI **Extended** (GPT‑5.5, 5.4, 5.x, 4.1) | up to **24 hours** | GPT‑5.5 supports **only** 24h extended |

**Implication:** a cache goes cold after a few idle minutes. Work in **bursts** to stay
within the window; a long coffee break means the next turn pays full price again
(except GPT‑5.5's 24h retention).

---

## What BUSTS the cache (avoid these mid-session)

Because the cached prefix is `tools → system → messages`, in the Copilot CLI the
following **invalidate your whole cached prefix** and force a full re-bill next turn:

| Action | Why it busts cache |
|---|---|
| Switching **model** or **effort level** mid-session | Changes the request fingerprint/system layer |
| Adding/removing an **MCP server** or toggling **tools** (`/mcp`) | Tool defs are the **first** cache layer — changing them invalidates everything after |
| Editing **custom instructions** mid-session | Part of the `system` layer |
| **`/rewind`**, **`/undo`**, editing an earlier turn | Rewrites history before the cache point |
| **`/compact`** | Rewrites the whole transcript → new prefix (reclaims tokens, but cold cache) |
| Long idle gap (> ~5–10 min) | TTL expiry evicts the prefix |

## How to MAXIMIZE cache hits (Copilot CLI checklist)

1. **Lock your config before you start.** Pick model, effort, contextTier, MCP servers,
   and tools up front — and don't change them mid-session. Each change is a cold cache.
2. **Front-load stable context, keep it.** Add big reference files/specs early with `@file`
   and reuse across turns — the large prefix is then read from cache at ~10% cost.
3. **Append, don't edit.** Ask follow-ups as new turns. Avoid `/rewind`/`/undo` unless needed.
4. **Keep the session warm.** Work in focused bursts; don't leave it idle past the TTL.
   On GPT‑5.5, the 24h extended retention makes cache survive long gaps.
5. **Defer `/compact`.** It busts the cache, so only compact when history is genuinely
   stale (see the quality tradeoff in the main guide).
6. **Stable, concise instructions.** A short `copilot-instructions.md` that you don't edit
   mid-session stays cached and steers every turn.
7. **Verify it's working.** Run `/context` and `/usage` to watch cached vs fresh input
   tokens (the API exposes `cached_tokens` in usage). Rising cache-hit share = you're winning.

## The one tradeoff to know

A cache **write** costs slightly more than a fresh read (Anthropic 1.25×; OpenAI free).
So caching is a net win whenever a prefix is reused — which is almost always in an
interactive session. The only time it doesn't pay is a single one-shot prompt you never
build on. For everyday CLI work, **keep the prefix stable and let the cache do the work.**
