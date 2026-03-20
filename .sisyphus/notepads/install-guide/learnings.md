# Learnings

- 成功新增 `INSTALL_GUIDE.md`（7 个 Step，逐字使用计划文本）
- 在 `README.md` `## Installation` 之前的 `git clone` 块前插入 Agent 安装入口并保留手动安装流程。
- 在 `README_CN.md` `## 安装` 同样位置插入中文 Agent 安装入口并保留后续手动说明。
- 删除本地未跟踪文件 `install.sh`，未使用 `git rm`。
- 仅对 `INSTALL_GUIDE.md`、`README.md`、`README_CN.md` 进行单次提交：`docs: add agent installation guide and update READMEs`，并推送至 `origin main`。
- 生成 evidence：`task-1-install-guide-content.txt`、`task-1-readme-en.txt`、`task-1-readme-cn.txt`、`task-1-install-sh-deleted.txt`、`task-1-git-status.txt`。
- 关键命令：`rm install.sh`、`git add INSTALL_GUIDE.md README.md README_CN.md`、`git commit -m "docs: add agent installation guide and update READMEs"`、`git push origin main`。
