# AutoBashCMD

[English](README.md) | 中文

一个 zsh 插件，用本地 AI（Ollama / LM Studio）把自然语言转成 shell 命令。

不需要云服务，不需要 API Key，全部本地运行。

## 依赖

- `zsh`、`curl`、`jq`
- [Ollama](https://ollama.com) 或 [LM Studio](https://lmstudio.ai) 在本地运行
- 推荐模型：`qwen2.5-coder:3b` — 速度快、体积小、擅长生成 shell 命令
  ```bash
  ollama pull qwen2.5-coder:3b
  ```

## 安装

**Agent 安装**：把下面这个地址发给你的 coding agent（Claude Code、Cursor、Codex 等），它会自动完成所有安装步骤：

https://raw.githubusercontent.com/chaodongzhang/AutoBashCMD/main/INSTALL_GUIDE.md

**手动安装**：

```bash
git clone https://github.com/chaodongzhang/AutoBashCMD.git ~/.AutoBashCMD
```

在 `~/.zshrc` 中加一行：

```bash
source ~/.AutoBashCMD/shell/autobashcmd.zsh
```

然后重新加载：

```bash
source ~/.zshrc
```

## 用法

### `ai` — 生成命令

```bash
ai 列出当前目录下的文件
ai 找出占用 3000 端口的进程
ai 把当前目录压缩成 zip
```

只输出命令，不执行。

### `airun` — 生成并确认执行

```bash
airun 删除所有 .log 文件
```

先显示命令，回车执行，按其他键取消。危险命令（如 `rm`、`sudo`）需要输入 `yes` 确认。

### `aiexplain` — 解释命令

```bash
aiexplain grep -rn
aiexplain chmod 755 是什么意思
```

### 直接输入自然语言

在 shell 里直接打中文，会自动走 `airun` 流程：

```bash
列出当前目录下的文件
进入 src 目录
找出占用 3000 端口的进程
```

问命令用法也行：

```bash
ls这个命令如何使用
介绍一下 grep
rm 是什么意思
```

## 配置

| 变量 | 默认值 | 说明 |
|---|---|---|
| `SHELL_AI_BACKEND` | `ollama` | `ollama` 或 `lmstudio` |
| `SHELL_AI_MODEL` | `qwen2.5-coder:3b` | 命令生成用的模型 |
| `SHELL_AI_TEXT_MODEL` | 同 MODEL | 解释说明用的模型 |
| `SHELL_AI_DEBUG` | 未设置 | 设为 `1` 开启调试输出 |
| `OLLAMA_BASE_URL` | `http://localhost:11434` | Ollama API 地址 |
| `LMSTUDIO_BASE_URL` | `http://127.0.0.1:1234/v1` | LM Studio API 地址 |

### 切换后端

```bash
# 切到 LM Studio
export SHELL_AI_BACKEND=lmstudio
export SHELL_AI_MODEL=qwen3.5-9b-mlx

# 切回 Ollama
export SHELL_AI_BACKEND=ollama
export SHELL_AI_MODEL=qwen2.5-coder:3b
```

## 工作原理

1. **本地快速匹配**：高频请求（列目录、查 CPU 等）直接映射成固定命令，不调模型。
2. **意图分类**：模型把输入分成 `command`、`cd`、`help`、`reject` 四类。
3. **分流处理**：每种意图走对应的处理链——命令生成、目录解析、帮助文本、或拒绝。
4. **校验**：生成的命令会用 `zsh -n` 做语法检查、用 `whence` 验证命令是否存在。无效输出会带纠正提示重试一次。
5. **安全**：高风险命令（`rm`、`sudo`、`dd` 等）必须显式确认才执行。

## License

MIT
