#!/usr/bin/env bash
# ============================================================================
# ask-council-debate.sh -- Deep Dive Debate: multi-round adversarial council
# ============================================================================
#
# Implements a 3+1 round deliberation process designed for maximum quality:
#
#   Round 1 — Independent Deep Dive (diversity)
#   Round 2 — Cross-Critique (adversarial)
#   Round 3 — Convergence (synthesis)
#   Round 4 — Audit (red team) [optional, enabled by default]
#
# Usage:
#   ask-council-debate.sh "prompt" [timeout_per_round]
#
# Environment Variables:
#   COUNCIL_AUDIT     - "true" (default) or "false" — enable/disable Round 4
#   COUNCIL_LOG       - CSV log file path (optional)
#   CONTEXT_FILES     - Colon-separated file paths for context injection
#   DEBATE_TIMEOUT_R1 - Round 1 timeout (default: 300)
#   DEBATE_TIMEOUT_R2 - Round 2 timeout (default: 300)
#   DEBATE_TIMEOUT_R3 - Round 3 timeout (default: 300)
#   DEBATE_TIMEOUT_R4 - Round 4 timeout (default: 240)
#
# ============================================================================
set -euo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  cat <<'HELP'
Usage: ask-council-debate.sh "prompt" [timeout_per_round]

4-round adversarial deep-dive debate for maximum-quality answers using Dual LLMs (Codex & Gemini).
HELP
  exit 0
fi

PROMPT="${1:?Usage: ask-council-debate.sh \"prompt\" [timeout_per_round]}"
DEFAULT_TIMEOUT="${2:-300}"

COUNCIL_AUDIT="${COUNCIL_AUDIT:-true}"
DEBATE_TIMEOUT_R1="${DEBATE_TIMEOUT_R1:-$DEFAULT_TIMEOUT}"
DEBATE_TIMEOUT_R2="${DEBATE_TIMEOUT_R2:-$DEFAULT_TIMEOUT}"
DEBATE_TIMEOUT_R3="${DEBATE_TIMEOUT_R3:-$DEFAULT_TIMEOUT}"
DEBATE_TIMEOUT_R4="${DEBATE_TIMEOUT_R4:-240}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROMPT_DIR="$SCRIPT_DIR/council-debate-prompts"

for TPL in round1-deep-dive.txt round2-cross-critique.txt round3-converge.txt round4-audit.txt; do
  if [ ! -f "$PROMPT_DIR/$TPL" ]; then
    echo "FATAL: Template not found: $PROMPT_DIR/$TPL" >&2
    exit 1
  fi
done

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
mkdir -p "$WORKDIR"/{round1,round2,round3,round4}

ENRICHED_PROMPT="$PROMPT"
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
    ENRICHED_PROMPT="${ENRICHED_PROMPT}

=== CONTEXT FILES ===
${CONTEXT_BLOCK}"
  fi
fi

printf "%s\n" "$ENRICHED_PROMPT" > "$WORKDIR/enriched_prompt.txt"

render_template() {
  local template_file="$1"
  local output_file="$2"
  shift 2

  python3 -c "
import sys
template = open(sys.argv[1], 'r').read()
for arg in sys.argv[2:]:
    key, val_file = arg.split('=', 1)
    val = open(val_file, 'r').read()
    template = template.replace('{' + key + '}', val)
print(template, end='')
" "$template_file" "$@" > "$output_file"
}

extract_section() {
  local file="$1"
  local header="$2"
  awk -v h="$header" '
    BEGIN { found=0 }
    $0 ~ h { found=1; next }
    found && /^## / { found=0 }
    found { print }
  ' "$file" | sed '/^$/{ N; /^\n$/d; }' | head -80
}

run_parallel() {
  local round_dir="$1"
  local codex_pf="$2"
  local gemini_pf="$3"
  local tout="$4"

  "$SCRIPT_DIR/ask-codex.sh" --prompt-file "$codex_pf" "$tout" > "$round_dir/codex.txt" 2>"$round_dir/codex.err" &
  local pid_x=$!

  "$SCRIPT_DIR/ask-gemini.sh" --prompt-file "$gemini_pf" "$tout" > "$round_dir/gemini.txt" 2>"$round_dir/gemini.err" &
  local pid_g=$!

  local ec_x=0 ec_g=0
  wait $pid_x 2>/dev/null || ec_x=$?
  wait $pid_g 2>/dev/null || ec_g=$?

  echo "$ec_x $ec_g" > "$round_dir/exit_codes.txt"

  local ok=0
  [ $ec_x -eq 0 ] && ok=1
  [ $ec_g -eq 0 ] && ok=1
  if [ $ok -eq 0 ]; then
    echo "ERROR: Both models failed in this round" >&2
    return 1
  fi
  return 0
}

COUNCIL_LOG="${COUNCIL_LOG:-}"
DEBATE_START=$(date +%s)

# ============================================================================
# ROUND 1
# ============================================================================
echo "╔══════════════════════════════════════════════════════════════╗" >&2
echo "║  ROUND 1/$([ "$COUNCIL_AUDIT" = "true" ] && echo "4" || echo "3") — Independent Deep Dive (diversity)              ║" >&2
echo "╚══════════════════════════════════════════════════════════════╝" >&2

render_template "$PROMPT_DIR/round1-deep-dive.txt" "$WORKDIR/round1/prompt.txt" \
  "QUESTION=$WORKDIR/enriched_prompt.txt"

run_parallel "$WORKDIR/round1" "$WORKDIR/round1/prompt.txt" "$WORKDIR/round1/prompt.txt" "$DEBATE_TIMEOUT_R1"

for model in codex gemini; do
  extract_section "$WORKDIR/round1/${model}.txt" "## 6. DECISION PACKET" > "$WORKDIR/round1/packet_${model}.txt"
  if [ ! -s "$WORKDIR/round1/packet_${model}.txt" ]; then
    echo "WARN: Could not extract Decision Packet from $model R1, using truncated output" >&2
    head -60 "$WORKDIR/round1/${model}.txt" > "$WORKDIR/round1/packet_${model}.txt"
  fi
done
echo "  ✓ Round 1 complete. Decision Packets extracted." >&2

# ============================================================================
# ROUND 2
# ============================================================================
echo "╔══════════════════════════════════════════════════════════════╗" >&2
echo "║  ROUND 2/$([ "$COUNCIL_AUDIT" = "true" ] && echo "4" || echo "3") — Cross-Critique (adversarial)                  ║" >&2
echo "╚══════════════════════════════════════════════════════════════╝" >&2

render_template "$PROMPT_DIR/round2-cross-critique.txt" "$WORKDIR/round2/prompt_codex.txt" \
  "QUESTION=$WORKDIR/enriched_prompt.txt" \
  "MY_PACKET=$WORKDIR/round1/packet_codex.txt" \
  "PACKET_OTHER=$WORKDIR/round1/packet_gemini.txt"

render_template "$PROMPT_DIR/round2-cross-critique.txt" "$WORKDIR/round2/prompt_gemini.txt" \
  "QUESTION=$WORKDIR/enriched_prompt.txt" \
  "MY_PACKET=$WORKDIR/round1/packet_gemini.txt" \
  "PACKET_OTHER=$WORKDIR/round1/packet_codex.txt"

run_parallel "$WORKDIR/round2" "$WORKDIR/round2/prompt_codex.txt" "$WORKDIR/round2/prompt_gemini.txt" "$DEBATE_TIMEOUT_R2"

for model in codex gemini; do
  extract_section "$WORKDIR/round2/${model}.txt" "## 5. REVISED DECISION PACKET" > "$WORKDIR/round2/packet_${model}.txt"
  if [ ! -s "$WORKDIR/round2/packet_${model}.txt" ]; then
    echo "WARN: Could not extract Revised Packet from $model R2, using truncated output" >&2
    head -60 "$WORKDIR/round2/${model}.txt" > "$WORKDIR/round2/packet_${model}.txt"
  fi
done
echo "  ✓ Round 2 complete. Revised Decision Packets extracted." >&2

# ============================================================================
# ROUND 3
# ============================================================================
echo "╔══════════════════════════════════════════════════════════════╗" >&2
echo "║  ROUND 3/$([ "$COUNCIL_AUDIT" = "true" ] && echo "4" || echo "3") — Convergence (synthesis)                       ║" >&2
echo "╚══════════════════════════════════════════════════════════════╝" >&2

render_template "$PROMPT_DIR/round3-converge.txt" "$WORKDIR/round3/prompt.txt" \
  "QUESTION=$WORKDIR/enriched_prompt.txt" \
  "PACKET_1=$WORKDIR/round2/packet_codex.txt" \
  "PACKET_2=$WORKDIR/round2/packet_gemini.txt"

run_parallel "$WORKDIR/round3" "$WORKDIR/round3/prompt.txt" "$WORKDIR/round3/prompt.txt" "$DEBATE_TIMEOUT_R3"

for model in codex gemini; do
  extract_section "$WORKDIR/round3/${model}.txt" "## 7. CONVERGENCE PACKET" > "$WORKDIR/round3/conv_${model}.txt"
  if [ ! -s "$WORKDIR/round3/conv_${model}.txt" ]; then
    echo "WARN: Could not extract Convergence Packet from $model R3, using truncated output" >&2
    head -80 "$WORKDIR/round3/${model}.txt" > "$WORKDIR/round3/conv_${model}.txt"
  fi
done

{
  echo "=== Converged Plan from Advisor 1 (Codex) ==="
  extract_section "$WORKDIR/round3/codex.txt" "## 3. CONVERGED PLAN"
  echo ""
  echo "=== Converged Plan from Advisor 2 (Gemini) ==="
  extract_section "$WORKDIR/round3/gemini.txt" "## 3. CONVERGED PLAN"
} > "$WORKDIR/round3/converged_plan.txt"

if [ ! -s "$WORKDIR/round3/converged_plan.txt" ]; then
  { cat "$WORKDIR/round3/conv_codex.txt"; cat "$WORKDIR/round3/conv_gemini.txt"; } > "$WORKDIR/round3/converged_plan.txt"
fi

echo "  ✓ Round 3 complete. Convergence Packets extracted." >&2

# ============================================================================
# ROUND 4
# ============================================================================
if [ "$COUNCIL_AUDIT" = "true" ]; then
  echo "╔══════════════════════════════════════════════════════════════╗" >&2
  echo "║  ROUND 4/4 — Audit (red team)                              ║" >&2
  echo "╚══════════════════════════════════════════════════════════════╝" >&2

  render_template "$PROMPT_DIR/round4-audit.txt" "$WORKDIR/round4/prompt.txt" \
    "QUESTION=$WORKDIR/enriched_prompt.txt" \
    "CONVERGED_PLAN=$WORKDIR/round3/converged_plan.txt" \
    "CONVERGENCE_PACKET_1=$WORKDIR/round3/conv_codex.txt" \
    "CONVERGENCE_PACKET_2=$WORKDIR/round3/conv_gemini.txt"

  run_parallel "$WORKDIR/round4" "$WORKDIR/round4/prompt.txt" "$WORKDIR/round4/prompt.txt" "$DEBATE_TIMEOUT_R4"

  echo "  ✓ Round 4 (Audit) complete." >&2
fi

# ============================================================================
# METRICS LOGGING
# ============================================================================
DEBATE_END=$(date +%s)
DEBATE_DURATION=$((DEBATE_END - DEBATE_START))
TOTAL_ROUNDS=$([ "$COUNCIL_AUDIT" = "true" ] && echo "4" || echo "3")

if [ -n "$COUNCIL_LOG" ]; then
  if [ ! -f "$COUNCIL_LOG" ]; then
    echo "timestamp,mode,rounds,duration_s,prompt_preview" > "$COUNCIL_LOG"
  fi
  PROMPT_PREVIEW=$(echo "$PROMPT" | tr '\n' ' ' | cut -c1-80 | sed 's/"/""/g')
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ),debate,$TOTAL_ROUNDS,$DEBATE_DURATION,\"$PROMPT_PREVIEW\"" >> "$COUNCIL_LOG"
fi

echo "" >&2
echo "══════════════════════════════════════════════════════════════" >&2
echo "  Deep Dive Debate complete: $TOTAL_ROUNDS rounds in ${DEBATE_DURATION}s" >&2
echo "══════════════════════════════════════════════════════════════" >&2

# ============================================================================
# STRUCTURED OUTPUT
# ============================================================================
echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║           DEEP DIVE DEBATE — FULL TRANSCRIPT                           ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

for round_num in 1 2 3; do
  case $round_num in
    1) round_name="Independent Deep Dive" ;;
    2) round_name="Cross-Critique" ;;
    3) round_name="Convergence" ;;
  esac
  echo "┌──────────────────────────────────────────────────────────────┐"
  echo "│  ROUND $round_num — $round_name"
  echo "└──────────────────────────────────────────────────────────────┘"
  read -r ec_x ec_g < "$WORKDIR/round${round_num}/exit_codes.txt"
  echo ""
  echo "=== CODEX / Round $round_num (exit: $ec_x) ==="
  cat "$WORKDIR/round${round_num}/codex.txt"
  echo ""
  echo "=== GEMINI / Round $round_num (exit: $ec_g) ==="
  cat "$WORKDIR/round${round_num}/gemini.txt"
  echo ""
done

if [ "$COUNCIL_AUDIT" = "true" ]; then
  echo "┌──────────────────────────────────────────────────────────────┐"
  echo "│  ROUND 4 — Audit (Red Team)"
  echo "└──────────────────────────────────────────────────────────────┘"
  read -r ec_x ec_g < "$WORKDIR/round4/exit_codes.txt"
  echo ""
  echo "=== CODEX / Round 4 Audit (exit: $ec_x) ==="
  cat "$WORKDIR/round4/codex.txt"
  echo ""
  echo "=== GEMINI / Round 4 Audit (exit: $ec_g) ==="
  cat "$WORKDIR/round4/gemini.txt"
  echo ""
fi

echo "┌──────────────────────────────────────────────────────────────┐"
echo "│  DECISION PACKET EVOLUTION (for synthesizer)                 │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""
echo "--- Round 1 Decision Packets ---"
for model in Codex Gemini; do
  lc=$(echo "$model" | tr '[:upper:]' '[:lower:]')
  echo "[$model]"
  cat "$WORKDIR/round1/packet_${lc}.txt"
  echo ""
done
echo "--- Round 2 Revised Decision Packets ---"
for model in Codex Gemini; do
  lc=$(echo "$model" | tr '[:upper:]' '[:lower:]')
  echo "[$model]"
  cat "$WORKDIR/round2/packet_${lc}.txt"
  echo ""
done
echo "--- Round 3 Convergence Packets ---"
for model in Codex Gemini; do
  lc=$(echo "$model" | tr '[:upper:]' '[:lower:]')
  echo "[$model]"
  cat "$WORKDIR/round3/conv_${lc}.txt"
  echo ""
done
echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║  DEBATE COMPLETE — $TOTAL_ROUNDS rounds, ${DEBATE_DURATION}s total"
echo "║  Synthesizer: parse Decision Packet Evolution + Audit verdicts above.  ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
