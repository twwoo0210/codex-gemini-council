#!/usr/bin/env bash
# ============================================================================
# ask-council-multiround.sh -- Multi-round council deliberation
# ============================================================================
#
# Implements a 3-round deliberation process using Dual LLMs (Codex & Gemini):
#   Round 1: Independent responses
#   Round 2: Each model receives a summary of divergence points and responds
#   Round 3: Final synthesis round with all perspectives
#
# Usage:
#   ask-council-multiround.sh "prompt" [timeout_seconds]
#   CONTEXT_FILES="file1:file2" ask-council-multiround.sh "prompt"
#
# Environment Variables:
#   COUNCIL_MODE     - Applied to each round (default: team)
#   COUNCIL_LOG      - CSV log file path (optional)
#   CONTEXT_FILES    - Colon-separated file paths for context injection
#   MAX_ROUNDS       - Number of deliberation rounds (default: 3, max: 5)
#
# ============================================================================
set -euo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  cat <<'HELP'
Usage: ask-council-multiround.sh "prompt" [timeout_seconds]

Multi-round iterative deliberation. Each round sends both models the
previous round's full output to build consensus incrementally.
HELP
  exit 0
fi

PROMPT="${1:?Usage: ask-council-multiround.sh \"prompt\" [timeout_seconds]}"
TIMEOUT="${2:-240}"
MAX_ROUNDS="${MAX_ROUNDS:-3}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ "$MAX_ROUNDS" -gt 5 ]; then
  echo "WARN: MAX_ROUNDS capped at 5 (was $MAX_ROUNDS)" >&2
  MAX_ROUNDS=5
fi

TMPDIR_MR=$(mktemp -d)
trap 'rm -rf "$TMPDIR_MR"' EXIT

echo "=== MULTI-ROUND COUNCIL DELIBERATION (${MAX_ROUNDS} rounds) ===" >&2

echo "--- Round 1/${MAX_ROUNDS}: Independent responses ---" >&2
bash "$SCRIPT_DIR/ask-council.sh" "$PROMPT" "$TIMEOUT" > "$TMPDIR_MR/round1.txt" 2>"$TMPDIR_MR/round1.err"

awk '/^=== CODEX/,/^=== GEMINI/' "$TMPDIR_MR/round1.txt" | sed '1d;$d' > "$TMPDIR_MR/r1_codex.txt" || true
awk '/^=== GEMINI/,0' "$TMPDIR_MR/round1.txt" | sed '1d' > "$TMPDIR_MR/r1_gemini.txt" || true

for model in codex gemini; do
  if [ ! -s "$TMPDIR_MR/r1_${model}.txt" ]; then
    echo "WARN: Could not extract ${model} response from Round 1 output" >&2
  fi
done

CURRENT_ROUND=2
PREV_ROUND_FILE="$TMPDIR_MR/round1.txt"

while [ $CURRENT_ROUND -le $MAX_ROUNDS ]; do
  echo "--- Round ${CURRENT_ROUND}/${MAX_ROUNDS}: Cross-model feedback ---" >&2

  FEEDBACK_PROMPT="You are in round ${CURRENT_ROUND} of a multi-round deliberation.

ORIGINAL QUESTION:
${PROMPT}

PREVIOUS ROUND RESPONSES:
$(cat "$PREV_ROUND_FILE")

INSTRUCTIONS FOR THIS ROUND:
- Review all previous responses carefully
- Identify points of agreement and disagreement
- Refine your position based on the other model's perspectives
- If you changed your mind on anything, explicitly state what and why
- Focus on resolving disagreements and strengthening the consensus
- Provide your updated, refined response"

  bash "$SCRIPT_DIR/ask-council.sh" "$FEEDBACK_PROMPT" "$TIMEOUT" > "$TMPDIR_MR/round${CURRENT_ROUND}.txt" 2>"$TMPDIR_MR/round${CURRENT_ROUND}.err"

  PREV_ROUND_FILE="$TMPDIR_MR/round${CURRENT_ROUND}.txt"
  CURRENT_ROUND=$((CURRENT_ROUND + 1))
done

echo "=== MULTI-ROUND DELIBERATION COMPLETE (${MAX_ROUNDS} rounds) ==="
echo ""
echo "--- FINAL ROUND RESPONSES ---"
cat "$PREV_ROUND_FILE"
echo ""
echo "--- ROUND 1 RESPONSES (for reference) ---"
cat "$TMPDIR_MR/round1.txt"
