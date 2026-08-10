# smart-router

A model-routing system for Claude Code that preserves your Claude usage limits
by delegating most work to the cheapest model that will do a good job. The
orchestrator (Sonnet) classifies every task and picks the right worker:

- **`self`** (Sonnet) — tasks where delegation overhead > the task itself
- **`@go-executor`** — dispatches across 18 OpenCode Go plan models (zero Claude cost)
- **`@advisor`** — Opus alias, advisory only, for hard architectural calls
- **`@fable-advisor`** — Fable 5, METERED usage credits, explicit `/fable` flag only
- **`@reviewer`** — post-execution quality gate (escalates for security-sensitive code)

Key design rule: `@go-executor` is NOT locked to one model. It selects from
all 18 per task and spreads load to preserve each model's rate limit.

## Repo layout

```
smart-router/
├── claude/
│   ├── CLAUDE.md              ← Global protocol (budget rule + routing + sparring + clarification)
│   ├── agents/
│   │   ├── advisor.md         ← Architecture / hard calls (Opus alias)
│   │   ├── fable-advisor.md   ← METERED escalation (Fable 5)
│   │   ├── go-executor.md     ← Dispatches across 18 Go models
│   │   └── reviewer.md        ← Post-execution quality gate
│   └── commands/              ← /go, /opus, /fable, /route, /spar
├── scripts/
│   └── go-caller.sh           ← OpenCode Go API caller (curl + jq)
├── docs/
│   └── architecture.md        ← How the four-layer flow works
├── models.json                ← Tracked Go model IDs + tiers (synced by CI)
├── setup.sh                   ← One-command installer
├── setup-global.sh            ← CLAUDE.md / agents / commands updater
└── .github/workflows/sync-opencode.yml  ← Weekly model-list drift check
```

Installed on your machine:

```
~/.claude/
├── CLAUDE.md                  ← Global protocol
├── agents/                    ← advisor, fable-advisor, go-executor, reviewer
└── commands/                  ← /go, /opus, /fable, /route, /spar

~/.smart-router/
└── config.env                 ← OPENCODE_GO_API_KEY (never committed)

~/smart-router/
└── go-caller.sh               ← Called by @go-executor
```

## Go model pool (inside `@go-executor`)

| Tier     | Models                                                     | Used for                                  |
|----------|------------------------------------------------------------|-------------------------------------------|
| Premium  | kimi-k3, deepseek-v4-pro, qwen3.8-max                      | Complex implementation, nuanced logic     |
| Balanced | kimi-k2.7-code, glm-5.2, minimax-m3, qwen3.7-max, grok-4.5 | Standard features, daily workhorse        |
| Standard | glm-5.1, qwen3.7-plus, minimax-m2.7, mimo-v2.5-pro         | Components, endpoints, routine features   |
| Fast     | qwen3.6-plus, kimi-k2.6, deepseek-v4-flash, mimo-v2.5      | Simple functions, small utilities         |
| Bulk     | gpt-5.6-luna, hy3*                                         | Scaffolding, boilerplate, types, fixtures |

`kimi-k2.7-code` is code-tuned — preferred for straight code generation.
\* `hy3` is an unverified model ID — the executor never dispatches to it until
confirmed in the OpenCode dashboard.

## Install

```bash
git clone https://github.com/bashartaamneh/smart-router.git
cd smart-router
bash setup.sh
```

See [INSTALL.md](INSTALL.md) for details, verification steps, and troubleshooting.

## Usage

### Automatic (default)

Just type normally in Claude Code. `CLAUDE.md` classifies the task and routes
it. Every routed call shows one transparency line:

```
→ Routing: @go-executor:kimi-k2.7-code — bulk type definitions
```

### Manual overrides

| Command                  | What it does |
|--------------------------|--------------|
| `/go <task>`             | Auto-pick best Go model |
| `/go @<model-id> <task>` | Force a specific model (e.g. `@kimi-k3`, `@glm-5.2`, `@deepseek-v4-pro`) |
| `/go @<family> <task>`   | Force a family, executor picks variant (`@kimi`, `@qwen`, `@deepseek`, `@glm`, `@minimax`, `@mimo`) |
| `/opus <q>`              | Consult `@advisor` (Opus, plan limits), advisory only |
| `/fable <q>`             | Consult `@fable-advisor` — **METERED**, requires cost confirmation |
| `/route <task>`          | Force explicit routing decision, wait for approval |
| `/spar`                  | Sparring Partner Mode — challenges assumptions |

### The four-layer flow

1. **Clarification** — Sonnet self-assesses at 95% confidence. If unclear, asks max 3 targeted questions.
2. **Routing** — picks `self`, `@go-executor`, `@advisor`, or (explicit flag only) `@fable-advisor`.
3. **Execution** — the delegate does its job. For Go, Sonnet applies the returned files immediately.
4. **Review** — `@reviewer` gates prod / security / user-facing output, escalating automatically for auth, payments, or regulated-data code.

### The budget rule

`claude-fable-5` is the only metered model. It is never auto-routed: the
orchestrator requires an explicit `/fable` or `--fable` flag plus a y/n cost
confirmation, and on any failure it falls back to `@advisor` and continues.
Credit exhaustion is treated as the expected steady state, not an error.

## Model list sync

`models.json` tracks the 18 Go model IDs and their tiers. The
[sync-opencode workflow](.github/workflows/sync-opencode.yml) checks the
OpenCode API weekly and opens a PR when the list drifts. It needs the
`OPENCODE_GO_API_KEY` repo secret and PR-creation permission for Actions —
see [INSTALL.md](INSTALL.md#ci-model-list-sync-optional).

## Updating

```bash
cd smart-router && git pull
bash setup-global.sh --force   # updates CLAUDE.md, agents, and commands only
```

## License

[MIT](LICENSE)
