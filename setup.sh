#!/usr/bin/env bash
# setup.sh — Complete install for Smart Router + Global CLAUDE.md
#
# What this does:
#   1. Checks deps (curl, jq)
#   2. Creates ~/.smart-router/config.env with your OpenCode Go API key
#   3. Backs up OLD agents (smart-router, code-writer, code-reviewer, glm-executor) if present
#   4. Installs agents from claude/agents/ to ~/.claude/agents/
#      (advisor, fable-advisor, go-executor, reviewer) and retires opus-advisor.md
#   5. Installs slash commands from claude/commands/ to ~/.claude/commands/
#      (/go, /opus, /fable, /route, /spar)
#   6. Installs global CLAUDE.md from claude/CLAUDE.md to ~/.claude/
#   7. Installs go-caller.sh to ~/smart-router/
#   8. Tests API connectivity
#
# Usage:
#   bash setup.sh            # Interactive
#   bash setup.sh --force    # Overwrite existing CLAUDE.md without prompting

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_SRC="$SCRIPT_DIR/claude"
CONFIG_DIR="$HOME/.smart-router"
INSTALL_DIR="$HOME/smart-router"
CLAUDE_DIR="$HOME/.claude"
AGENTS_DIR="$CLAUDE_DIR/agents"
COMMANDS_DIR="$CLAUDE_DIR/commands"
FORCE=false

for arg in "$@"; do
  [[ "$arg" == "--force" || "$arg" == "-f" ]] && FORCE=true
done

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   Smart Router + Global Protocol — Install       ║"
echo "║   Claude Code (Sonnet/Opus) + OpenCode Go (18)   ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# ── Preflight ─────────────────────────────────────────────────
if [[ ! -d "$CLAUDE_SRC" ]]; then
  echo "❌  claude/ folder not found at $CLAUDE_SRC"
  echo "    Run this script from the repo root (the folder containing claude/, scripts/, setup.sh)."
  exit 1
fi

# ── Step 1: Dependencies ──────────────────────────────────────
echo "📦  Checking dependencies..."
MISSING=()
for cmd in curl jq; do
  command -v "$cmd" &>/dev/null || MISSING+=("$cmd")
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo "    Installing: ${MISSING[*]}"
  sudo apt-get update -qq && sudo apt-get install -y -qq "${MISSING[@]}"
fi
echo "    ✓ curl and jq ready"

# ── Step 2: Config directory + API key ────────────────────────
echo ""
echo "⚙️   Configuring API key..."
mkdir -p "$CONFIG_DIR"

if [[ ! -f "$CONFIG_DIR/config.env" ]]; then
  API_KEY=""
  if [[ -t 0 ]]; then
    echo "    Get your key from: https://opencode.ai/auth (Go tab)"
    read -rp "    Paste OpenCode Go API key: " API_KEY || API_KEY=""
  fi
  if [[ -z "$API_KEY" ]]; then
    echo 'OPENCODE_GO_API_KEY=' > "$CONFIG_DIR/config.env"
    chmod 600 "$CONFIG_DIR/config.env"
    echo "    ⚠️   No key provided — add it later: $CONFIG_DIR/config.env"
  else
    echo "OPENCODE_GO_API_KEY=$API_KEY" > "$CONFIG_DIR/config.env"
    chmod 600 "$CONFIG_DIR/config.env"
    echo "    ✓ Saved to $CONFIG_DIR/config.env"
  fi
else
  echo "    ✓ Existing config kept at $CONFIG_DIR/config.env"
fi

# ── Step 3: Back up OLD agents ────────────────────────────────
echo ""
echo "🧹  Backing up old agents (if any)..."
mkdir -p "$AGENTS_DIR"
for old in smart-router.md code-writer.md code-reviewer.md glm-executor.md; do
  if [[ -f "$AGENTS_DIR/$old" ]]; then
    mv "$AGENTS_DIR/$old" "$AGENTS_DIR/$old.bak"
    echo "    ✓ Backed up $old → $old.bak"
  fi
done

# ── Step 4: Install agents from claude/agents/ ────────────────
echo ""
echo "🤖  Installing agents..."
for agent in advisor.md fable-advisor.md go-executor.md reviewer.md; do
  if [[ -f "$CLAUDE_SRC/agents/$agent" ]]; then
    [[ -f "$AGENTS_DIR/$agent" ]] && cp "$AGENTS_DIR/$agent" "$AGENTS_DIR/$agent.bak"
    cp "$CLAUDE_SRC/agents/$agent" "$AGENTS_DIR/$agent"
    echo "    ✓ $agent"
  else
    echo "    ❌ $agent not found in $CLAUDE_SRC/agents (skipping)"
  fi
done

# Retire the old advisor so it stops being matched
if [[ -f "$AGENTS_DIR/opus-advisor.md" ]]; then
  mv "$AGENTS_DIR/opus-advisor.md" "$AGENTS_DIR/opus-advisor.md.retired"
  echo "    📦 Retired opus-advisor.md"
fi

# ── Step 5: Install slash commands from claude/commands/ ──────
echo ""
echo "⌨️   Installing slash commands..."
mkdir -p "$COMMANDS_DIR"
if [[ -d "$CLAUDE_SRC/commands" ]]; then
  for cmd in go.md opus.md fable.md route.md spar.md; do
    if [[ -f "$CLAUDE_SRC/commands/$cmd" ]]; then
      cp "$CLAUDE_SRC/commands/$cmd" "$COMMANDS_DIR/$cmd"
      echo "    ✓ /$(basename "$cmd" .md)"
    else
      echo "    ❌ $cmd not found in $CLAUDE_SRC/commands (skipping)"
    fi
  done
else
  echo "    ❌ commands/ folder not found in $CLAUDE_SRC (skipping)"
fi

# ── Step 6: Install global CLAUDE.md ──────────────────────────
echo ""
echo "🌐  Installing global CLAUDE.md..."
CLAUDE_MD_SRC="$CLAUDE_SRC/CLAUDE.md"
CLAUDE_MD_DST="$CLAUDE_DIR/CLAUDE.md"

if [[ ! -f "$CLAUDE_MD_SRC" ]]; then
  echo "    ❌ CLAUDE.md not found at $CLAUDE_MD_SRC — skipping"
else
  if [[ -f "$CLAUDE_MD_DST" && "$FORCE" == false && -t 0 ]]; then
    echo "    ⚠️   Existing CLAUDE.md found at $CLAUDE_MD_DST"
    read -rp "       Back it up and overwrite? [y/N]: " confirm || confirm="n"
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      cp "$CLAUDE_MD_DST" "$CLAUDE_MD_DST.bak"
      cp "$CLAUDE_MD_SRC" "$CLAUDE_MD_DST"
      echo "    ✓ Installed (backup at $CLAUDE_MD_DST.bak)"
    else
      echo "    ⊝ Kept existing CLAUDE.md"
    fi
  else
    [[ -f "$CLAUDE_MD_DST" ]] && cp "$CLAUDE_MD_DST" "$CLAUDE_MD_DST.bak"
    cp "$CLAUDE_MD_SRC" "$CLAUDE_MD_DST"
    echo "    ✓ Installed to $CLAUDE_MD_DST"
  fi
fi

# ── Step 7: Install go-caller.sh ──────────────────────────────
echo ""
echo "📞  Installing go-caller.sh..."
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/scripts/go-caller.sh" "$INSTALL_DIR/go-caller.sh"
chmod +x "$INSTALL_DIR/go-caller.sh"
echo "    ✓ Installed to $INSTALL_DIR/go-caller.sh"

# ── Step 8: API connectivity test ─────────────────────────────
echo ""
echo "🔌  Testing OpenCode Go API..."
source "$CONFIG_DIR/config.env" 2>/dev/null || true
if [[ -n "${OPENCODE_GO_API_KEY:-}" ]]; then
  HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null \
    "https://opencode.ai/zen/go/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${OPENCODE_GO_API_KEY}" \
    -d '{"model":"qwen3.6-plus","max_tokens":10,"messages":[{"role":"user","content":"ping"}]}' 2>/dev/null) || HTTP_CODE="000"

  case "$HTTP_CODE" in
    2*) echo "    ✓ API reachable (HTTP $HTTP_CODE)" ;;
    401|403) echo "    ❌ Invalid API key (HTTP $HTTP_CODE) — check https://opencode.ai/auth" ;;
    *) echo "    ⚠️   HTTP $HTTP_CODE — verify network and key" ;;
  esac
else
  echo "    ⊝ No key configured — skipping test"
fi

# ── Done ──────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   Install complete ✓                             ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  Files installed:"
echo "    Global protocol : $CLAUDE_MD_DST"
echo "    Agents          : $AGENTS_DIR/"
echo "                      ├── advisor.md         (Opus alias)"
echo "                      ├── fable-advisor.md   (Fable 5, METERED)"
echo "                      ├── go-executor.md     (18 Go models)"
echo "                      └── reviewer.md        (Sonnet)"
echo "    Slash commands  : $COMMANDS_DIR/"
echo "                      ├── go.md              (/go)"
echo "                      ├── opus.md            (/opus)"
echo "                      ├── fable.md           (/fable)"
echo "                      ├── route.md           (/route)"
echo "                      └── spar.md            (/spar)"
echo "    Go caller       : $INSTALL_DIR/go-caller.sh"
echo "    Config          : $CONFIG_DIR/config.env"
echo ""
echo "  Slash commands:"
echo "    /go <task>     — Send to Go model pool (18 models, zero Claude cost)"
echo "    /opus <q>      — Consult @advisor (Opus, plan limits)"
echo "    /fable <q>     — Consult @fable-advisor (METERED, requires y/n)"
echo "    /route <task>  — Force explicit routing"
echo "    /spar          — Activate Sparring Partner Mode"
echo ""
echo "  Verify in Claude Code:"
echo "    claude"
echo "    > /agents"
echo "    (should list: advisor, fable-advisor, go-executor, reviewer)"
echo ""
