# Decisions

## 2026-03-20 Install-guide pattern comparison

### 1) nvm-sh/nvm (v0.40.4)
- Install entry in README: yes (`Install & Update Script` section) with `curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash` and `wget` equivalent.
- Raw URL usage: yes, version pinned in URL.
- README install flow: auto install script + verification via `command -v nvm` + `Git Install` + `Manual Install` sections.
- Risk notes:
  - URL pinning lowers drift risk compared to `master`.
  - Non-interactive and automation use-cases are covered, but script must be trusted by users (manual inspection recommended).
- Useful URLs:
  - https://github.com/nvm-sh/nvm/blob/v0.40.4/README.md#install--update-script
  - https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/README.md
  - https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh

### 2) Homebrew/install
- Install entry in README: one-line installer command with raw.githubusercontent.com.
- Raw URL usage: yes, points to `HEAD/install.sh`.
- README install flow: one-click command + link to official docs; includes non-interactive install pattern (`NONINTERACTIVE=1 /bin/bash -c ...`).
- Risk notes:
  - `HEAD` URL can change behavior by default script updates; for reproducibility prefer commit/hash pinning in internal docs if needed.
  - Lacks explicit manual install section in this minimal README snippet; uses external docs for details.
- Useful URLs:
  - https://github.com/Homebrew/install/blob/master/README.md
  - https://raw.githubusercontent.com/Homebrew/install/HEAD/README.md
  - https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh

### 3) ohmyzsh/ohmyzsh
- Install entry in README: `Basic Installation` includes `sh -c` + `curl -fsSL` from `raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh`.
- Raw URL usage: yes, plus mirror fallback `https://install.ohmyz.sh/`.
- README install flow: auto command + `Manual Inspection` + `Advanced Installation` and explicit `Manual Installation` steps.
- Risk notes:
  - Uses `master` branch in raw URL; branch/head moves can create drift.
  - Already includes mirror fallback to reduce regional blocking risk.
- Useful URLs:
  - https://github.com/ohmyzsh/ohmyzsh/blob/master/README.md#basic-installation
  - https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/README.md
  - https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh

### Conclusions for AutoBashCMD
- Current style `https://raw.githubusercontent.com/chaodongzhang/AutoBashCMD/main/INSTALL_GUIDE.md` is aligned with common practice (agent-friendly single-copy install entry).
- Two-path pattern from examples is preferable: keep raw installer URL and add explicit backup path (manual steps + verification) to reduce trust/availability issues.
- Key gap vs mature patterns:
  - no mirror/offline fallback URL.
  - version-anchored installer URL is not available yet.
  - no explicit command for non-interactive/CI mode in README.
- Suggested improvement (documentation only): keep current auto path, add a `Manual Install` block and an install troubleshooting note (script download failure, checksum/URL check, mirror alternative).
