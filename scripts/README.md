# scripts/

Multi-model council scripts for Claude Code. These scripts run Claude (Opus 4.6), GPT-5.3-Codex, and Gemini 3.1 Pro as three independent sessions in parallel. The calling Claude Code session acts as pure synthesizer, combining all three perspectives into a unified council response.

## Overview

```
                  ┌──>  ask-claude.sh ──>  Claude CLI ──>  Opus 4.6
ask-council.sh  ──┼──>  ask-codex.sh  ──>  Codex CLI  ──>  GPT-5.3-Codex
                  └──>  ask-gemini.sh ──>  Gemini CLI ──>  Gemini 3.1 Pro
```

`ask-council.sh` is the main entry point. It runs all three model scripts in parallel and collects their responses. The calling session does not contribute its own opinion -- it synthesizes the three independent outputs.

## Scripts

### ask-council.sh

Orchestrator that queries all three models in parallel and returns structured output.

| Item | Detail |
|------|--------|
| **Usage** | `ask-council.sh "prompt" [timeout_seconds]` |
| **Arg 1** | `prompt` -- The question to ask (required) |
| **Arg 2** | `timeout_seconds` -- Max wait per model (default: `180`) |
| **Env vars** | `COUNCIL_MODE`, `CLAUDE_MODEL`, `CODEX_MODEL`, `GEMINI_MODEL` (optional overrides) |
| **Exit 0** | At least one model responded |
| **Exit 1** | Missing prompt argument |

**Output format:**
```
=== CLAUDE / Opus-4.6 RESPONSE (exit: N) ===
<response or [FAILED] message>

=== CODEX / GPT-5.3-Codex RESPONSE (exit: N) ===
<response or [FAILED] message>

=== GEMINI / Gemini-3.1-Pro RESPONSE (exit: N) ===
<response or [FAILED] message>
```

#### Team Deliberation Mode

`ask-council.sh` supports two council modes controlled by the `COUNCIL_MODE` environment variable:

| Mode | Behavior |
|------|----------|
| `team` (default) | Wraps the user's question in a 4-phase team deliberation prompt (Research -> Analysis -> Critique -> Team Conclusion) using `council-team-prompt.txt` |
| `fast` | Passes the question as-is to each model (original behavior) |

In **team mode**, each model acts as an internal team of three specialists (Researcher, Analyst, Critic) and produces a structured 4-phase analysis. This yields deeper, more self-critical responses compared to fast mode.

```bash
# Team mode (default)
ask-council.sh "Should we use Redis or Memcached?"

# Fast mode (original behavior)
COUNCIL_MODE=fast ask-council.sh "Should we use Redis or Memcached?"
```

### council-team-prompt.txt

Template file used by `ask-council.sh` in team mode. Contains a 4-phase deliberation prompt with `{QUESTION}` placeholder that gets replaced with the user's actual question at runtime.

The four phases are:
1. **Research** -- Gather facts, prior art, and constraints
2. **Analysis** -- Evaluate trade-offs, compare approaches, propose recommendation
3. **Critique** -- Challenge assumptions, identify edge cases and failure modes
4. **Team Conclusion** -- Synthesize all phases into a final refined answer

### ask-claude.sh

Wrapper around the Claude CLI (`claude -p`) for non-interactive single-shot queries. Spawns an independent Claude session separate from the calling Claude Code session.

| Item | Detail |
|------|--------|
| **Usage** | `ask-claude.sh "prompt" [timeout_seconds] [model]` |
| **Arg 1** | `prompt` -- The question to ask (required) |
| **Arg 2** | `timeout_seconds` -- Max wait time (default: `120`) |
| **Arg 3** | `model` -- Model ID (default: `claude-opus-4-6`) |
| **Env vars** | `ANTHROPIC_API_KEY` (optional), `CLAUDE_MODEL` (optional override) |
| **Exit 0** | Success |
| **Exit 1** | `claude` CLI not found |
| **Exit 124** | Timeout exceeded |

**Claude CLI flags used:**
- `-p` -- print/pipe mode (non-interactive, single-shot)
- `--model` -- select model
- `--no-session-persistence` -- don't persist conversation state

**Key detail: `env -u CLAUDECODE`** -- When running inside a Claude Code session, the `CLAUDECODE` environment variable is set. This prevents spawning a nested Claude session. The script uses `env -u CLAUDECODE` to unset this variable, allowing an independent Claude CLI session to be spawned from within a running Claude Code session.

### ask-codex.sh

Wrapper around the Codex CLI (`codex exec`) for non-interactive single-shot queries.

| Item | Detail |
|------|--------|
| **Usage** | `ask-codex.sh "prompt" [timeout_seconds] [model]` |
| **Arg 1** | `prompt` -- The question to ask (required) |
| **Arg 2** | `timeout_seconds` -- Max wait time (default: `120`) |
| **Arg 3** | `model` -- Model ID (default: `gpt-5.3-codex`) |
| **Env vars** | `OPENAI_API_KEY` (optional), `CODEX_MODEL` (optional override) |
| **Exit 0** | Success |
| **Exit 1** | `codex` CLI not found |
| **Exit 124** | Timeout exceeded |

**Codex CLI flags used:**
- `exec` -- non-interactive single-shot mode
- `--model` -- select model
- `--skip-git-repo-check` -- don't require git context
- `--ephemeral` -- don't persist conversation

### ask-gemini.sh

Wrapper around the Gemini CLI (`gemini -p`) for non-interactive headless queries.

| Item | Detail |
|------|--------|
| **Usage** | `ask-gemini.sh "prompt" [timeout_seconds] [model]` |
| **Arg 1** | `prompt` -- The question to ask (required) |
| **Arg 2** | `timeout_seconds` -- Max wait time (default: `120`) |
| **Arg 3** | `model` -- Model ID (default: `gemini-3.1-pro-preview`) |
| **Env vars** | `GOOGLE_API_KEY` (optional), `GEMINI_MODEL` (optional override) |
| **Exit 0** | Success |
| **Exit 1** | `gemini` CLI not found |
| **Exit 124** | Timeout exceeded |

**Gemini CLI flags used:**
- `-p` -- pipe/headless mode (no interactive REPL)
- `--model` -- select model

## Prerequisites

1. **Claude CLI** -- Install Claude Code (`npm install -g @anthropic-ai/claude-code`), authenticate with `claude auth`
2. **Codex CLI** -- Install with `npm install -g @openai/codex`, then authenticate with `codex auth`
3. **Gemini CLI** -- Install and authenticate with `gemini auth`
4. **Bash 4+** -- Required for process management features
5. **timeout command** -- Available on Linux/macOS (coreutils); on Git Bash for Windows it is included

## Environment Variables

| Variable | Used by | Description |
|----------|---------|-------------|
| `COUNCIL_MODE` | ask-council.sh | `"team"` (default) or `"fast"` -- team mode wraps prompt in 4-phase deliberation template |
| `ANTHROPIC_API_KEY` | ask-claude.sh | Anthropic API key (alternative to OAuth) |
| `OPENAI_API_KEY` | ask-codex.sh | OpenAI API key (alternative to OAuth) |
| `GOOGLE_API_KEY` | ask-gemini.sh | Google API key (alternative to OAuth) |
| `CLAUDE_MODEL` | ask-claude.sh, ask-council.sh | Override default Claude model |
| `CODEX_MODEL` | ask-codex.sh, ask-council.sh | Override default Codex model |
| `GEMINI_MODEL` | ask-gemini.sh, ask-council.sh | Override default Gemini model |

## Integration with Claude Code

These scripts are invoked by Claude Code's agent system. In `CLAUDE.md`, the council is configured as the default behavior for substantive responses:

```bash
bash "scripts/ask-council.sh" "<question>" 180
```

Claude acts as pure synthesizer: all three models (Claude, GPT-5.3, Gemini) run independently via the council script. The calling Claude Code session collects all three responses and synthesizes them into a structured output with Consensus, Divergence, and Recommendation sections. The calling session does not contribute its own opinion -- it only orchestrates and synthesizes.
