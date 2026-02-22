# Setup Guide

## Prerequisites

- **OS Environment**:
  - **macOS**: Requires `coreutils` for timeout fallback (`brew install coreutils`).
  - **Windows**: WSL2 or Git Bash is required. Native PowerShell is not fully supported.
- **Bash shell**: Linux, macOS, or Windows with WSL/Git Bash
- **Node.js 18+**: Required for CLI tool installation

## Step 1: Install Codex CLI (OpenAI)

Codex CLI is OpenAI's terminal-based coding agent.

```bash
npm install -g @openai/codex
```

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

### Authentication

On first run, Gemini CLI initiates an OAuth browser authentication flow:

```bash
gemini  # Opens browser for Google account authentication
```

### Configuration

Create or edit `~/.gemini/settings.json` to match the official category structure:

```json
{
  "general": {
    "defaultApprovalMode": "plan",
    "theme": "system",
    "sandbox": true
  },
  "experimental": {
    "plan": true
  },
  "model": {
    "defaultModel": "gemini-3.1-pro-preview"
  },
  "output": {
    "format": "text",
    "markdown": true
  },
  "security": {
    "disableYoloMode": true
  }
}
```

### Verify Installation

```bash
gemini "Say hello"
```

Expected: A text response from Gemini 3.1 Pro.

## Step 3: Install Council Scripts

Keep the scripts organized within your project repository (e.g., in a `scripts` folder).

Ensure execution permissions are set via Git metadata, or apply them locally:

```bash
chmod +x scripts/*.sh
```

### Verify Council

```bash
bash scripts/ask-council.sh "What is 2+2?" 60
```

Expected output:

```
=== CODEX / GPT-5.3-Codex RESPONSE (exit: 0) ===
4

=== GEMINI / Gemini-3.1-Pro RESPONSE (exit: 0) ===
4
```

## Step 4: Configure Gemini CLI Integration

See [gemini-cli-integration.md](./gemini-cli-integration.md) for detailed instructions on adding council capabilities to your local Gemini CLI configuration or agent environment.

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

### Timeout command not found (macOS)

```
ERROR: timeout command not found (install coreutils on macOS)
```

Install `coreutils` to gain access to `gtimeout` which the wrappers automatically detect:

```bash
brew install coreutils
```

### Windows-Specific Notes

- Use WSL or Git Bash; native `cmd.exe` or PowerShell alone is not fully supported for process group dispatch.
- Ensure the codebase line endings are set to LF (handled automatically by the included `.gitattributes`).
- File paths in scripts use forward slashes (`/`) for compatibility. The script manages `CONTEXT_FILES` delimited by `:` properly in WSL.