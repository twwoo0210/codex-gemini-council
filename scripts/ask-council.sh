#!/usr/bin/env bash
# ============================================================================
# ask-council.sh -- Ask Codex (GPT-5.3) and Gemini (3.1 Pro)
#                   the same question in parallel (Dual LLM Council)
# ============================================================================
#
# Both models run as independent sessions; the calling session acts as
# pure synthesizer.
#
# Supports two council modes via COUNCIL_MODE:
#   - "fast"  : Pass the question as-is to each model (original behavior)
#   - "team"  : Wrap the question in a 4-phase team deliberation prompt
#               (Research -> Analysis -> Critique -> Team Conclusion)
#               using the council-team-prompt.txt template
#
# Usage:
#   ask-council.sh "prompt" [timeout_seconds]
#   COUNCIL_MODE=fast ask-council.sh "prompt" [timeout_seconds]
#
# Arguments:
#   prompt           - The question or instruction to send (required)
#   timeout_seconds  - Max seconds to wait per model (default: 180)
#
# Prerequisites:
#   - ask-codex.sh and ask-gemini.sh in the same directory
#   - `codex` and `gemini` CLIs installed and authenticated
#   - See individual script headers for detailed prerequisites
#   - council-team-prompt.txt in the same directory (for team mode)
#
# Environment Variables:
#   COUNCIL_MODE     - (optional) "team" (default) or "fast"
#   COUNCIL_ROLE_MODE- (optional) "symmetric" (default) or "specialized"
#   COUNCIL_LOG      - (optional) Path to CSV metrics log file
#   CONTEXT_FILES    - (optional) Colon-separated file paths for context injection
#   COUNCIL_STDIN    - (optional) Set to "1" to pass prompts via --prompt-file
#                      instead of CLI arguments (avoids ARG_MAX / special char issues)
#   CODEX_MODEL      - (optional) Override Codex model (default: gpt-5.3-codex)
#   GEMINI_MODEL     - (optional) Override Gemini model (default: gemini-3.1-pro-preview)
#
# ============================================================================
set -euo pipefail

PROMPT="${1:?Usage: ask-council.sh \"prompt\" [timeout_seconds]}"
COUNCIL_MODE="${COUNCIL_MODE:-team}"

if [ -n "${2:-}" ]; then
  TIMEOUT="$2"
elif [ "$COUNCIL_MODE" = "team" ]; then
  TIMEOUT=240
else
  TIMEOUT=120
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -n "${CONTEXT_FILES:-}" ]; then
  CONTEXT_BLOCK=""
  IFS=':' read -ra CTX_PATHS <<< "$CONTEXT_FILES"
  for CTX_PATH in "${CTX_PATHS[@]}"; do
    if [[ "$CTX_PATH" == *".."* ]]; then
      echo "WARN: Rejecting context file with path traversal: $CTX_PATH" >&2
      continue
    fi
    if [ -f "$CTX_PATH" ]; then
      CONTEXT_BLOCK="${CONTEXT_BLOCK}
--- FILE: ${CTX_PATH} ---
$(<"$CTX_PATH")
--- END FILE ---
"
    else
      echo "WARN: Context file not found: $CTX_PATH" >&2
    fi
  done
  if [ -n "$CONTEXT_BLOCK" ]; then
    PROMPT="${PROMPT}

=== CONTEXT FILES ===
${CONTEXT_BLOCK}"
  fi
fi

if [ "$COUNCIL_MODE" = "team" ]; then
  TEMPLATE_FILE="$SCRIPT_DIR/council-team-prompt.txt"
  if [ -f "$TEMPLATE_FILE" ]; then
    PROMPT=$(python3 -c "
import sys
template = open(sys.argv[1], 'r').read()
question = sys.stdin.read()
print(template.replace('{QUESTION}', question), end='')
" "$TEMPLATE_FILE" <<< "$PROMPT")
  else
    echo "WARNING: Team prompt template not found at $TEMPLATE_FILE, falling back to fast mode" >&2
  fi
fi

TMPDIR_COUNCIL=$(mktemp -d)
trap 'rm -rf "$TMPDIR_COUNCIL"' EXIT

COUNCIL_LOG="${COUNCIL_LOG:-}"
TS_START=$(date +%s)

COUNCIL_ROLE_MODE="${COUNCIL_ROLE_MODE:-symmetric}"
PROMPT_CODEX="$PROMPT"
PROMPT_GEMINI="$PROMPT"

if [ "$COUNCIL_ROLE_MODE" = "specialized" ]; then
  ROLE_DIR="$SCRIPT_DIR/council-role-prompts"
  if [ -d "$ROLE_DIR" ]; then
    for ROLE_FILE in codex-role.txt gemini-role.txt; do
      if [ ! -f "$ROLE_DIR/$ROLE_FILE" ]; then
        echo "WARN: Role file $ROLE_DIR/$ROLE_FILE not found, using symmetric prompt" >&2
        COUNCIL_ROLE_MODE="symmetric"
        break
      fi
    done
  else
    echo "WARN: Role prompts directory $ROLE_DIR not found, using symmetric prompt" >&2
    COUNCIL_ROLE_MODE="symmetric"
  fi

  if [ "$COUNCIL_ROLE_MODE" = "specialized" ]; then
    PROMPT_CODEX=$(python3 -c "
import sys
template = open(sys.argv[1], 'r').read()
question = sys.stdin.read()
print(template.replace('{QUESTION}', question), end='')
" "$ROLE_DIR/codex-role.txt" <<< "$PROMPT")
    PROMPT_GEMINI=$(python3 -c "
import sys
template = open(sys.argv[1], 'r').read()
question = sys.stdin.read()
print(template.replace('{QUESTION}', question), end='')
" "$ROLE_DIR/gemini-role.txt" <<< "$PROMPT")
  fi
fi

COUNCIL_STDIN="${COUNCIL_STDIN:-0}"

if [ "$COUNCIL_STDIN" = "1" ]; then
  printf '%s' "$PROMPT_CODEX"  > "$TMPDIR_COUNCIL/prompt_codex.txt"
  printf '%s' "$PROMPT_GEMINI" > "$TMPDIR_COUNCIL/prompt_gemini.txt"

  "$SCRIPT_DIR/ask-codex.sh" --prompt-file "$TMPDIR_COUNCIL/prompt_codex.txt" "$TIMEOUT" > "$TMPDIR_COUNCIL/codex.txt" 2>"$TMPDIR_COUNCIL/codex.err" &
  PID_CODEX=$!

  "$SCRIPT_DIR/ask-gemini.sh" --prompt-file "$TMPDIR_COUNCIL/prompt_gemini.txt" "$TIMEOUT" > "$TMPDIR_COUNCIL/gemini.txt" 2>"$TMPDIR_COUNCIL/gemini.err" &
  PID_GEMINI=$!
else
  "$SCRIPT_DIR/ask-codex.sh" "$PROMPT_CODEX" "$TIMEOUT" > "$TMPDIR_COUNCIL/codex.txt" 2>"$TMPDIR_COUNCIL/codex.err" &
  PID_CODEX=$!

  "$SCRIPT_DIR/ask-gemini.sh" "$PROMPT_GEMINI" "$TIMEOUT" > "$TMPDIR_COUNCIL/gemini.txt" 2>"$TMPDIR_COUNCIL/gemini.err" &
  PID_GEMINI=$!
fi

EC_CODEX=0
EC_GEMINI=0
wait $PID_CODEX  2>/dev/null || EC_CODEX=$?
wait $PID_GEMINI 2>/dev/null || EC_GEMINI=$?

TS_END=$(date +%s)
DURATION=$((TS_END - TS_START))
if [ -n "$COUNCIL_LOG" ]; then
  if [ ! -f "$COUNCIL_LOG" ]; then
    echo "timestamp,mode,timeout,duration_s,codex_exit,gemini_exit,prompt_preview" > "$COUNCIL_LOG"
  fi
  PROMPT_PREVIEW=$(echo "$PROMPT" | tr '\n' ' ' | cut -c1-80 | sed 's/"/""/g')
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ),$COUNCIL_MODE,$TIMEOUT,$DURATION,$EC_CODEX,$EC_GEMINI,\"$PROMPT_PREVIEW\"" >> "$COUNCIL_LOG"
fi

echo "=== CODEX / GPT-5.3-Codex RESPONSE (exit: $EC_CODEX) ==="
if [ $EC_CODEX -eq 0 ]; then
  cat "$TMPDIR_COUNCIL/codex.txt"
else
  echo "[FAILED] $(cat "$TMPDIR_COUNCIL/codex.err" 2>/dev/null)"
fi

echo ""
echo "=== GEMINI / Gemini-3.1-Pro RESPONSE (exit: $EC_GEMINI) ==="
if [ $EC_GEMINI -eq 0 ]; then
  cat "$TMPDIR_COUNCIL/gemini.txt"
else
  echo "[FAILED] $(cat "$TMPDIR_COUNCIL/gemini.err" 2>/dev/null)"
fi
