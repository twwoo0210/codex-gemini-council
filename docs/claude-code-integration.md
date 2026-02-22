# Claude Code Integration

This guide explains how to integrate the Multi-Model Council into a Claude Code workspace.

## Directory Structure

```
your-project/
├── CLAUDE.md                          # Project instructions (council rules go here)
└── .claude/
    ├── bin/
    │   ├── ask-council.sh             # Parallel dispatcher (3 models)
    │   ├── ask-claude.sh              # Claude CLI wrapper (isolated session)
    │   ├── ask-codex.sh               # Codex CLI wrapper
    │   └── ask-gemini.sh              # Gemini CLI wrapper
    ├── skills/
    │   └── council/
    │       └── SKILL.md               # /council slash command
    └── agents/
        ├── council.md                 # Council pure synthesizer agent
        ├── codex.md                   # Codex delegation agent
        └── gemini.md                  # Gemini delegation agent
```

## Step 1: Add Council Rules to CLAUDE.md

Add the following section to your project's `CLAUDE.md`:

```markdown
## Multi-Model Council (MANDATORY -- Default Behavior)

Three independent model sessions run in parallel. The current session is a pure synthesizer:
- **Claude Opus 4.6** -- independent session via `ask-claude.sh` (env -u CLAUDECODE claude -p --no-session-persistence)
- **GPT-5.3-Codex** -- via `codex exec`, xhigh reasoning
- **Gemini 3.1 Pro** -- via `gemini -p`, headless mode
- **Current session** -- pure synthesizer, does NOT form its own opinion

### Invocation (REQUIRED for every substantive response)
\`\`\`bash
bash ".claude/bin/ask-council.sh" "<same question as user asked>" 180
\`\`\`

### Output Format (REQUIRED)
Every council response MUST follow this structure:
\`\`\`
## Council (Claude Opus 4.6 + GPT-5.3 + Gemini 3.1 Pro)
### Consensus -- where all 3 agree
### Divergence -- where they disagree (explain each position)
### Recommendation -- synthesized final answer
<details><summary>Claude Opus 4.6 Raw</summary>...</details>
<details><summary>GPT-5.3 Raw</summary>...</details>
<details><summary>Gemini 3.1 Pro Raw</summary>...</details>
\`\`\`
```

## Step 2: Configure the /council Skill

Create `.claude/skills/council/SKILL.md`:

```markdown
---
name: council
description: Get multi-model perspectives on any question.
---

# /council Skill

Usage: `/council <question or task>`

Run immediately. Do not wait for extra confirmation.

## Behavior

1. Take the user's question/task as-is.
2. Run all 3 models (Claude, Codex, Gemini) in parallel via Bash:
   \`\`\`bash
   bash ".claude/bin/ask-council.sh" "<question>" 180
   \`\`\`
3. Parse the structured output (3 independent responses).
4. Synthesize all three perspectives into a unified response as a pure synthesizer.
   Do NOT form your own opinion — only synthesize the 3 model responses.
```

## Step 3: Configure Agents

### .claude/agents/council.md

The council agent is a **pure synthesizer**. It:
- Dispatches to all 3 independent model sessions via `ask-council.sh`
- Parses structured output markers from Claude, Codex, and Gemini
- Synthesizes consensus, divergence, and recommendations
- Does NOT form its own opinion — only synthesizes the 3 model responses

Key configuration:

```yaml
---
name: council
tools: Bash, Read
model: opus
memory: none
---
```

### .claude/agents/codex.md

A delegation agent that sends tasks to GPT-5.3-Codex:

```yaml
---
name: codex
tools: Bash, Read
model: sonnet
memory: none
---
```

Invocation: `bash ".claude/bin/ask-codex.sh" "<prompt>"`

### .claude/agents/gemini.md

A delegation agent that sends tasks to Gemini 3.1 Pro:

```yaml
---
name: gemini
tools: Bash, Read
model: sonnet
memory: none
---
```

Invocation: `bash ".claude/bin/ask-gemini.sh" "<prompt>"`

## Step 4: Install Wrapper Scripts

Place the four scripts in `.claude/bin/` and make them executable:

```bash
chmod +x .claude/bin/ask-council.sh
chmod +x .claude/bin/ask-claude.sh
chmod +x .claude/bin/ask-codex.sh
chmod +x .claude/bin/ask-gemini.sh
```

### ask-claude.sh

The `ask-claude.sh` script runs Claude Opus 4.6 in an **isolated session**, separate from the current orchestrating session:

```bash
env -u CLAUDECODE claude -p "$PROMPT" --model claude-opus-4-6 --no-session-persistence
```

- `env -u CLAUDECODE`: Avoids the nested session error by unsetting the environment variable that Claude Code uses to detect existing sessions.
- `--no-session-persistence`: Ensures the spawned session is ephemeral.

See `scripts/` in this repository for the complete script sources.

## Skip Rules

The council should **NOT** be invoked for every interaction. Define clear skip rules in `CLAUDE.md`:

### When to SKIP Council (exhaustive list)

| Category | Examples |
|---|---|
| File operations | Read, write, edit, create files |
| Git commands | commit, push, pull, status, diff |
| Simple confirmations | Yes/no, proceed/cancel |
| Skill execution | `/save`, `/now`, `/search` |
| Tool configuration | MCP setup, CLI config |

### When to ALWAYS Run Council

| Category | Examples |
|---|---|
| Questions & analysis | Any question, opinion, or recommendation |
| Architecture | Design decisions, system design review |
| Code review | Review strategy, debugging approach |
| Planning | Sprint planning, project scoping |
| Research | Technology comparison, trade-off analysis |

## Subagent Context Injection

When Claude Code spawns Task subagents for substantive work, inject the council capability:

```markdown
### Subagent Context Injection
When spawning ANY Task subagent for substantive work, prepend this to the prompt:
> "IMPORTANT: You have access to external AI models via Bash.
> For substantive analysis, run:
> bash \".claude/bin/ask-council.sh\" \"<question>\" 180
> -- then synthesize all responses."
```

This ensures subagents can also leverage multi-model perspectives when needed.

## Configuration Reference

### Script Parameters

| Script | Arg 1 | Arg 2 | Arg 3 |
|---|---|---|---|
| `ask-council.sh` | prompt (required) | timeout (default: 180s) | -- |
| `ask-claude.sh` | prompt (required) | timeout (default: 120s) | model (default: claude-opus-4-6) |
| `ask-codex.sh` | prompt (required) | timeout (default: 120s) | model (default: gpt-5.3-codex) |
| `ask-gemini.sh` | prompt (required) | timeout (default: 120s) | model (default: gemini-3.1-pro-preview) |

### Environment Dependencies

| Dependency | Required By | Install |
|---|---|---|
| `claude` CLI | ask-claude.sh | Bundled with Claude Code (no separate install) |
| `codex` CLI | ask-codex.sh | `npm i -g @openai/codex` |
| `gemini` CLI | ask-gemini.sh | See official docs |
| `timeout` | All scripts | Built-in (Linux/macOS), coreutils (WSL) |
| `mktemp` | All scripts | Built-in on all Unix systems |

### Exit Codes

| Code | Meaning |
|---|---|
| 0 | Success |
| 1 | General error (CLI not found, auth failure) |
| 124 | Timeout exceeded |

## Verifying the Integration

After setup, test the full pipeline:

```bash
# Test individual models
bash .claude/bin/ask-claude.sh "What is 2+2?" 30
bash .claude/bin/ask-codex.sh "What is 2+2?" 30
bash .claude/bin/ask-gemini.sh "What is 2+2?" 30

# Test council (all 3 in parallel)
bash .claude/bin/ask-council.sh "What is 2+2?" 60

# Test from Claude Code
# Type in a Claude Code session:
/council What is the best sorting algorithm for nearly-sorted data?
```

If all three model responses appear in the council output, the integration is complete.
