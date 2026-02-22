# Setup Guide

## Prerequisites

- **Bash shell**: Linux, macOS, or Windows with WSL/Git Bash
- **Node.js 18+**: Required for CLI tool installation
- **Claude Code**: The synthesizer runs within a Claude Code session. The `claude` CLI is included — no separate installation is needed. Claude CLI doesn't need separate installation — it's part of Claude Code itself.

## Step 1: Install Codex CLI (OpenAI)

Codex CLI is OpenAI's terminal-based coding agent.

```bash
npm install -g @openai/codex
```

> **Note**: The package name and installation method may change. Refer to the [official Codex CLI documentation](https://github.com/openai/codex) for the latest instructions.

### Authentication

On first run, Codex CLI initiates an OAuth browser authentication flow:

```bash
codex  # Opens browser for authentication
```

Alternatively, set an API key directly:

```bash
export OPENAI_API_KEY="sk-..."
```

### Configuration

Create or edit `~/.codex/config.toml`:

```toml
model = "gpt-5.3-codex"
reasoning_effort = "xhigh"
```

### Verify Installation

```bash
codex exec "Say hello" --ephemeral
```

Expected: A text response from GPT-5.3-Codex.

## Step 2: Install Gemini CLI (Google)

Gemini CLI is Google's terminal interface for Gemini models.

```bash
npm install -g @google/gemini-cli
```

> **Note**: Refer to the [official Gemini CLI documentation](https://github.com/google-gemini/gemini-cli) for the latest installation instructions.

### Authentication

On first run, Gemini CLI initiates an OAuth browser authentication flow:

```bash
gemini  # Opens browser for Google account authentication
```

### Configuration

Create or edit `~/.gemini/settings.json`:

```json
{
  "defaultModel": "gemini-3.1-pro-preview"
}
```

### Verify Installation

```bash
gemini -p "Say hello"
```

Expected: A text response from Gemini 3.1 Pro.

## Step 3: Verify Claude CLI (for Independent Session)

Claude CLI is bundled with Claude Code. Verify it can run in an isolated session:

```bash
env -u CLAUDECODE claude -p "Say hello" --model claude-opus-4-6 --no-session-persistence
```

Expected: A text response from Claude Opus 4.6. The `env -u CLAUDECODE` prefix is required to avoid the nested session error when running from inside a Claude Code session.

## Step 4: Install Council Scripts

Copy the wrapper scripts to your `.claude/bin/` directory:

```bash
mkdir -p .claude/bin

# Copy from this repository
cp scripts/ask-claude.sh  .claude/bin/
cp scripts/ask-codex.sh   .claude/bin/
cp scripts/ask-gemini.sh  .claude/bin/
cp scripts/ask-council.sh .claude/bin/

# Make executable
chmod +x .claude/bin/*.sh
```

### Verify Council

```bash
bash .claude/bin/ask-council.sh "What is 2+2?" 60
```

Expected output:

```
=== CLAUDE / Claude-Opus-4.6 RESPONSE (exit: 0) ===
4

=== CODEX / GPT-5.3-Codex RESPONSE (exit: 0) ===
4

=== GEMINI / Gemini-3.1-Pro RESPONSE (exit: 0) ===
4
```

## Step 5: Configure Claude Code Integration

See [claude-code-integration.md](./claude-code-integration.md) for detailed instructions on:

- Adding council rules to `CLAUDE.md`
- Setting up skills and agents
- Configuring skip rules

## Troubleshooting

### Codex CLI not found

```
ERROR: codex CLI not found in PATH
```

Ensure `codex` is globally installed and in your PATH:

```bash
which codex        # Should return a path
npm list -g @openai/codex
```

### Gemini CLI not found

```
ERROR: gemini CLI not found in PATH
```

Ensure `gemini` is globally installed and in your PATH:

```bash
which gemini       # Should return a path
```

### Timeout errors

```
--- CODEX ERROR (exit 124) ---
```

Exit code 124 means the process exceeded the timeout limit. Solutions:

- Increase the timeout: `ask-council.sh "prompt" 300`
- Simplify the prompt to reduce processing time
- Check network connectivity

### Authentication failures

If a CLI returns authentication errors:

1. Re-run the CLI directly (e.g., `codex` or `gemini`) to trigger the OAuth flow
2. Check that tokens have not expired
3. Verify API keys if using key-based auth

### Nested Session Error (Claude CLI)

```
Error: Cannot run claude inside an existing Claude Code session
```

This occurs when `ask-claude.sh` is invoked without clearing the `CLAUDECODE` environment variable. The solution:

```bash
# Wrong — will fail with nested session error
claude -p "prompt"

# Correct — unset CLAUDECODE to allow independent session
env -u CLAUDECODE claude -p "prompt" --no-session-persistence
```

The `ask-claude.sh` wrapper script handles this automatically. If you see this error, ensure you are using the wrapper script or manually unsetting the variable.

### Windows-Specific Notes

- Use WSL or Git Bash; native `cmd.exe` is not supported
- Ensure `timeout` command is available (part of GNU coreutils in WSL)
- File paths in scripts use forward slashes (`/`) for compatibility
