# mise Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace per-tool chezmoi install scripts with mise as the host tool manager for starship, zoxide, lazygit, lazydocker, neovim, and eza on both macOS and Linux.

**Architecture:** chezmoi bootstraps mise via a new `run_once` script, deploys `~/.config/mise/config.toml` with the tool list, then a second `run_once` script runs `mise install`. All existing per-tool install templates and `run_onchange` update scripts are deleted. mise's shell activation replaces scattered PATH entries.

**Tech Stack:** chezmoi (dotfiles manager), mise (tool version manager), zsh

**Working directory for all tasks:** `/Users/brendan/.local/share/chezmoi/.worktrees/mise-experiment`

---

## File Map

| Action | Path | Purpose |
|---|---|---|
| Create | `dot_config/mise/config.toml` | mise tool list — deployed to `~/.config/mise/config.toml` |
| Create | `.chezmoiscripts/run_once_install_mise.sh.tmpl` | Bootstrap: installs mise binary |
| Create | `.chezmoiscripts/run_once_install_tools.sh.tmpl` | Installs all tools via `mise install` |
| Create | `docs/mise-migration.md` | Per-machine cleanup guide for existing installs |
| Modify | `dot_zshrc.tmpl` | Add `eval "$(mise activate zsh)"` |
| Modify | `.chezmoiscripts/run_once_install_deps.sh.tmpl` | Remove tool install template calls |
| Modify | `.chezmoiexternal.toml.tmpl` | Remove neovim Linux binary block |
| Delete | `.chezmoitemplates/install-eza.sh.tmpl` | Replaced by mise |
| Delete | `.chezmoitemplates/install-starship.sh.tmpl` | Replaced by mise |
| Delete | `.chezmoitemplates/install-zoxide.sh.tmpl` | Replaced by mise |
| Delete | `.chezmoitemplates/install-lazyapps.sh.tmpl` | Replaced by mise |
| Delete | `.chezmoitemplates/install-nvim.sh.tmpl` | Replaced by mise |
| Delete | `.chezmoiscripts/run_onchange_update-lazygit.sh.tmpl` | Replaced by `mise upgrade` |
| Delete | `.chezmoiscripts/run_onchange_update-lazydocker.sh.tmpl` | Replaced by `mise upgrade` |

---

### Task 1: Create mise config

**Files:**
- Create: `dot_config/mise/config.toml`

- [ ] **Step 1: Create the directory**

```bash
mkdir -p dot_config/mise
```

- [ ] **Step 2: Create the config file**

Create `dot_config/mise/config.toml` with this content:

```toml
[tools]
neovim = "0.10.4"     # pinned — bump manually when ready to upgrade
starship = "latest"
zoxide = "latest"
lazygit = "latest"
lazydocker = "latest"
eza = "latest"
```

- [ ] **Step 3: Verify chezmoi sees the new file**

```bash
chezmoi diff
```

Expected: output includes `+` lines for `~/.config/mise/config.toml` with the tool list.

- [ ] **Step 4: Commit**

```bash
git add dot_config/mise/config.toml
git commit -m "feat: add mise config with host tool list"
```

---

### Task 2: Add mise bootstrap script

**Files:**
- Create: `.chezmoiscripts/run_once_install_mise.sh.tmpl`

The script naming `run_once_install_mise` puts it alphabetically after `run_once_install_deps` and before `run_once_install_tools`, which is the required execution order.

- [ ] **Step 1: Create the script**

Create `.chezmoiscripts/run_once_install_mise.sh.tmpl` with this content:

```bash
#!/bin/bash

# ------------------------------------------
# install > mise (tool version manager)
# ------------------------------------------

if command -v mise &>/dev/null; then
  echo "mise already installed, skipping."
  exit 0
fi

echo "installing mise..."
curl https://mise.run | sh

echo "mise installed to ~/.local/bin/mise"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x .chezmoiscripts/run_once_install_mise.sh.tmpl
```

- [ ] **Step 3: Verify chezmoi template parses cleanly**

```bash
chezmoi execute-template < .chezmoiscripts/run_once_install_mise.sh.tmpl
```

Expected: the script content printed with no template errors (no `{{` blocks in this file, so output should match input exactly).

- [ ] **Step 4: Commit**

```bash
git add .chezmoiscripts/run_once_install_mise.sh.tmpl
git commit -m "feat: add mise bootstrap install script"
```

---

### Task 3: Add mise tool install script

**Files:**
- Create: `.chezmoiscripts/run_once_install_tools.sh.tmpl`

This runs after mise is installed and `~/.config/mise/config.toml` is deployed by chezmoi.

- [ ] **Step 1: Create the script**

Create `.chezmoiscripts/run_once_install_tools.sh.tmpl` with this content:

```bash
#!/bin/bash

# ------------------------------------------
# install > mise tools (runs after mise bootstrap)
# ------------------------------------------

MISE="$HOME/.local/bin/mise"

if [ ! -f "$MISE" ]; then
  echo "mise not found at $MISE, skipping tool install."
  exit 1
fi

echo "installing mise tools..."
"$MISE" install

echo "mise tools installed."
```

Using the explicit path `~/.local/bin/mise` because chezmoi scripts run in a non-interactive shell where `mise` may not be on PATH yet.

- [ ] **Step 2: Make it executable**

```bash
chmod +x .chezmoiscripts/run_once_install_tools.sh.tmpl
```

- [ ] **Step 3: Verify template parses cleanly**

```bash
chezmoi execute-template < .chezmoiscripts/run_once_install_tools.sh.tmpl
```

Expected: script content printed with no template errors.

- [ ] **Step 4: Commit**

```bash
git add .chezmoiscripts/run_once_install_tools.sh.tmpl
git commit -m "feat: add mise tool install script"
```

---

### Task 4: Add mise shell activation to zshrc

**Files:**
- Modify: `dot_zshrc.tmpl`

- [ ] **Step 1: Add mise activation after the `~/.local/bin` PATH entry**

Open `dot_zshrc.tmpl`. Find this block:

```bash
# ------------------------------------------
# zoxide (cd)
# ------------------------------------------

export PATH=$HOME/.local/bin:$PATH
eval "$(zoxide init --cmd cd zsh)"
```

Add the mise activation immediately after the PATH line, before the zoxide init:

```bash
# ------------------------------------------
# zoxide (cd)
# ------------------------------------------

export PATH=$HOME/.local/bin:$PATH
eval "$(mise activate zsh)"
eval "$(zoxide init --cmd cd zsh)"
```

- [ ] **Step 2: Verify the template renders cleanly**

```bash
chezmoi execute-template < dot_zshrc.tmpl > /dev/null
```

Expected: no output, exit code 0 (no template errors).

- [ ] **Step 3: Verify chezmoi diff shows only the added line**

```bash
chezmoi diff dot_zshrc.tmpl
```

Expected: diff shows one added line (`+eval "$(mise activate zsh)"`), nothing else changed.

- [ ] **Step 4: Commit**

```bash
git add dot_zshrc.tmpl
git commit -m "feat: add mise shell activation to zshrc"
```

---

### Task 5: Simplify run_once_install_deps

**Files:**
- Modify: `.chezmoiscripts/run_once_install_deps.sh.tmpl`

Remove all tool install template calls. The Linux block keeps only apt system packages and `init-defaults`. The macOS block (currently just a comment) stays untouched. The "all platforms" block at the bottom is removed entirely.

- [ ] **Step 1: Replace the file contents**

Replace `.chezmoiscripts/run_once_install_deps.sh.tmpl` with:

```bash
#!/bin/bash

# ------------------------------------------
# linux
# ------------------------------------------

{{ if eq .chezmoi.os "linux" -}}

# --- root user --- #

{{ if eq .chezmoi.username "root" -}}

# prep package manager
apt update && apt upgrade -y && apt autoremove

# install packages
apt install -y zsh git nano bat fd-find btop tmux ncdu

# check/run package installer modules
{{ template "install-fzf.sh.tmpl" . }}
{{ end -}}

# --- all users --- #

{{ template "init-defaults.sh.tmpl" . }}
{{ end -}}

# ------------------------------------------
# mac os
# ------------------------------------------

{{ if eq .chezmoi.os "darwin" }}
# nothing needed here yet
{{ end -}}
```

- [ ] **Step 2: Verify the template renders cleanly on macOS**

```bash
chezmoi execute-template < .chezmoiscripts/run_once_install_deps.sh.tmpl
```

Expected: renders without errors. The linux block will be empty on macOS (correct).

- [ ] **Step 3: Verify chezmoi diff shows no unexpected file changes**

```bash
chezmoi diff
```

Expected: diff only shows changes to `~/.zshrc` and `~/.config/mise/config.toml` from previous tasks. The install_deps script itself doesn't produce a diff (it's a script, not a deployed file).

- [ ] **Step 4: Commit**

```bash
git add .chezmoiscripts/run_once_install_deps.sh.tmpl
git commit -m "chore: simplify install_deps — remove tool installs now handled by mise"
```

---

### Task 6: Remove neovim binary from chezmoiexternal

**Files:**
- Modify: `.chezmoiexternal.toml.tmpl`

Remove the Linux-only neovim binary block. mise manages neovim cross-platform from this point.

- [ ] **Step 1: Remove the neovim block**

Open `.chezmoiexternal.toml.tmpl`. Find and remove this entire block at the bottom of the file:

```
{{- if eq .chezmoi.os "linux" }}

# neovim binary bundle — extracts bin/nvim to ~/.local/bin/nvim (already in PATH)
[".local"]
type = "archive"
{{- if eq .chezmoi.arch "arm64" }}
url = "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-arm64.tar.gz"
{{- else }}
url = "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
{{- end }}
stripComponents = 1
refreshPeriod = "168h"

{{- end }}
```

The file should now end after the `[".tmux/plugins/tpm"]` block.

- [ ] **Step 2: Verify the template renders cleanly**

```bash
chezmoi execute-template < .chezmoiexternal.toml.tmpl
```

Expected: valid TOML output with no neovim block, no template errors.

- [ ] **Step 3: Commit**

```bash
git add .chezmoiexternal.toml.tmpl
git commit -m "chore: remove neovim binary from chezmoiexternal — now managed by mise"
```

---

### Task 7: Delete obsolete install templates

**Files:**
- Delete: `.chezmoitemplates/install-eza.sh.tmpl`
- Delete: `.chezmoitemplates/install-starship.sh.tmpl`
- Delete: `.chezmoitemplates/install-zoxide.sh.tmpl`
- Delete: `.chezmoitemplates/install-lazyapps.sh.tmpl`
- Delete: `.chezmoitemplates/install-nvim.sh.tmpl`

- [ ] **Step 1: Delete the files**

```bash
git rm .chezmoitemplates/install-eza.sh.tmpl \
       .chezmoitemplates/install-starship.sh.tmpl \
       .chezmoitemplates/install-zoxide.sh.tmpl \
       .chezmoitemplates/install-lazyapps.sh.tmpl \
       .chezmoitemplates/install-nvim.sh.tmpl
```

- [ ] **Step 2: Verify no remaining scripts reference the deleted templates**

```bash
grep -r "install-eza\|install-starship\|install-zoxide\|install-lazyapps\|install-nvim" .chezmoiscripts/ .chezmoitemplates/
```

Expected: no output (no remaining references).

- [ ] **Step 3: Verify chezmoi templates still render cleanly**

```bash
chezmoi execute-template < .chezmoiscripts/run_once_install_deps.sh.tmpl
```

Expected: renders without errors.

- [ ] **Step 4: Commit**

```bash
git commit -m "chore: delete obsolete tool install templates — replaced by mise"
```

---

### Task 8: Delete obsolete update scripts

**Files:**
- Delete: `.chezmoiscripts/run_onchange_update-lazygit.sh.tmpl`
- Delete: `.chezmoiscripts/run_onchange_update-lazydocker.sh.tmpl`

- [ ] **Step 1: Delete the files**

```bash
git rm .chezmoiscripts/run_onchange_update-lazygit.sh.tmpl \
       .chezmoiscripts/run_onchange_update-lazydocker.sh.tmpl
```

- [ ] **Step 2: Verify the scripts directory looks clean**

```bash
ls .chezmoiscripts/
```

Expected output (only these files remain):
```
run_after_install.sh.tmpl
run_once_install_deps.sh.tmpl
run_once_install_mise.sh.tmpl
run_once_install_tools.sh.tmpl
```

- [ ] **Step 3: Commit**

```bash
git commit -m "chore: delete run_onchange update scripts — replaced by mise upgrade"
```

---

### Task 9: Write migration guide

**Files:**
- Create: `docs/mise-migration.md`

- [ ] **Step 1: Create the docs directory if needed**

```bash
mkdir -p docs
```

- [ ] **Step 2: Create the migration guide**

Create `docs/mise-migration.md` with this content:

```markdown
# mise Migration Guide

When applying these dotfiles to a machine that previously used the old install scripts,
mise will immediately take over tool management — but old binaries are left on disk.
mise's shims take PATH precedence, so tools work correctly without manual cleanup.
Cleanup is optional housekeeping to reclaim disk space and avoid confusion.

## Why cleanup is safe

`eval "$(mise activate zsh)"` prepends mise's shim directory to PATH. Any tool managed
by mise will resolve to the mise-managed version regardless of what else is installed.

## macOS

Remove tools previously installed via Homebrew:

```bash
brew uninstall lazygit lazydocker neovim starship zoxide eza
```

Fonts and casks (font-monaspace-nerd-font, font-noto-sans-symbols-2) stay — mise
does not manage these.

## Linux

Remove tools previously installed to `~/.local/bin` by the old curl scripts:

```bash
rm -f ~/.local/bin/lazygit
rm -f ~/.local/bin/zoxide
rm -f ~/.local/bin/nvim
rm -f ~/.local/bin/starship
```

Remove eza (previously installed via apt repo):

```bash
sudo apt remove eza

# Optionally remove the apt repo and key:
sudo rm /etc/apt/sources.list.d/gierens.list
sudo rm /etc/apt/keyrings/gierens.gpg
sudo apt update
```

## Verifying mise is working

After applying dotfiles and opening a new shell:

```bash
# Confirm mise shims are active
which nvim      # should show ~/.local/share/mise/shims/nvim
which starship  # should show ~/.local/share/mise/shims/starship

# List installed tools and versions
mise list

# Check for any tools not yet installed
mise doctor
```

## Machine-local version overrides

To pin a tool to a different version on one machine without changing the dotfiles,
create `~/.config/mise/config.local.toml` (not tracked by chezmoi):

```toml
[tools]
neovim = "0.9.5"
```

## Per-project Node version pinning

Add a `.mise.toml` in the project root (not in the dotfiles repo):

```toml
[tools]
node = "22.12.0"
```

mise auto-activates this version when you `cd` into the directory.

## Upgrading tools

```bash
# Upgrade all latest-tracked tools
mise upgrade

# Upgrade a specific tool
mise upgrade lazygit

# Upgrade neovim (pinned — edit config first)
# 1. Edit ~/.config/mise/config.toml and bump the version
# 2. chezmoi add ~/.config/mise/config.toml
# 3. git commit + chezmoi apply
# 4. mise install
```
```

- [ ] **Step 3: Commit**

```bash
git add docs/mise-migration.md
git commit -m "docs: add mise migration guide for existing machines"
```

---

## Self-Review Checklist

Spec requirements vs tasks:

| Spec requirement | Task |
|---|---|
| mise bootstrap script (curl install) | Task 2 |
| `~/.config/mise/config.toml` with tool list | Task 1 |
| neovim pinned, others latest | Task 1 |
| run_once_install_tools runs `mise install` | Task 3 |
| `eval "$(mise activate zsh)"` in zshrc | Task 4 |
| install_deps simplified | Task 5 |
| neovim removed from chezmoiexternal | Task 6 |
| 5 install templates deleted | Task 7 |
| 2 run_onchange scripts deleted | Task 8 |
| Migration guide | Task 9 |
| install-fzf.sh.tmpl stays | ✓ not touched |
| install-tmux-plugins.sh.tmpl stays | ✓ not touched |
| init-defaults.sh.tmpl stays | ✓ kept in install_deps |
| run_after_install.sh.tmpl stays | ✓ not touched |
