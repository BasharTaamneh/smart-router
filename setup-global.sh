#!/usr/bin/env bash
# setup-global.sh — Install/update ONLY the global CLAUDE.md, agents, and commands.
# Does not touch config.env or go-caller.sh. Use setup.sh for a full install.
#
# Usage:
#   bash setup-global.sh           # Install fresh
#   bash setup-global.sh --force   # Overwrite existing without prompting

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_SRC="$SCRIPT_DIR/claude"
SOURCE="$CLAUDE_SRC/CLAUDE.md"
TARGET_DIR="$HOME/.claude"
TARGET="$TARGET_DIR/CLAUDE.md"
BACKUP="$TARGET_DIR/CLAUDE.md.bak"
FORCE=false

# ── Parse args ────────────────────────────────────────────────────────────────
for arg in "$@"; do
  case $arg in
    --force|-f) FORCE=true ;;
    --help|-h)
      echo "Usage: bash setup-global.sh [--force]"
      echo "  --force  Overwrite existing CLAUDE.md without prompting"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg"
      exit 1
      ;;
  esac
done

# ── Preflight ─────────────────────────────────────────────────────────────────
if [[ ! -f "$SOURCE" ]]; then
  echo "❌  CLAUDE.md not found at: $SOURCE"
  echo "    Run this script from the repo root (the folder containing claude/)."
  exit 1
fi

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   Global CLAUDE.md Setup                 ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Create ~/.claude/ if needed ───────────────────────────────────────────────
if [[ ! -d "$TARGET_DIR" ]]; then
  echo "📁  Creating $TARGET_DIR ..."
  mkdir -p "$TARGET_DIR"
fi

# ── Backup existing file ──────────────────────────────────────────────────────
if [[ -f "$TARGET" ]]; then
  if [[ "$FORCE" == false && -t 0 ]]; then
    echo "⚠️   An existing CLAUDE.md was found at: $TARGET"
    read -rp "    Back it up and overwrite? [y/N]: " confirm || confirm="n"
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "Aborted. No changes made."
      exit 0
    fi
  fi
  cp "$TARGET" "$BACKUP"
  echo "💾  Backed up existing file to: $BACKUP"
fi

# ── Install CLAUDE.md ─────────────────────────────────────────────────────────
cp "$SOURCE" "$TARGET"
echo "✅  Installed: $TARGET"

# ── Install agents ────────────────────────────────────────────────────────────
mkdir -p "$TARGET_DIR/agents"
for a in advisor.md fable-advisor.md go-executor.md reviewer.md; do
  if [[ -f "$CLAUDE_SRC/agents/$a" ]]; then
    [[ -f "$TARGET_DIR/agents/$a" ]] && cp "$TARGET_DIR/agents/$a" "$TARGET_DIR/agents/$a.bak"
    cp "$CLAUDE_SRC/agents/$a" "$TARGET_DIR/agents/$a"
    echo "✅  Installed agent: $a"
  fi
done

# Retire the old advisor so it stops being matched
if [[ -f "$TARGET_DIR/agents/opus-advisor.md" ]]; then
  mv "$TARGET_DIR/agents/opus-advisor.md" "$TARGET_DIR/agents/opus-advisor.md.retired"
  echo "📦  Retired opus-advisor.md"
fi

# ── Install commands ──────────────────────────────────────────────────────────
mkdir -p "$TARGET_DIR/commands"
if [[ -d "$CLAUDE_SRC/commands" ]]; then
  cp "$CLAUDE_SRC"/commands/*.md "$TARGET_DIR/commands/"
  echo "✅  Installed commands"
fi

# ── Verify ────────────────────────────────────────────────────────────────────
if [[ -f "$TARGET" ]]; then
  LINE_COUNT=$(wc -l < "$TARGET")
  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║   Install complete ✓                     ║"
  echo "╚══════════════════════════════════════════╝"
  echo ""
  echo "  Location : $TARGET"
  echo "  Lines    : $LINE_COUNT"
  echo "  Scope    : All projects (global)"
  echo ""
  echo "  Protocols active:"
  echo "    ✓ Budget Rule (Fable metered, never auto-routed)"
  echo "    ✓ Clarification (95% confidence check)"
  echo "    ✓ Sparring Partner Mode (opt-in)"
  echo "    ✓ Routing Protocol (Go pool / advisor / self)"
  echo ""
  echo "  Slash commands available:"
  echo "    /go <task>     — Send to Go model pool (18 models, zero Claude cost)"
  echo "    /opus <q>      — Consult @advisor (Opus, plan limits)"
  echo "    /fable <q>     — Consult @fable-advisor (METERED, requires y/n)"
  echo "    /route <task>  — Force explicit routing"
  echo "    /spar          — Activate Sparring Partner Mode"
  echo ""
  echo "  Note: Project-level CLAUDE.md files extend this config."
  echo "  They do NOT override it — both are loaded."
  echo ""
else
  echo "❌  Install failed — file not found after copy."
  exit 1
fi
