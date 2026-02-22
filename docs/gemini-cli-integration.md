# Gemini CLI Integration

This guide explains how to integrate the Dual LLM Council into a Gemini CLI or Claude Code workspace.

## Directory Structure

```
your-project/
├── .gemini/
│   ├── GEMINI.md                      # Project instructions (council rules go here)
│   └── skills/
│       └── council/
│           └── SKILL.md               # /council slash command
└── scripts/
    ├── ask-council.sh                 # Parallel dispatcher (2 models)
    ├── ask-codex.sh                   # Codex CLI wrapper
    └── ask-gemini.sh                  # Gemini CLI wrapper
```

## Step 1: Native Slash Commands (`/council` & `/debate`)

Gemini CLI natively supports custom slash commands via `.toml` files. We have provided ready-to-use commands in `.gemini/commands/`.

**To install globally (use anywhere):**
Copy the `.toml` files to your global Gemini configuration and update the paths to point to this repository:
```bash
cp .gemini/commands/*.toml ~/.gemini/commands/
# Then edit ~/.gemini/commands/*.toml to use absolute paths (e.g. bash /path/to/repo/scripts/ask-council.sh)
```

**Usage in Gemini CLI:**
Once installed, simply type in any Gemini CLI session:
- `/council How should I structure my React state?` -> Triggers the standard 2-model council.
- `/debate What is the best database for a high-frequency trading app?` -> Triggers the 4+2 round deep dive debate.

## Step 2: Add Council Rules to GEMINI.md (For Autonomous Usage)

Add the following section to your project's `.gemini/GEMINI.md` (or equivalent system prompt injection file):

```markdown
## Dual LLM Council (MANDATORY -- Default Behavior)

Two independent model sessions run in parallel. The current session is a pure synthesizer:
- **GPT-5.3-Codex** -- via `codex exec`, xhigh reasoning
- **Gemini 3.1 Pro** -- via `gemini`, headless mode
- **Current session** -- pure synthesizer, does NOT form its own opinion

### Invocation (REQUIRED for every substantive response)
\`\`\`bash
bash "scripts/ask-council.sh" "<same question as user asked>" 180
\`\`\`

### Output Format (REQUIRED)
Every council response MUST follow this structure:
\`\`\`
## Council (GPT-5.3 + Gemini 3.1 Pro)
### Consensus -- where both agree
### Divergence -- where they disagree (explain each position)
### Recommendation -- synthesized final answer
<details><summary>GPT-5.3 Raw</summary>...</details>
<details><summary>Gemini 3.1 Pro Raw</summary>...</details>
\`\`\`
```

## Step 3: Configure the /council Skill (Optional)

If you prefer using Agent Skills over Slash Commands, ensure `.gemini/skills/council/SKILL.md` exists as defined in the repository.

```markdown
---
name: dual-llm-council
description: Get multi-model perspectives without using Claude's quota.
---

# /council Skill

Usage: `/council <question or task>`

Run immediately. Do not wait for extra confirmation.

## Behavior

1. Take the user's question/task as-is.
2. Run both models (Codex, Gemini) in parallel via Bash:
   \`\`\`bash
   bash "scripts/ask-council.sh" "<question>" 180
   \`\`\`
3. Parse the structured output (2 independent responses).
4. Synthesize both perspectives into a unified response as a pure synthesizer.
   Do NOT form your own opinion — only synthesize the 2 model responses.
```

## Skip Rules

The council should **NOT** be invoked for every interaction. Define clear skip rules:

### When to SKIP Council (exhaustive list)

| Category | Examples |
|---|---|
| File operations | Read, write, edit, create files |
| Git commands | commit, push, pull, status, diff |
| Simple confirmations | Yes/no, proceed/cancel |
| Tool configuration | Configuration setup |

### When to ALWAYS Run Council

| Category | Examples |
|---|---|
| Questions & analysis | Any question, opinion, or recommendation |
| Architecture | Design decisions, system design review |
| Code review | Review strategy, debugging approach |
| Planning | Sprint planning, project scoping |
| Research | Technology comparison, trade-off analysis |

## Configuration Reference

### Script Parameters

| Script | Arg 1 | Arg 2 | Arg 3 |
|---|---|---|---|
| `ask-council.sh` | prompt (required) | timeout (default: 180s) | -- |
| `ask-codex.sh` | prompt (required) | timeout (default: 120s) | model (default: gpt-5.3-codex) |
| `ask-gemini.sh` | prompt (required) | timeout (default: 120s) | model (default: gemini-3.1-pro-preview) |

### Environment Dependencies

| Dependency | Required By | Install |
|---|---|---|
| `codex` CLI | ask-codex.sh | `npm i -g @openai/codex` |
| `gemini` CLI | ask-gemini.sh | `npm i -g @google/gemini-cli` |
| `timeout` / `gtimeout` | All scripts | Built-in (Linux), coreutils (macOS) |

## Verifying the Integration

After setup, test the full pipeline:

```bash
# Test individual models
bash scripts/ask-codex.sh "What is 2+2?" 30
bash scripts/ask-gemini.sh "What is 2+2?" 30

# Test council (both in parallel)
bash scripts/ask-council.sh "What is 2+2?" 60
```
