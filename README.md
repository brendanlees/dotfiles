# dotfiles

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
chezmoi init --apply brendanlees
```

on first run you'll be prompted to set your machine role. these role flags gate which config and packages are applied.

```
personal | work | homelab
```

chezmoi will detect the system environment automatically, and configure things accordingly based on the relevant machine role.

```
darwin | windows| linux
```

see [scoping](docs/scoping.md) for how to skip prompts with env vars or provision via ansible.

## architecture

```
.chezmoi.toml.tmpl              # config templating based on role and environment
.chezmoiexternal.toml.tmpl      # external dependencies (plugins, nvim config, harness configs, fonts)
.chezmoidata/                   # state/data files (system defaults, themes, packages etc)
.chezmoiscripts/
  run_once_before_*             # bootstrapping
  run_after_*                   # post-apply tooling
  */run_onchange_*              # environment-specific
.chezmoitemplates/              # chezmoi templating partials
dot_zshrc.tmpl                  # zsh config
dot_config/zsh/                 # aliases
dot_config/                     # xdg config
dot_local/bin/                  # user scripts
```


## docs

- [usage](docs/usage.md) — updating and installing
- [secrets](docs/secrets.md) — token and secrets (backed by bitwarden)
- [ssh](docs/ssh.md) — reproducable ssh config and keys (from bitwarden manifest file)
- [scoping](docs/scoping.md) — machine roles, skipping prompts, ansible usage
- [themes](docs/themes.md) — switching theme, adding new themes
- [file tracking](docs/file-tracking.md) — adding dotfiles to track
- [testing](docs/testing.md) — ci pipeline and branch testing
- [inspiration](docs/inspiration.md) — reference repos and tools
