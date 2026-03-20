# AutoBashCMD — Agent Installation Guide

> **This document is for coding agents (Claude Code, Cursor, Codex, etc.)**
> A human user has asked you to install AutoBashCMD. Follow every step below in order.

## Step 1: Check Prerequisites

Run these commands and verify the output:

```bash
zsh --version    # REQUIRED — must be installed
curl --version   # REQUIRED — must be installed
jq --version     # REQUIRED — must be installed
```

If any of the above is missing, install it first:

- macOS: `brew install jq` (zsh and curl are pre-installed)
- Linux: `sudo apt install zsh curl jq` (or equivalent for your distro)

## Step 2: Check Ollama

```bash
curl -s http://localhost:11434/api/tags | jq -r '.models[].name'
```

- If this returns a model list -> Ollama is running, proceed.
- If this fails -> Ollama is not running or not installed.
  - Install: `brew install ollama` (macOS) or see https://ollama.com/download
  - Start: `ollama serve &`
  - Wait a few seconds, then retry the curl command.

## Step 3: Pull Recommended Model

```bash
ollama pull qwen2.5-coder:3b
```

Skip if the model already appears in the Step 2 output.

## Step 4: Clone Repository

```bash
git clone https://github.com/chaodongzhang/AutoBashCMD.git ~/.AutoBashCMD
```

If `~/.AutoBashCMD` already exists:

```bash
git -C ~/.AutoBashCMD pull --ff-only
```

## Step 5: Configure Shell

Check if already configured:

```bash
grep -q "autobashcmd.zsh" ~/.zshrc 2>/dev/null && echo "ALREADY_CONFIGURED" || echo "NEEDS_SETUP"
```

If `~/.zshrc` does not exist, create it first with `touch ~/.zshrc`.

If `NEEDS_SETUP`, append these lines to `~/.zshrc`:

```bash
# AutoBashCMD - natural language to shell commands
source ~/.AutoBashCMD/shell/autobashcmd.zsh
```

Do NOT add duplicate entries. Do NOT remove existing content in `~/.zshrc`.

## Step 6: Verify Installation

```bash
zsh -n ~/.AutoBashCMD/shell/autobashcmd.zsh
```

Expected: no output (means syntax is valid). If there are errors, report them to the user.

## Step 7: Tell the User

Installation is complete. Tell the user:

> AutoBashCMD installed successfully. Run `source ~/.zshrc` or open a new terminal to activate.
>
> Then try: `ai list files in current directory`

**Do NOT run `source ~/.zshrc` yourself** — it won't affect the user's interactive shell session.
