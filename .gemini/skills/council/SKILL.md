---
name: dual-llm-council
description: Get multi-model perspectives without using Claude's quota. Queries Codex (GPT-5.3) + Gemini (3.1 Pro) as independent sessions and synthesizes a unified answer.
---

# /council Skill

Usage: `/council <question or task>`

Run immediately. Do not wait for extra confirmation.

## Models (all run as independent sessions)
- **Codex**: GPT-5.3-Codex (xhigh reasoning effort)
- **Gemini**: Gemini 3.1 Pro

## Team Deliberation Mode

By default, `COUNCIL_MODE=team` is active. Each model receives a structured prompt template (`council-team-prompt.txt`) that simulates a 4-phase internal deliberation:

| Phase | Role | Purpose |
|---|---|---|
| Phase 1 | Researcher | 사실 수집, 선행 사례, 제약 조건 식별 |
| Phase 2 | Analyst | 트레이드오프 분석, 초기 권고안 |
| Phase 3 | Critic | 반론, 엣지 케이스, 신뢰도 평가 |
| Phase 4 | Team Lead | 최종 종합 결론 |

Set `COUNCIL_MODE=fast` to use the original single-response mode.

## Behavior

1. Take the user's question/task as-is.
2. Run both models in parallel via Bash:
   ```bash
   bash "scripts/ask-council.sh" "<question>" 180
   ```
   The script automatically applies the team prompt template when `COUNCIL_MODE=team` (default).
3. Parse the structured output (`=== CODEX RESPONSE ===`, `=== GEMINI RESPONSE ===`).
4. In **team mode**, focus on each model's **Phase 4 (Team Conclusion)** for synthesis, with earlier phases as supporting context.
5. As the synthesizer (current session), combine both independent perspectives into a unified response.
6. Do NOT form your own opinion separately — your role is purely to synthesize the 2 responses.

## Deep Dive Debate Mode (최상 품질)

For hard problems requiring maximum quality, use the debate script instead:

```bash
bash "scripts/ask-council-debate.sh" "<question>" 300
```

### Debate Synthesis Behavior

When synthesizing debate output:
1. Focus on the **Decision Packet Evolution** section at the bottom of the output.
2. Parse Round 1 Packets → Round 2 Revised Packets → Round 3 Convergence Packets.
3. **CRITICAL**: Identify the AUDIT VERDICT (APPROVE / APPROVE WITH CONDITIONS / REVISE / REJECT) from Round 4.
4. If any model says REVISE or REJECT, you MUST incorporate their MUST-FIX patches into the final answer.
5. Build the final answer as: **Converged Recommendation + Decision Tree + Residual Risks + Audit Patches**.
6. Preserve minority opinions where advisors disagreed — present as "if condition X, then alternative Y".
