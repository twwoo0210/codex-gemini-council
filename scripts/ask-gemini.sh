#!/usr/bin/env bash
# ============================================================================
# ask-gemini.sh -- Non-interactive Gemini CLI wrapper for Claude Code agents
# ============================================================================
#
# Sends a prompt to Google Gemini CLI in headless pipe mode and returns
# the response to stdout. Designed to be called by ask-council.sh or directly
# from Claude Code agent subprocesses.
#
# Model: Gemini 3.1 Pro (Preview) by default
#
# Usage:
#   ask-gemini.sh "prompt" [timeout_seconds] [model]
#   ask-gemini.sh --prompt-file /path/to/file [timeout_seconds] [model]
#
# Arguments:
#   prompt or --prompt-file  - The question/instruction or path to prompt file (required)
#   timeout_seconds          - Max seconds to wait for response (default: 120)
#   model                    - Gemini model ID to use (default: gemini-3.1-pro-preview)
#
# Prerequisites:
#   - Gemini CLI installed and available in PATH
#     Install: npm install -g @google/gemini-cli  (official Google package)
#   - Valid Google authentication (OAuth)
#     Run `gemini auth` to configure
#
# Environment Variables:
#   GOOGLE_API_KEY   - (optional) Google API key, if not using OAuth
#   GEMINI_MODEL     - (optional) Override default model; CLI arg takes priority
#
# Exit Codes:
#   0 - Success, response printed to stdout
#   1 - gemini CLI not found in PATH
#   124 - Timeout exceeded (from `timeout` command)
#   * - Any other non-zero code from gemini CLI itself
#
# ============================================================================
set -euo pipefail

TMP_CREATED=0
if [ "${1:-}" = "--prompt-file" ]; then
  PROMPT_FILE="${2:?Usage: ask-gemini.sh --prompt-file <file> [timeout] [model]}"
  TIMEOUT="${3:-120}"
  MODEL="${4:-${GEMINI_MODEL:-gemini-3.1-pro-preview}}"
else
  PROMPT="${1:?Usage: ask-gemini.sh \"prompt\" [timeout_seconds] [model]}"
  TIMEOUT="${2:-120}"
  MODEL="${3:-${GEMINI_MODEL:-gemini-3.1-pro-preview}}"
  PROMPT_FILE=$(mktemp)
  TMP_CREATED=1
  printf '%s' "$PROMPT" > "$PROMPT_FILE"
fi

if ! command -v gemini &>/dev/null; then
  echo "ERROR: gemini CLI not found in PATH" >&2
  echo "Install the Gemini CLI and ensure it is on your PATH." >&2
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

TIMEOUT_CMD="timeout"
if ! command -v timeout &>/dev/null && command -v gtimeout &>/dev/null; then
  TIMEOUT_CMD="gtimeout"
elif ! command -v timeout &>/dev/null; then
  echo "ERROR: timeout command not found (install coreutils on macOS)" >&2
  exit 1
fi

ATTEMPT=0
EXIT_CODE=0
while true; do
  EXIT_CODE=0
  $TIMEOUT_CMD "${TIMEOUT}" gemini \
    --model "$MODEL" \
    < "$PROMPT_FILE" \
    2>"$TMPERR" || EXIT_CODE=$?

  if [ $EXIT_CODE -eq 0 ]; then
    break
  fi

  ATTEMPT=$((ATTEMPT + 1))
  if [ $ATTEMPT -ge $MAX_RETRIES ]; then
    break
  fi

  echo "WARN: Gemini attempt $ATTEMPT failed (exit $EXIT_CODE), retrying in ${RETRY_DELAY}s..." >&2
  sleep "$RETRY_DELAY"
done

if [ $EXIT_CODE -ne 0 ]; then
  echo "--- GEMINI ERROR (exit $EXIT_CODE) ---"
  cat "$TMPERR" >&2
  exit $EXIT_CODE
fi
