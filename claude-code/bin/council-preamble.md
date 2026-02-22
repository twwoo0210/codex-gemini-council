# Multi-Model Council Context (inject into subagent prompts)

You have access to external AI models for multi-perspective analysis. All 3 models run as independent sessions — Claude via `claude -p`, Codex via `codex exec`, Gemini via `gemini -p`.

## Available Models
- **Claude Opus 4.6**: `bash "<YOUR_PROJECT_ROOT>/.claude/bin/ask-claude.sh" "<question>" 120`
- **GPT-5.3-Codex** (OpenAI): `bash "<YOUR_PROJECT_ROOT>/.claude/bin/ask-codex.sh" "<question>" 120`
- **Gemini 3.1 Pro** (Google): `bash "<YOUR_PROJECT_ROOT>/.claude/bin/ask-gemini.sh" "<question>" 120`
- **All 3 in parallel**: `bash "<YOUR_PROJECT_ROOT>/.claude/bin/ask-council.sh" "<question>" 180`

## Rule
For any substantive analysis, recommendation, or decision — run ask-council.sh which dispatches to all 3 models (Claude, Codex, Gemini) in parallel as independent sessions. Then synthesize all 3 responses into: Consensus / Divergence / Recommendation. Do NOT form your own opinion — purely synthesize the 3 independent responses.
