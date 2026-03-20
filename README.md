# AutoBashCMD

English | [中文](README_CN.md)

A zsh plugin that turns natural language into shell commands using local AI (Ollama / LM Studio).

Type what you want in plain language — get an executable command back. No cloud, no API keys, everything runs locally.

## Requirements

- `zsh`, `curl`, `jq`
- [Ollama](https://ollama.com) or [LM Studio](https://lmstudio.ai) running locally
- Recommended model: `qwen2.5-coder:3b` — fast, lightweight, good at shell command generation
  ```bash
  ollama pull qwen2.5-coder:3b
  ```

## Installation

Add to your `~/.zshrc`:

```bash
source /path/to/AutoBashCMD/shell/autobashcmd.zsh
```

Then reload:

```bash
source ~/.zshrc
```

## Usage

### `ai` — Generate a command

```bash
ai list all files in the current directory
ai find the process using port 3000
ai compress this folder into a zip
```

Outputs the command only. Does not execute.

### `airun` — Generate and confirm before executing

```bash
airun delete all .log files
```

Shows the command first, press Enter to run or any other key to cancel. Dangerous commands (e.g. `rm`, `sudo`) require typing `yes`.

### `aiexplain` — Explain a command

```bash
aiexplain grep -rn
aiexplain what does chmod 755 mean
```

### Natural language in shell

Just type naturally — if the input looks like natural language (contains non-ASCII characters), it auto-routes through `airun`:

```bash
列出当前目录下的文件
进入 src 目录
找出占用 3000 端口的进程
```

Help queries also work directly:

```bash
ls这个命令如何使用
介绍一下 grep
```

## Configuration

| Variable | Default | Description |
|---|---|---|
| `SHELL_AI_BACKEND` | `ollama` | `ollama` or `lmstudio` |
| `SHELL_AI_MODEL` | `qwen2.5-coder:3b` | Model for command generation |
| `SHELL_AI_TEXT_MODEL` | same as MODEL | Model for help/explain |
| `SHELL_AI_DEBUG` | unset | Set to `1` for debug output |
| `OLLAMA_BASE_URL` | `http://localhost:11434` | Ollama API endpoint |
| `LMSTUDIO_BASE_URL` | `http://127.0.0.1:1234/v1` | LM Studio API endpoint |

### Switch backends

```bash
# Use LM Studio
export SHELL_AI_BACKEND=lmstudio
export SHELL_AI_MODEL=qwen3.5-9b-mlx

# Back to Ollama
export SHELL_AI_BACKEND=ollama
export SHELL_AI_MODEL=qwen2.5-coder:3b
```

## How it works

1. **Local fast-path**: Common requests (directory listing, CPU usage, etc.) map directly to commands — no AI call needed.
2. **Intent classification**: The model classifies input as `command`, `cd`, `help`, or `reject`.
3. **Dispatch**: Each intent routes to the appropriate handler — command generation, directory resolution, help text, or rejection.
4. **Validation**: Generated commands are syntax-checked (`zsh -n`) and verified (`whence`). Invalid output triggers one retry with a correction prompt.
5. **Safety**: Risky commands (`rm`, `sudo`, `dd`, etc.) require explicit confirmation.

## License

MIT
