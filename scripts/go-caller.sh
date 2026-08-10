#!/bin/bash
# go-caller.sh — Calls OpenCode Go models via API
# Usage: bash go-caller.sh "<model_id>" "<prompt>" [--file <path>]
#
# Supported models and their endpoints:
#   OpenAI-compatible: glm-5.1, glm-5, kimi-k2.5, kimi-k2.6,
#                      mimo-v2-pro, mimo-v2-omni, mimo-v2.5-pro, mimo-v2.5,
#                      qwen3.5-plus, qwen3.6-plus
#   Anthropic-compatible: minimax-m2.5, minimax-m2.7

set -euo pipefail

# ─── Config ──────────────────────────────────────────────────
CONFIG_FILE="$HOME/.smart-router/config.env"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Config not found: $CONFIG_FILE"
    echo "   Run: bash ~/smart-router/setup.sh"
    exit 1
fi

source "$CONFIG_FILE"

if [[ -z "${OPENCODE_GO_API_KEY:-}" ]]; then
    echo "❌ OPENCODE_GO_API_KEY not set in $CONFIG_FILE"
    exit 1
fi

# ─── Args ────────────────────────────────────────────────────
MODEL_ID="${1:?Usage: go-caller.sh <model_id> <prompt> [--file <path>]}"
PROMPT="${2:?Usage: go-caller.sh <model_id> <prompt> [--file <path>]}"
FILE_PATH=""

# Parse optional --file flag
shift 2
while [[ $# -gt 0 ]]; do
    case "$1" in
        --file)
            FILE_PATH="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# If a file is provided, prepend its content to the prompt
if [[ -n "$FILE_PATH" && -f "$FILE_PATH" ]]; then
    FILE_CONTENT=$(cat "$FILE_PATH")
    PROMPT="Here is the relevant code/file content:

\`\`\`
$FILE_CONTENT
\`\`\`

Task: $PROMPT"
fi

# ─── Endpoint Selection ─────────────────────────────────────
BASE_URL="https://opencode.ai/zen/go/v1"

# MiniMax models use Anthropic-compatible endpoint
ANTHROPIC_MODELS=("minimax-m2.5" "minimax-m2.7")

IS_ANTHROPIC=false
for m in "${ANTHROPIC_MODELS[@]}"; do
    if [[ "$MODEL_ID" == "$m" ]]; then
        IS_ANTHROPIC=true
        break
    fi
done

# ─── System Prompt ───────────────────────────────────────────
SYSTEM_PROMPT="You are an expert coding assistant. Write clean, complete, production-ready code. Include all imports and dependencies. Use proper error handling. Never truncate code with '...' or placeholders. Be direct — no filler phrases or apologies."

# ─── API Call ────────────────────────────────────────────────
TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT

if [[ "$IS_ANTHROPIC" == true ]]; then
    # Anthropic-compatible call (MiniMax models)
    HTTP_CODE=$(curl -s -w "%{http_code}" -o "$TMPFILE" \
        "${BASE_URL}/messages" \
        -H "Content-Type: application/json" \
        -H "x-api-key: ${OPENCODE_GO_API_KEY}" \
        -H "anthropic-version: 2023-06-01" \
        -d "$(jq -n \
            --arg model "$MODEL_ID" \
            --arg system "$SYSTEM_PROMPT" \
            --arg prompt "$PROMPT" \
            '{
                model: $model,
                max_tokens: 8192,
                system: $system,
                messages: [{role: "user", content: $prompt}]
            }'
        )" 2>/dev/null)

    if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
        # Extract text from Anthropic response format
        jq -r '.content[]? | select(.type == "text") | .text // empty' "$TMPFILE" 2>/dev/null || cat "$TMPFILE"
    else
        echo "❌ API Error (HTTP $HTTP_CODE) from $MODEL_ID:"
        cat "$TMPFILE"
        exit 1
    fi

else
    # OpenAI-compatible call (all other models)
    HTTP_CODE=$(curl -s -w "%{http_code}" -o "$TMPFILE" \
        "${BASE_URL}/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${OPENCODE_GO_API_KEY}" \
        -d "$(jq -n \
            --arg model "$MODEL_ID" \
            --arg system "$SYSTEM_PROMPT" \
            --arg prompt "$PROMPT" \
            '{
                model: $model,
                max_tokens: 8192,
                messages: [
                    {role: "system", content: $system},
                    {role: "user", content: $prompt}
                ]
            }'
        )" 2>/dev/null)

    if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
        # Extract text from OpenAI response format
        jq -r '.choices[0].message.content // empty' "$TMPFILE" 2>/dev/null || cat "$TMPFILE"
    else
        echo "❌ API Error (HTTP $HTTP_CODE) from $MODEL_ID:"
        cat "$TMPFILE"
        exit 1
    fi
fi
