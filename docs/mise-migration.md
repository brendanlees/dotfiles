# mise Migration Guide

When applying these dotfiles to a machine that previously used the old install scripts,
mise will immediately take over tool management — but old binaries are left on disk.
mise's shims take PATH precedence, so tools work correctly without manual cleanup.
Cleanup is optional housekeeping to reclaim disk space and avoid confusion.

## Why cleanup is safe

`eval "$(mise activate zsh)"` uses shell hooks to prepend mise's tool directories to PATH. Any tool managed by mise will resolve to the mise-installed version in the active shell.

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
rm -f ~/.local/bin/lazydocker
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
# Confirm mise is managing tools
mise current

# List installed tools and versions
mise list

# Check mise health and configuration
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
