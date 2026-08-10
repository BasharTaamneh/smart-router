# Architecture

## The problem

Claude plans meter your heaviest models. Most day-to-day coding work — bulk
code, boilerplate, tests, refactors, docs — doesn't need them. smart-router
makes the orchestrator (Sonnet) treat its own usage as a scarce resource and
route everything else to cheaper workers.

## Workers

| Worker           | Model                  | Cost               |
|------------------|------------------------|--------------------|
| `self`           | Sonnet                 | Plan limits        |
| `@go-executor`   | 18 OpenCode Go models  | Zero Claude cost   |
| `@advisor`       | Opus (alias)           | Plan limits        |
| `@fable-advisor` | claude-fable-5         | METERED credits    |
| `@reviewer`      | Sonnet (Opus escalation) | Plan limits      |

`model: opus` and `model: sonnet` in agent frontmatter are aliases that resolve
to the current generation — no pinned version numbers.

## The four-layer flow

```
user message
     │
     ▼
1. CLARIFICATION  — <95% confidence → ask up to 3 questions, wait
     │
     ▼
2. ROUTING        — decision tree: trivial→self, architectural→@advisor,
     │              bulk mechanical→@go-executor, /fable→gate+confirm
     ▼
3. EXECUTION      — Go executor returns code; Sonnet writes files immediately.
     │              Advisor returns a consumable spec; Sonnet routes the
     │              implementation as if it arrived fresh (no post-analysis
     │              momentum).
     ▼
4. REVIEW         — @reviewer gates prod/security/user-facing output;
                    auto-escalates auth/payments/regulated-data reviews.
```

## Why the executor never writes files itself

`@go-executor` returns code in a structured format and the orchestrator applies
it with its own Edit/Write tools. This keeps Claude in the loop for safety and
avoids headless-write issues, while still writing immediately — the user is
never asked "do you want me to save this?".

## Load spreading

Each Go model has its own rate-limit window. The executor:

- never defaults to a single model,
- prefers the model it used least recently when quality is comparable,
- moves sideways within a tier on rate limit before moving up,
- announces tier exhaustion explicitly instead of silently escalating.

## The metered tier

`@fable-advisor` (Fable 5) is the only worker that consumes usage credits. It
sits behind a four-condition gate (explicit user flag, long-horizon problem,
Opus already tried, expensive-to-reverse decision) plus a y/n cost
confirmation. Every failure path falls back to `@advisor` and continues —
never halting, never prompting to buy credits.

## go-caller.sh

A thin curl+jq wrapper over the OpenCode Go API
(`https://opencode.ai/zen/go/v1`). OpenAI-compatible chat completions for most
models; Anthropic-compatible messages endpoint for MiniMax models. The API key
lives in `~/.smart-router/config.env` (chmod 600, gitignored) and is the only
piece of state outside the repo.
