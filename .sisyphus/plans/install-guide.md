# 创建 Agent 安装指南并更新 README

## TL;DR

> **目标**: 创建 INSTALL_GUIDE.md（给 coding agent 的自动安装指南），更新两个 README 添加 Agent Install 入口，删除废弃的 install.sh，提交推送到 GitHub。
>
> **交付物**:
> - 新文件：`INSTALL_GUIDE.md`（7 步骤的 agent 安装指南）
> - 更新：`README.md`（添加 Agent Install 段落）
> - 更新：`README_CN.md`（添加 Agent 安装段落）
> - 删除：`install.sh`（本地未跟踪文件）
>
> **预估工作量**: Quick
> **并行执行**: NO — 2 个顺序 wave（实施 → 验证）
> **关键路径**: Task 1 → Task 2 → Final Verification

---

## Context

### Original Request
用户希望创建一个给 coding agent 阅读的安装指南。工作流程：用户复制 INSTALL_GUIDE.md 的 raw GitHub URL，粘贴给 agent，agent 自动按步骤安装 AutoBashCMD。唯一需要人工操作的是 `source ~/.zshrc` 或开新终端。

### Interview Summary
**关键讨论**:
- 选择 Markdown 指南而非 bash 脚本：agent 能用推理处理边界情况，比死板脚本更好
- install.sh 之前创建但方案已转向 MD 指南——用户确认删除
- INSTALL_GUIDE.md 内容已在之前对话中完整起草并确认（7 步骤）
- 两个 README 需要在 Installation/安装 段落添加 Agent Install 入口

**研究发现**:
- librarian 调研了 oh-my-zsh/nvm/Homebrew/zinit 的安装模式
- MD 指南方式是有意为之的设计选择

### Metis Review
**发现的问题（已处理）**:
- 必须用单个原子提交，避免 URL 失效窗口期
- install.sh 从未被 git 跟踪，删除只需 `rm`，不需要 `git rm`
- INSTALL_GUIDE.md 仅覆盖 Ollama 后端——这是有意设计，保持简单
- Step 5 需要处理 `~/.zshrc` 不存在的情况——内容中已通过 `2>/dev/null` 和 NEEDS_SETUP 分支处理
- 推送后 raw.githubusercontent.com 可能有几秒缓存延迟——QA 验证需带重试

---

## Work Objectives

### Core Objective
创建 agent 可读的安装指南并将其集成到项目 README 中，完成项目文档收尾。

### Concrete Deliverables
- `INSTALL_GUIDE.md` — 新文件，7 步骤的 agent 安装指南
- `README.md` — 在 Installation 段落添加 Agent Install 入口
- `README_CN.md` — 在安装段落添加 Agent 安装入口
- `install.sh` — 从本地删除
- 一个原子提交推送到 `origin/main`

### Definition of Done
- [x] `INSTALL_GUIDE.md` 存在且包含 7 个 `## Step` 段落
- [x] `README.md` 包含 Agent Install 文本和 raw GitHub URL
- [x] `README_CN.md` 包含 Agent 安装文本和 raw GitHub URL
- [x] `install.sh` 不存在
- [x] `git status --porcelain` 返回空（排除 `.sisyphus/` 的未跟踪产物）
- [x] `git status` 显示 "up to date with 'origin/main'"
- [x] raw GitHub URL 返回 HTTP 200

### Must Have
- INSTALL_GUIDE.md 包含完整的 7 个步骤（前置检查 → Ollama 检查 → 模型拉取 → 克隆仓库 → 配置 shell → 验证 → 告知用户）
- 两个 README 都有 raw GitHub URL 链接
- 所有变更在一个原子提交中

### Must NOT Have (Guardrails)
- **禁止修改 `shell/autobashcmd.zsh`** — 纯文档变更，零代码改动
- **禁止修改 `AGENTS.md`** — 不在范围内
- **禁止修改 `~/.zshrc`** — 不在范围内
- **禁止修改 `.gitignore`** — 不在范围内
- **禁止在 README 中添加 Agent Install 段落以外的内容** — 纯插入，不改现有内容
- **禁止拆分为多个提交** — 必须是单个原子提交
- **禁止创建新分支或 PR** — 直接推送到 main
- **禁止添加卸载指南、badges 或其他未请求的内容**

---

## Verification Strategy

> **零人工干预** — 所有验证由 agent 执行，无例外。

### Test Decision
- **测试基础设施**: 无
- **自动测试**: 无（纯文档变更）
- **框架**: N/A

### QA Policy
每个任务必须包含 agent 可执行的 QA 场景。
证据保存到 `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`。

- **文档/文件操作**: 使用 Bash — 检查文件存在、grep 内容、git 状态
- **URL 验证**: 使用 Bash (curl) — 发送请求、验证 HTTP 状态码

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (立即开始 — 基础):
└── Task 1: 创建 INSTALL_GUIDE.md + 更新 README + 删除 install.sh + 提交推送 [quick]

Wave 2 (Wave 1 完成后 — 推送后验证):
└── Task 2: 验证 raw GitHub URL 可访问 [quick]

Wave FINAL (所有任务完成后 — 4 个并行审查 + 用户确认):
├── F1: 计划合规审计 (oracle)
├── F2: 代码质量审查 (unspecified-high)
├── F3: 实际 QA (unspecified-high)
└── F4: 范围保真检查 (deep)
-> 呈现结果 -> 获得用户确认

关键路径: Task 1 → Task 2 → F1-F4 → 用户确认
```

### Dependency Matrix

| Task | Depends On | Blocks |
|------|------------|--------|
| 1 | — | 2, F1-F4 |
| 2 | 1 | F1-F4 |
| F1-F4 | 2 | — |

### Agent Dispatch Summary

- **Wave 1**: 1 个任务 — T1 → `quick` + `git-master`
- **Wave 2**: 1 个任务 — T2 → `quick`
- **FINAL**: 4 个任务 — F1 → `oracle`, F2 → `unspecified-high`, F3 → `unspecified-high`, F4 → `deep`

---

## TODOs

- [x] 1. 创建 INSTALL_GUIDE.md、更新两个 README、删除 install.sh、提交并推送

  **What to do**:

  **Step A — 创建 `INSTALL_GUIDE.md`**:

  在项目根目录创建 `INSTALL_GUIDE.md`，内容如下（完整文件内容，直接写入）：

  ````markdown
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

  - If this returns a model list → Ollama is running, proceed.
  - If this fails → Ollama is not running or not installed.
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
  ````

  **Step B — 更新 `README.md`**:

  在 `## Installation`（第 18 行）之后、现有 `git clone` 代码块（第 20 行）之前，插入以下内容：

  ```markdown
  **Agent Install**: Give this URL to your coding agent and it will handle everything automatically:

  ```
  https://raw.githubusercontent.com/chaodongzhang/AutoBashCMD/main/INSTALL_GUIDE.md
  ```

  **Manual Install**:

  ```

  确保现有的 `git clone` 代码块和后续内容不被删除或修改。

  具体编辑操作：找到 `## Installation\n\n```bash` 替换为包含 Agent Install 段落的新内容。

  **Step C — 更新 `README_CN.md`**:

  在 `## 安装`（第 18 行）之后、现有 `git clone` 代码块（第 20 行）之前，插入以下内容：

  ```markdown
  **Agent 安装**：把下面这个地址发给你的 coding agent（Claude Code、Cursor、Codex 等），它会自动完成所有安装步骤：

  ```
  https://raw.githubusercontent.com/chaodongzhang/AutoBashCMD/main/INSTALL_GUIDE.md
  ```

  **手动安装**：

  ```

  同样确保现有内容不被删除或修改。

  **Step D — 删除 `install.sh`**:

  ```bash
  rm install.sh
  ```

  注意：`install.sh` 从未被 git 跟踪，所以只需 `rm`，不需要 `git rm`。

  **Step E — 提交并推送**:

  ```bash
  git add INSTALL_GUIDE.md README.md README_CN.md
  git commit -m "docs: add agent installation guide and update READMEs"
  git push origin main
  ```

  **Must NOT do**:
  - 不要修改 `shell/autobashcmd.zsh`、`AGENTS.md`、`.gitignore` 或 `~/.zshrc`
  - 不要修改 README 中除 Installation/安装段落以外的任何内容
  - 不要拆分成多个提交
  - 不要创建新分支

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - 原因：纯文档操作，4 个文件变更 + git 提交推送，无复杂逻辑
  - **Skills**: [`git-master`]
    - `git-master`: 确保原子提交和推送操作正确

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 1（单独）
  - **Blocks**: Task 2, F1-F4
  - **Blocked By**: None（可立即开始）

  **References**:

  **Pattern References**:
  - `README.md:18-34` — 当前 Installation 段落，插入点在 line 18 之后、line 20 之前
  - `README_CN.md:18-34` — 当前安装段落，同样的插入模式

  **Content References**:
  - 之前会话 `ses_2f61b9842ffen09fIuXOAX95h0` 中起草的完整 INSTALL_GUIDE.md 内容（已包含在上方 Step A 中）
  - Metis review 建议在 Step 5 增加 `touch ~/.zshrc` 处理文件不存在的情况（已纳入）

  **External References**:
  - GitHub 仓库: https://github.com/chaodongzhang/AutoBashCMD
  - Raw URL: https://raw.githubusercontent.com/chaodongzhang/AutoBashCMD/main/INSTALL_GUIDE.md

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: INSTALL_GUIDE.md 创建成功且内容完整
    Tool: Bash
    Preconditions: 项目根目录
    Steps:
      1. test -f INSTALL_GUIDE.md — 文件存在
      2. grep -c "^## Step" INSTALL_GUIDE.md — 计数 Step 标题
      3. grep -q "Check Prerequisites" INSTALL_GUIDE.md — Step 1 存在
      4. grep -q "Tell the User" INSTALL_GUIDE.md — Step 7 存在
      5. grep -q "touch ~/.zshrc" INSTALL_GUIDE.md — Metis 建议的改进存在
    Expected Result: 文件存在，7 个 Step 标题，所有关键内容存在
    Failure Indicators: 文件不存在、Step 数量不是 7、缺少关键段落
    Evidence: .sisyphus/evidence/task-1-install-guide-content.txt

  Scenario: README.md Agent Install 段落正确插入
    Tool: Bash
    Preconditions: README.md 已编辑
    Steps:
      1. grep -q "Agent Install" README.md — 新段落存在
      2. grep -q "raw.githubusercontent.com/chaodongzhang/AutoBashCMD/main/INSTALL_GUIDE.md" README.md — URL 正确
      3. grep -q "Manual Install" README.md — 手动安装标签存在
      4. grep -q "git clone" README.md — 原有 git clone 命令未被删除
      5. grep -q "source ~/.zshrc" README.md — 原有 source 命令未被删除
    Expected Result: 所有 grep 匹配成功
    Failure Indicators: 缺少新段落、URL 错误、原有内容被删除
    Evidence: .sisyphus/evidence/task-1-readme-en.txt

  Scenario: README_CN.md Agent 安装段落正确插入
    Tool: Bash
    Preconditions: README_CN.md 已编辑
    Steps:
      1. grep -q "Agent 安装" README_CN.md — 新段落存在
      2. grep -q "raw.githubusercontent.com/chaodongzhang/AutoBashCMD/main/INSTALL_GUIDE.md" README_CN.md — URL 正确
      3. grep -q "手动安装" README_CN.md — 手动安装标签存在
      4. grep -q "git clone" README_CN.md — 原有内容未被删除
    Expected Result: 所有 grep 匹配成功
    Failure Indicators: 缺少新段落、URL 错误、原有内容被删除
    Evidence: .sisyphus/evidence/task-1-readme-cn.txt

  Scenario: install.sh 已删除
    Tool: Bash
    Preconditions: 项目根目录
    Steps:
      1. test ! -f install.sh && echo "PASS" || echo "FAIL"
    Expected Result: PASS
    Failure Indicators: install.sh 仍然存在
    Evidence: .sisyphus/evidence/task-1-install-sh-deleted.txt

  Scenario: Git 状态 — 单个原子提交且已推送
    Tool: Bash
    Preconditions: 所有文件操作已完成
    Steps:
      1. git status --porcelain — 应为空
      2. git log --oneline -1 — 应显示新提交
      3. git status — 应显示 "up to date with 'origin/main'"
      4. git diff HEAD~1 --name-status — 应只有 A INSTALL_GUIDE.md, M README.md, M README_CN.md
    Expected Result: 干净状态、单个提交、已推送、仅 3 个文件变更
    Failure Indicators: 有未提交文件、未推送、包含非预期文件
    Evidence: .sisyphus/evidence/task-1-git-status.txt
  ```

  **Evidence to Capture:**
  - [ ] task-1-install-guide-content.txt
  - [ ] task-1-readme-en.txt
  - [ ] task-1-readme-cn.txt
  - [ ] task-1-install-sh-deleted.txt
  - [ ] task-1-git-status.txt

  **Commit**: YES
  - Message: `docs: add agent installation guide and update READMEs`
  - Files: `INSTALL_GUIDE.md`, `README.md`, `README_CN.md`
  - Pre-commit: 无

- [x] 2. 验证 raw GitHub URL 可访问

  **What to do**:
  推送完成后等待 5 秒，然后用 curl 验证 raw GitHub URL 返回 HTTP 200。如果首次返回 404，等待 10 秒后重试一次（GitHub CDN 缓存延迟）。

  **Must NOT do**:
  - 不要修改任何文件
  - 不要执行任何 git 操作

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - 原因：单条 curl 命令验证，无文件操作
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 2（Task 1 完成后）
  - **Blocks**: F1-F4
  - **Blocked By**: Task 1

  **References**:
  - Raw URL: `https://raw.githubusercontent.com/chaodongzhang/AutoBashCMD/main/INSTALL_GUIDE.md`
  - Metis 指出 raw.githubusercontent.com 推送后可能有几秒缓存延迟

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Raw GitHub URL 返回 HTTP 200
    Tool: Bash (curl)
    Preconditions: Task 1 已完成（提交已推送）
    Steps:
      1. sleep 5
      2. curl -fsS -o /dev/null -w "%{http_code}" https://raw.githubusercontent.com/chaodongzhang/AutoBashCMD/main/INSTALL_GUIDE.md
      3. 如果返回 404，sleep 10 后重试一次
    Expected Result: HTTP 200
    Failure Indicators: 持续返回 404 或其他非 200 状态码
    Evidence: .sisyphus/evidence/task-2-url-validation.txt

  Scenario: URL 内容包含预期的 Step 标题
    Tool: Bash (curl)
    Preconditions: URL 可访问
    Steps:
      1. curl -fsS https://raw.githubusercontent.com/chaodongzhang/AutoBashCMD/main/INSTALL_GUIDE.md | grep -c "^## Step"
    Expected Result: 输出 7
    Failure Indicators: 输出不是 7，或 curl 失败
    Evidence: .sisyphus/evidence/task-2-url-content.txt
  ```

  **Evidence to Capture:**
  - [ ] task-2-url-validation.txt
  - [ ] task-2-url-content.txt

  **Commit**: NO

---

## Final Verification Wave (MANDATORY — 所有实施任务完成后)

> 4 个审查 agent 并行运行。全部必须 APPROVE。将合并结果呈现给用户并获得明确 "okay" 后才能完成。

- [x] F1. **Plan Compliance Audit** — `oracle`
  读取本计划，逐项检查 Must Have：验证 INSTALL_GUIDE.md 存在且有 7 个 Step 段落、README.md 包含 Agent Install 文本、README_CN.md 包含 Agent 安装文本、install.sh 已删除。逐项检查 Must NOT Have：搜索是否有被禁止的改动（autobashcmd.zsh、AGENTS.md、.gitignore 等）。检查 `.sisyphus/evidence/` 中证据文件。
  输出: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [x] F2. **Code Quality Review** — `unspecified-high`
  检查所有变更文件的 Markdown 格式：代码块嵌套正确、链接语法正确、无 broken links。验证 INSTALL_GUIDE.md 中的 bash 代码块语法。检查 README 插入点前后内容完整（未丢失或覆盖现有内容）。
  输出: `Markdown [PASS/FAIL] | Links [PASS/FAIL] | Content Integrity [N/N] | VERDICT`

- [x] F3. **Real Manual QA** — `unspecified-high`
  执行每个任务的 QA 场景：检查文件存在、grep 关键内容、验证 git 状态、curl 测试 raw URL。保存到 `.sisyphus/evidence/final-qa/`。
  输出: `Scenarios [N/N pass] | VERDICT`

- [x] F4. **Scope Fidelity Check** — `deep`
  检查 `git diff HEAD~1` — 验证变更仅包含 INSTALL_GUIDE.md（新增）、README.md（修改）、README_CN.md（修改），无其他文件。验证 install.sh 在工作目录中不存在。检测是否有超出范围的改动。
  输出: `Files [N/N compliant] | Scope [CLEAN/N issues] | VERDICT`

---

## Commit Strategy

- **单个原子提交**: `docs: add agent installation guide and update READMEs`
  - A: `INSTALL_GUIDE.md`
  - M: `README.md`
  - M: `README_CN.md`
  - 注意: `install.sh` 从未被跟踪，`rm` 删除即可，不进入 commit
  - Pre-commit: 无（纯文档）
  - Push: `git push origin main`

---

## Success Criteria

### Verification Commands
```bash
# INSTALL_GUIDE.md 有 7 个步骤
grep -c "^## Step" INSTALL_GUIDE.md  # Expected: 7

# README.md 有 Agent Install
grep "Agent Install" README.md  # Expected: 匹配

# README_CN.md 有 Agent 安装
grep "Agent 安装" README_CN.md  # Expected: 匹配

# install.sh 已删除
test ! -f install.sh && echo "PASS"  # Expected: PASS

# Git 状态干净
git status --porcelain  # Expected: 空

# 已推送
git status  # Expected: up to date with 'origin/main'

# URL 可访问
curl -fsS -o /dev/null -w "%{http_code}" https://raw.githubusercontent.com/chaodongzhang/AutoBashCMD/main/INSTALL_GUIDE.md  # Expected: 200
```

### Final Checklist
- [x] All "Must Have" present
- [x] All "Must NOT Have" absent
- [x] Git clean, pushed, URL live
