# mise Integration Design

**Date:** 2026-03-28
**Branch:** mise-experiment
**Status:** Approved

## Overview

Replace per-tool install scripts and update scripts in the chezmoi dotfiles with mise as the host tool manager. mise handles installs, version pinning, and upgrades for all CLI dev tools on both macOS and Linux. Homebrew remains for casks, fonts, and system-level packages it already manages.

## Scope

### Moves to mise

| Tool | macOS (before) | Linux (before) |
|---|---|---|
| starship | curl install script | curl install script |
| zoxide | brew | curl install script |
| lazygit | brew | run_onchange script |
| lazydocker | brew | run_onchange script |
| neovim | brew | .chezmoiexternal.toml binary |
| eza | brew | apt repo + GPG setup |

### Stays unchanged

- **fzf** — `.chezmoiexternal.toml` (shell integration via `~/.fzf/install --all`)
- **zsh plugins** — `.chezmoiexternal.toml` (sourced shell scripts, not binaries)
- **tpm + tmux plugins** — `.chezmoiexternal.toml`
- **Neovim config (astronvim)** — `.chezmoiexternal.toml`
- **Fonts** — Homebrew casks (macOS only)
- **System packages** — apt on Linux (zsh, git, tmux, ncdu, btop, bat, fd-find, nano)

## Architecture

```
chezmoi apply
│
├── deploys dot_config/mise/config.toml     ← new, chezmoi-managed
│
├── run_once_install_deps.sh.tmpl           ← simplified (apt system packages + zsh default only)
├── run_once_install_mise.sh.tmpl           ← new: installs mise binary via curl
├── run_once_install_tools.sh.tmpl          ← new: runs `mise install`
│
├── run_after_install.sh.tmpl               ← unchanged (fzf setup, bat theme cache)
│
└── dot_zshrc.tmpl                          ← add `eval "$(mise activate zsh)"`
```

Script naming is deliberate — alphabetical execution order gives the correct dependency chain:
`install_deps` → `install_mise` → `install_tools`

## mise Config

`dot_config/mise/config.toml` → deployed to `~/.config/mise/config.toml`:

```toml
[tools]
neovim = "0.10.4"     # pinned — bump manually when ready to upgrade
starship = "latest"
zoxide = "latest"
lazygit = "latest"
lazydocker = "latest"
eza = "latest"
```

Neovim is pinned; all other tools track latest. To upgrade neovim: bump the version in config.toml, commit, and run `chezmoi apply` — mise installs the new version. To upgrade all other tools: `mise upgrade` from anywhere.

### Machine-local overrides

To hold a specific tool to a different version on one machine without changing the dotfiles, create `~/.config/mise/config.local.toml` (not managed by chezmoi):

```toml
[tools]
neovim = "0.9.5"
```

### Per-project Node pinning

Add `.mise.toml` directly in project directories (outside dotfiles repo):

```toml
[tools]
node = "22.12.0"
```

mise auto-activates when `cd`-ing into the project. The Astro project (`stdy-astro-superpowers`) requires `node >= 22.12.0` and is the primary candidate.

## Shell Activation

Add to `dot_zshrc.tmpl` after the `~/.local/bin` PATH entry:

```bash
eval "$(mise activate zsh)"
```

The existing `starship init` and `zoxide init` calls stay unchanged — they are runtime hooks, not PATH entries. mise's activation prepends its shims directory to PATH, taking precedence over any legacy installs.

## File Changes

### New files
- `dot_config/mise/config.toml`
- `.chezmoiscripts/run_once_install_mise.sh.tmpl`
- `.chezmoiscripts/run_once_install_tools.sh.tmpl`

### Modified files
- `.chezmoiscripts/run_once_install_deps.sh.tmpl` — remove tool install template calls; keep apt system packages and `init-defaults.sh.tmpl`
- `.chezmoiexternal.toml.tmpl` — remove neovim Linux binary block
- `dot_zshrc.tmpl` — add `eval "$(mise activate zsh)"`

### Deleted files
- `.chezmoitemplates/install-eza.sh.tmpl`
- `.chezmoitemplates/install-starship.sh.tmpl`
- `.chezmoitemplates/install-zoxide.sh.tmpl`
- `.chezmoitemplates/install-lazyapps.sh.tmpl`
- `.chezmoitemplates/install-nvim.sh.tmpl`
- `.chezmoiscripts/run_onchange_update-lazygit.sh.tmpl`
- `.chezmoiscripts/run_onchange_update-lazydocker.sh.tmpl`

## Migration on Existing Machines

See `docs/mise-migration.md` for the per-machine cleanup guide.

Summary: mise's shims take PATH precedence immediately on apply. Old binaries stay on disk until manually removed — they do not cause breakage but waste space.

- **macOS:** `brew uninstall lazygit lazydocker neovim starship zoxide eza`
- **Linux `~/.local/bin`:** manually remove `lazygit`, `zoxide`, `nvim`, `starship`
- **Linux eza:** `apt remove eza` (and optionally remove the apt repo/key)
