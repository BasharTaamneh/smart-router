# Installing smart-router

## Prerequisites

- Claude Code (WSL2/Linux/macOS) with an active plan
- An OpenCode Go plan API key — https://opencode.ai/auth (Go tab)
- `curl` and `jq` (the installer installs them on Debian/Ubuntu if missing)

## Full install

```bash
git clone https://github.com/bashartaamneh/smart-router.git
cd smart-router
bash setup.sh
```

`setup.sh` does the following:

1. Checks/install deps (`curl`, `jq`)
2. Prompts for your OpenCode Go API key → saves to `~/.smart-router/config.env` (chmod 600)
3. Backs up old agents (`smart-router.md`, `code-writer.md`, `code-reviewer.md`, `glm-executor.md`) to `.bak`
4. Installs agents from `claude/agents/` → `~/.claude/agents/`:
   `advisor.md`, `fable-advisor.md`, `go-executor.md`, `reviewer.md` — and retires any `opus-advisor.md`
5. Installs slash commands from `claude/commands/` → `~/.claude/commands/`:
   `/go`, `/opus`, `/fable`, `/route`, `/spar`
6. Installs the global protocol `claude/CLAUDE.md` → `~/.claude/CLAUDE.md` (backs up any existing one)
7. Installs `scripts/go-caller.sh` → `~/smart-router/go-caller.sh`
8. Tests OpenCode API connectivity

Flags: `bash setup.sh --force` skips overwrite prompts. Running non-interactively
(no TTY) skips all prompts and keeps existing files backed up.

## Protocol-only update

To update `CLAUDE.md`, agents, and commands without touching your API key
config or `go-caller.sh`:

```bash
bash setup-global.sh          # or --force to skip the prompt
```

## Verify

```bash
claude
> /agents
```

Should list: `advisor`, `fable-advisor`, `go-executor`, `reviewer`.

Test the routing:

```
> hi
# → Sonnet handles directly (greeting)

> scaffold a Next.js API route for user registration
# → Routes to @go-executor → executor picks a Go model → Sonnet applies files

> should we use JWT or session cookies for the auth system?
# → Routes to @advisor → returns recommendation → waits for your call

> /go @qwen generate 20 TypeScript interfaces from this schema
# → Forces Qwen family → executor picks the right variant → Sonnet applies files

> /fable <a genuinely long-horizon problem>
# → Four-condition gate → cost estimate → waits for explicit y

> /spar my plan to migrate from REST to GraphQL incrementally
# → Sparring Partner Mode → challenges assumptions
```

## The 18-model Go pool

| Tier     | Models                                                     |
|----------|------------------------------------------------------------|
| Premium  | kimi-k3, deepseek-v4-pro, qwen3.8-max                      |
| Balanced | kimi-k2.7-code, glm-5.2, minimax-m3, qwen3.7-max, grok-4.5 |
| Standard | glm-5.1, qwen3.7-plus, minimax-m2.7, mimo-v2.5-pro         |
| Fast     | qwen3.6-plus, kimi-k2.6, deepseek-v4-flash, mimo-v2.5      |
| Bulk     | gpt-5.6-luna, hy3 (unverified — never dispatched)          |

Valid model IDs for `/go @<model>`: `kimi-k3`, `kimi-k2.7-code`, `kimi-k2.6`,
`qwen3.8-max`, `qwen3.7-max`, `qwen3.7-plus`, `qwen3.6-plus`, `deepseek-v4-pro`,
`deepseek-v4-flash`, `glm-5.2`, `glm-5.1`, `minimax-m3`, `minimax-m2.7`,
`mimo-v2.5-pro`, `mimo-v2.5`, `grok-4.5`, `gpt-5.6-luna`, `hy3` (unverified).

Rate limits per model are intentionally `TBD` in `claude/agents/go-executor.md` —
fill them in from your OpenCode dashboard; the load-spreading rule depends on
real numbers, not guesses.

## Updating your API key

```bash
nano ~/.smart-router/config.env
# Change: OPENCODE_GO_API_KEY=new_key
```

`config.env` is gitignored and must never be committed.

## CI model-list sync (optional)

The [sync-opencode workflow](.github/workflows/sync-opencode.yml) checks the
OpenCode API weekly and opens a PR when `models.json` drifts from the live
model list. After forking/cloning to your own GitHub account
(`https://github.com/bashartaamneh/smart-router`), enable it with two
one-time settings:

1. **Repo secret** — Settings → Secrets and variables → Actions → New repository
   secret: name `OPENCODE_GO_API_KEY`, value = your OpenCode Go key.
2. **PR permission** — Settings → Actions → General → Workflow permissions:
   select "Read and write permissions" and check
   "Allow GitHub Actions to create and approve pull requests".

## Troubleshooting

**Agents not showing in `/agents`**
```bash
ls ~/.claude/agents/
# Expect: advisor.md  fable-advisor.md  go-executor.md  reviewer.md
# If missing: re-run bash setup.sh
```

**API returns 401 / 403**
Invalid or expired key. Grab a new one at https://opencode.ai/auth.

**CLAUDE.md not being picked up**
Claude Code reads `~/.claude/CLAUDE.md` at session start. Start a fresh session
after install.

**Old agents still appearing**
The installer backs them up to `.bak` / `.retired` but doesn't delete. To fully
remove:
```bash
rm ~/.claude/agents/*.bak ~/.claude/agents/*.retired
```

**Executor always picking the same model**
Open `~/.claude/agents/go-executor.md` and confirm the "Load-Spreading Rule"
section is present. If you're seeing repeated use of one model, add an explicit
`@<other-model>` override for the next few calls to rebalance.
