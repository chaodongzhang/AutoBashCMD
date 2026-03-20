# AGENTS.md — AutoBashCMD

## Project Overview

A zsh plugin that converts natural language (primarily Chinese) into shell commands using local AI backends (Ollama / LM Studio). Single-file project: `shell/autobashcmd.zsh` (≈1400 lines).

Core flow: user input → intent classification (command / cd / help / reject) → dispatch to appropriate handler → output command or explanation text.

## Build / Lint / Test

There is no build step, no test framework, and no linter configured.

### Validate syntax

```bash
zsh -n shell/autobashcmd.zsh
```

### Source and smoke-test

```bash
source shell/autobashcmd.zsh
ai 列出当前目录下的文件
```

### Debug mode

```bash
export SHELL_AI_DEBUG=1
ai 找出占用 3000 端口的进程
# stderr will show: backend, model, mode, classification, payload size, raw output, final command
```

### Verify Ollama connectivity

```bash
curl -s http://localhost:11434/api/tags | jq -r '.models[].name'
```

## Architecture

```
shell/autobashcmd.zsh
├── Configuration layer     — _autobashcmd_{backend,model,text_model,*_base_url}
├── System prompts          — _autobashcmd_system_prompt_{classifier,command,help}
├── Context builder         — _autobashcmd_context (PWD, ls, find, last command)
├── Intent classification   — _autobashcmd_request_classifier → _autobashcmd_parse_classification
├── Local fast-path rules   — _autobashcmd_directory_command_from_prompt, _autobashcmd_common_command_from_prompt
├── Command generation      — _autobashcmd_request_command → _autobashcmd_finalize_command
├── Help / explain          — _autobashcmd_local_explain, _autobashcmd_request_text
├── Directory resolution    — _autobashcmd_resolve_directory_target, _autobashcmd_find_directory_matches
├── Validation & safety     — _autobashcmd_is_valid_command, _autobashcmd_is_risky_command
├── Dispatch orchestrator   — _autobashcmd_dispatch_request
└── Public API              — ai(), airun(), aiexplain(), command_not_found_handler()
```

## Code Style Guidelines

### Language & Shell

- **Zsh only.** All scripts are sourced into the user's interactive zsh session.
- Every function MUST begin with `emulate -L zsh` to reset options to a clean zsh baseline.
- Add `setopt pipefail` when the function uses pipelines whose exit status matters.

### Naming Conventions

| Category | Pattern | Example |
|---|---|---|
| Internal functions | `_autobashcmd_<descriptive_name>` | `_autobashcmd_resolve_directory_target` |
| Public functions | Short, user-facing names | `ai`, `airun`, `aiexplain` |
| Environment variables (user-facing) | `SHELL_AI_*` or `OLLAMA_*` | `SHELL_AI_BACKEND`, `SHELL_AI_DEBUG` |
| Local variables | `snake_case`, always declared with `local` | `local prompt context raw cmd` |

### Function Structure

```zsh
_autobashcmd_example() {
  emulate -L zsh
  setopt pipefail          # only if pipelines are used

  local var1 var2          # declare ALL locals upfront, on one or few lines
  var1="$1"
  var2="$(_autobashcmd_trim "$2")"

  # ... body ...

  print -r -- "$result"    # use print -r --, never echo
}
```

### Output & I/O

- **stdout**: Use `print -r -- "$value"` for all normal output. Never use `echo`.
- **stderr**: Use `print -u2 -r -- "message"` for errors and debug output.
- **Debug logging**: Use `_autobashcmd_debug "key=value"` — it checks `SHELL_AI_DEBUG` internally.
- **Return values**: Use stdout for data, return code for success/failure. Do not mix.

### String Handling

- Always trim user input with `_autobashcmd_trim "$var"` before processing.
- Always quote variables: `"$var"`, `"$1"`, `"$(...)"`. No unquoted expansions.
- For parameter stripping, use zsh native operators: `${var#prefix}`, `${var%suffix}`.
- Use `${(q)var}` for shell-quoting paths that may contain spaces/special chars.

### JSON Handling

- **Construction**: Always use `jq -n --arg key "$val" '{...}'`. Never build JSON with string concatenation.
- **Extraction**: Use `jq -r '.field'` for string fields, `jq -cer` when strict validation is needed.
- **Payload assembly**: Use `--data-binary "$payload"` with curl to avoid shell interpretation.

### HTTP Requests

- Use `curl -fsS` (fail silently on HTTP errors, show errors on curl failures, silent progress).
- Always pipe through `jq` for response parsing.
- Backend-specific endpoints:
  - Ollama: `$(_autobashcmd_ollama_base_url)/api/chat`
  - LM Studio: `$(_autobashcmd_lmstudio_base_url)/chat/completions`
- Both paths set `temperature: 0` and `stream: false`.

### Control Flow Patterns

- **Early return on empty input**: `[[ -z "$var" ]] && return 1`
- **Case statements for Chinese NL patterns**: Preferred for fixed phrase matching (see `_autobashcmd_common_command_from_prompt`).
- **Fallback chains**: Local rules first → model classification → model generation. Always prefer deterministic local logic over model calls.
- **Retry with correction**: If model output is invalid, send a correction prompt with the previous (bad) output as context, then retry once. Do not retry more than once.

### Safety & Validation

- **Risky commands** (`_autobashcmd_is_risky_command`): `sudo`, `rm`, `mv`, `dd`, `chmod`, `chown`, `killall`, `kill -9`, `diskutil`, `mkfs`, `sed -i`, `perl -pi`, `launchctl unload`, `git reset --hard`, `git clean -fd`, pipe to `sh`/`bash`, redirects.
- **Command validation** (`_autobashcmd_is_valid_command`): Check with `zsh -n -c`, verify the primary command exists via `whence -w`, reject explanation-like text.
- When adding new risky command patterns, add them to `_autobashcmd_is_risky_command`.

### Error Handling

- Functions return non-zero on failure. Callers check with `|| return 1`.
- No `set -e`. Error propagation is manual via return codes and `setopt pipefail`.
- Use `2>/dev/null` for commands that may legitimately fail (e.g., `man`, `whatis`, `find`).
- Never swallow errors silently in the main dispatch path.

### Adding New Features

1. **New local fast-path rule**: Add a case to `_autobashcmd_common_command_from_prompt` or `_autobashcmd_directory_command_from_prompt`. These bypass model calls entirely.
2. **New intent type**: Would require changes to the classifier system prompt, `_autobashcmd_parse_classification`, and the dispatch switch in `_autobashcmd_dispatch_request`.
3. **New backend**: Follow the `if [[ "$backend" == "..." ]]` branching pattern used in `_autobashcmd_request_classifier`, `_autobashcmd_request_command`, and `_autobashcmd_request_text`.
4. **New risky command pattern**: Add to `_autobashcmd_is_risky_command`.

### Things to Avoid

- **Do not** use `echo` — always `print -r --`.
- **Do not** build JSON with string concatenation — always use `jq -n`.
- **Do not** add external dependencies beyond `zsh`, `curl`, `jq`, and standard Unix tools.
- **Do not** introduce subshell-heavy patterns in hot paths (each `$(...)` forks).
- **Do not** modify global shell state — every function uses `emulate -L zsh`.
- **Do not** add `set -e` or `setopt errexit` — the codebase relies on manual error propagation.
- **Do not** suppress errors by removing validation; fix the root cause instead.

## Dependencies

Runtime: `zsh`, `curl`, `jq`, standard Unix tools (`find`, `sed`, `awk`, `man`, `whatis`).
AI Backend: Ollama (`http://localhost:11434`) or LM Studio (`http://127.0.0.1:1234/v1`).

## Environment Variables

| Variable | Default | Purpose |
|---|---|---|
| `SHELL_AI_BACKEND` | `ollama` | Backend selection: `ollama` or `lmstudio` |
| `SHELL_AI_MODEL` | `gpt-oss:20b` | Model for command/classification |
| `SHELL_AI_TEXT_MODEL` | (same as MODEL) | Model for help/explain text |
| `SHELL_AI_DEBUG` | unset | Set to `1` to enable debug logging to stderr |
| `OLLAMA_BASE_URL` | `http://localhost:11434` | Ollama API base URL |
| `LMSTUDIO_BASE_URL` | `http://127.0.0.1:1234/v1` | LM Studio API base URL |

## File Map

```
AutoBashCMD/
├── AGENTS.md              ← this file
├── README.md.md           ← usage docs and design notes (Chinese)
└── shell/
    └── autobashcmd.zsh      ← entire implementation (≈1400 lines)
```
