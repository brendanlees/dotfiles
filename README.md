k dotfiles

managed by [chezmoi](https://www.chezmoi.io/)

## install

**macos**

```sh
brew install chezmoi && chezmoi init --apply brendanlees
```

**linux**

```sh
sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply brendanlees
```

**windows**

```pwsh
winget install -e --id twpayne.chezmoi --accept-source-agreements --accept-package-agreements
# open a new terminal so chezmoi lands on PATH, then:
chezmoi init --apply brendanlees
```

on first run you'll be prompted to set your machine role. see [scoping](docs/scoping.md) to skip prompts or provision via ansible.

## architecture

```
.chezmoi.toml.tmpl              # template config — sets role flags (personal/work/homelab/ephemeral)
.chezmoiexternal.toml.tmpl      # external sources (zsh plugins, nvim config, claude config, fonts)
.chezmoidata/                   # data files (defaults, themes, packages); local.yml is host-local + gitignored
.chezmoiscripts/
  run_once_before_*             # bootstrap: install chezmoi deps, mise
  run_after_*                   # post-apply: install tools, tmux plugins
  darwin/run_onchange_*         # brew taps, packages, casks, mas, uv, npm globals
.chezmoitemplates/              # shared template partials
dot_zshrc.tmpl                  # zsh config
dot_config/zsh/                 # aliases.zsh.tmpl + exact_aliases.d/ (per-tool alias files)
dot_config/                     # xdg config (git, mise, starship, ghostty, …)
dot_local/bin/                  # user scripts (theme switcher, dpedit, …)
```

role flags gate which config and packages are applied per machine type.

## docs

- [usage](docs/usage.md) — updating, re-installing, tokens, agentic tool integration
- [ssh + bitwarden](docs/usage.md#ssh-config-and-keys-via-bitwarden) — local SSH config/key generation from a private Bitwarden manifest
- [scoping](docs/scoping.md) — machine roles, skipping prompts, ansible
- [themes](docs/themes.md) — switching theme, adding new themes
- [file tracking](docs/file-tracking.md) — adding dotfiles to track
- [testing](docs/testing.md) — ci pipeline and branch testing
- [inspiration](docs/inspiration.md) — reference repos and tools
