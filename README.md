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

on first run you'll be prompted to set machine role. these role flags gate which config and packages are applied.

```
personal | work | homelab
```

chezmoi will detect the system environment automatically, and configure things accordingly based on the relevant machine role.

```
darwin | windows| linux
```

see [scoping](docs/scoping.md) for non-interactive options via env vars, ansible.

## architecture

```
.chezmoiroot                    # points chezmoi at home/
home/                           # deployable chezmoi source state
  .chezmoi.toml.tmpl            # role and environment config
  .chezmoiexternal.toml.tmpl    # plugins, harness configs, fonts
  .chezmoidata/                 # defaults, themes, package data
  .chezmoiscripts/              # bootstrap and post-apply automation
  .chezmoitemplates/            # shared template partials
  dot_config/                   # XDG configuration
  dot_local/bin/                # user scripts
agents/                         # ~/.agents config
tests/                          # repo-only tests
docs/                           # repo-only documentation
```

## docs

- [usage](docs/usage.md) — updating and installing
- [secrets](docs/secrets.md) — token and secrets (backed by bitwarden)
- [ssh](docs/ssh.md) — reproducable ssh config and keys (from bitwarden manifest file)
- [scoping](docs/scoping.md) — define machine roles, non-interactive options
- [themes](docs/themes.md) — global theming, how to switch and add new
- [file tracking](docs/file-tracking.md) — file tracking practices
- [testing](docs/testing.md) - ci pipeline and branch testing
- [private agent skills](docs/private-agent-skills.md) - sync/overlay additional private skills repo
- [inspiration](docs/inspiration.md) - reference repos and tools
