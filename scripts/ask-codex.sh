#!/usr/bin/env bash
# ============================================================================
# ask-codex.sh -- Non-interactive Codex CLI wrapper for Claude Code agents
# ============================================================================
#
# Sends a prompt to OpenAI Codex CLI in non-interactive (exec) mode and
# returns the response to stdout. Designed to be called by ask-council.sh
# or directly from Claude Code agent subprocesses.
#
# Model: GPT-5.3-Codex (xhigh reasoning) by default
#
# Usage:
#   ask-codex.sh "prompt" [timeout_seconds] [model]
#   ask-codex.sh --prompt-file /path/to/file [timeout_seconds] [model]
#
# Arguments:
#   prompt or --prompt-file  - The question/instruction or path to prompt file (required)
#   timeout_seconds          - Max seconds to wait for response (default: 120)
#   model                    - Codex model ID to use (default: gpt-5.3-codex)
#
# Prerequisites:
#   - Codex CLI installed and available in PATH
#     Install: npm install -g @openai/codex
#   - Valid OpenAI authentication (OAuth or API key)
#     Run `codex auth` to configure
#
# Environment Variables:
#   OPENAI_API_KEY   - (optional) OpenAI API key, if not using OAuth
#   CODEX_MODEL      - (optional) Override default model; CLI arg takes priority
#
# Exit Codes:
#   0 - Success, response printed to stdout
#   1 - codex CLI not found in PATH
#   124 - Timeout exceeded (from `timeout` command)
#   * - Any other non-zero code from codex CLI itself
#
# ============================================================================
set -euo pipefail

TMP_CREATED=0
if [ "${1:-}" = "--prompt-file" ]; then
  PROMPT_FILE="${2:?Usage: ask-codex.sh --prompt-file <file> [timeout] [model]}"
  TIMEOUT="${3:-120}"
  MODEL="${4:-${CODEX_MODEL:-gpt-5.3-codex}}"
else
  PROMPT="${1:?Usage: ask-codex.sh \"prompt\" [timeout_seconds] [model]}"
  TIMEOUT="${2:-120}"
  MODEL="${3:-${CODEX_MODEL:-gpt-5.3-codex}}"
  PROMPT_FILE=$(mktemp)
  TMP_CREATED=1
  printf '%s' "$PROMPT" > "$PROMPT_FILE"
fi

if ! command -v codex &>/dev/null; then
  echo "ERROR: codex CLI not found in PATH" >&2
  echo "Install with: npm install -g @openai/codex" >&2
  [ $TMP_CREATED -eq 1 ] && rm -f "$PROMPT_FILE"
  exit 1
fi

TMPERR=$(mktemp)
if [ $TMP_CREATED -eq 1 ]; then
  trap 'rm -f "$TMPERR" "$PROMPT_FILE"' EXIT
else
  trap 'rm -f "$TMPERR"' EXIT
fi

MAX_RETRIES="${MAX_RETRIES:-1}"
RETRY_DELAY="${RETRY_DELAY:-5}"

ATTEMPT=0
EXIT_CODE=0
while true; do
  EXIT_CODE=0
  timeout "${TIMEOUT}" codex exec - \
    --model "$MODEL" \
    --skip-git-repo-check \
    --ephemeral \
    < "$PROMPT_FILE" \
    2>"$TMPERR" || EXIT_CODE=$?

  if [ $EXIT_CODE -eq 0 ]; then
    break
  fi

  ATTEMPT=$((ATTEMPT + 1))
  if [ $ATTEMPT -ge $MAX_RETRIES ]; then
    break
  fi

  echo "WARN: Codex attempt $ATTEMPT failed (exit $EXIT_CODE), retrying in ${RETRY_DELAY}s..." >&2
  sleep "$RETRY_DELAY"
done

if [ $EXIT_CODE -ne 0 ]; then
  echo "--- CODEX ERROR (exit $EXIT_CODE) ---"
  cat "$TMPERR" >&2
  exit $EXIT_CODE
fi
