# Claude Code Integration Files

This directory contains all the Claude Code configuration files needed to enable Multi-Model Council in your project.

## Architecture

The current Claude session acts as a **pure synthesizer**. All 3 models (Claude, Codex, Gemini) run as independent sessions via `ask-council.sh`, which dispatches them in parallel. The synthesizer collects all 3 responses and combines them into Consensus / Divergence / Recommendation — without forming its own opinion.

## Quick Setup

Copy the contents of this directory into your project's `.claude/` directory:

```bash
# From your project root
cp -r claude-code/agents/ .claude/agents/
cp -r claude-code/skills/ .claude/skills/
cp -r claude-code/bin/    .claude/bin/
```

Then copy the shell scripts from `scripts/` to `.claude/bin/`:

```bash
cp scripts/ask-council.sh .claude/bin/
cp scripts/ask-claude.sh  .claude/bin/
cp scripts/ask-codex.sh   .claude/bin/
cp scripts/ask-gemini.sh  .claude/bin/
chmod +x .claude/bin/*.sh
```

Finally, add the Council section from `CLAUDE.md.example` to your project's `CLAUDE.md`.

## Path Configuration

All agent and skill files use `<YOUR_PROJECT_ROOT>` as a placeholder. After copying, replace it with your actual project path:

```bash
# Example: replace placeholder with actual path
find .claude/ -name "*.md" -exec sed -i 's|<YOUR_PROJECT_ROOT>|/path/to/your/project|g' {} +
```

Or use relative paths if your shell supports it:
```bash
find .claude/ -name "*.md" -exec sed -i 's|<YOUR_PROJECT_ROOT>|.|g' {} +
```

## Directory Structure

```
claude-code/
  agents/
    council.md          # Pure synthesizer agent - collects 3 independent responses and synthesizes
    codex.md            # Delegation agent for GPT-5.3-Codex
    gemini.md           # Delegation agent for Gemini 3.1 Pro
  skills/
    council/
      SKILL.md          # /council slash command definition
  bin/
    council-preamble.md # Context block to inject into subagent prompts
  CLAUDE.md.example     # CLAUDE.md section to add to your project
  README.md             # This file
```

## What Each File Does

| File | Purpose |
|------|---------|
| `agents/council.md` | Pure synthesizer agent that dispatches to all 3 models (Claude, Codex, Gemini) as independent sessions and synthesizes their responses |
| `agents/codex.md` | Delegation agent that sends prompts to OpenAI Codex CLI and returns raw results |
| `agents/gemini.md` | Delegation agent that sends prompts to Google Gemini CLI and returns raw results |
| `skills/council/SKILL.md` | Enables the `/council <question>` slash command in Claude Code |
| `bin/council-preamble.md` | Markdown block to prepend to Task subagent prompts so they can also invoke the council |
| `CLAUDE.md.example` | Drop-in section for your CLAUDE.md to make council the default behavior |

## Shell Scripts (in `scripts/`)

| Script | Purpose |
|--------|---------|
| `ask-council.sh` | Dispatches question to all 3 models (Claude, Codex, Gemini) in parallel |
| `ask-claude.sh` | Sends prompt to Claude Opus 4.6 via `claude -p` (independent session) |
| `ask-codex.sh` | Sends prompt to GPT-5.3-Codex via `codex exec` |
| `ask-gemini.sh` | Sends prompt to Gemini 3.1 Pro via `gemini -p` |

## Prerequisites

Before these files will work, you need the CLI tools installed and authenticated:

1. **Claude Code** (`claude`): Already installed if you're reading this
2. **Codex CLI** (`codex`): `npm install -g @openai/codex` + OAuth login
3. **Gemini CLI** (`gemini`): `npm install -g @google/gemini-cli` or equivalent + OAuth login
4. **Shell scripts** from `scripts/` directory copied to `.claude/bin/`

See the main [README](../README.md) and [Setup Guide](../docs/setup.md) for detailed installation instructions.
