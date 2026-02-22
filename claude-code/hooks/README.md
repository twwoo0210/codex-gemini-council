# Claude Code Hooks for Council

Claude Code supports `PreToolUse` and `PostToolUse` hooks that run before and after tool invocations. These can be used as quality gates for council operations.

## Setup

Copy `council-hooks.json.example` to your `.claude/settings.json` and adjust paths:

```bash
cp claude-code/hooks/council-hooks.json.example .claude/settings.json
```

## Hook Configuration

The `council-hooks.json.example` file demonstrates how to configure hooks for council operations. You will need to create your own hook scripts tailored to your workflow.

### Example PreToolUse Hook

A `PreToolUse` hook for council could validate:
- Council script exists and is executable
- Required CLI tools are available
- Prompt is not empty

### Example PostToolUse Hook

A `PostToolUse` hook for council could validate:
- Output contains all 3 section markers (`=== CLAUDE`, `=== CODEX`, `=== GEMINI`)
- At least one model returned successfully (exit 0)
- Warns if any model failed

### Writing Your Own Hooks

Create shell scripts that exit 0 for pass or non-zero for fail. The hook receives the tool input via stdin as JSON. See [Claude Code Hooks docs](https://docs.anthropic.com/en/docs/claude-code/hooks) for details.

## Environment Variables

| Variable | Description |
|---|---|
| `COUNCIL_HOOKS_STRICT` | Set to `1` to fail on any model failure (default: warn only) |
