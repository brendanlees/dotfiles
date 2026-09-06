# dotfiles

my macOS, Linux and Windows configuration, managed by [chezmoi](https://www.chezmoi.io/).

## approach

I use machine roles to share the common parts without forcing desktop configuration onto servers. mise owns cross-platform CLI tools; OS package managers cover system dependencies and desktop apps. Most configuration stays in each tool's native format, with templates where a role or shared theme actually changes it.

Tests focus on bootstrap, role changes and scripts that can overwrite or remove files. CI handles syntax and template validation. The aim is a useful personal setup, not a general-purpose dotfiles framework.

**These are personal dotfiles, not a starter kit.** They include private service references and opinionated package choices. Read the role configuration and preview changes before applying them to another machine.

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
darwin | windows | linux
```

see [scoping](docs/scoping.md) for non-interactive options via env vars, ansible.

## maintenance

`chezmoi apply` updates configuration and installs missing global tools. It does not upgrade mise, upgrade installed tools or prune old versions. Theme switching also skips package scripts and external repository updates.

update tools explicitly when convenient:

```sh
mise --cd "$HOME" self-update
mise --cd "$HOME" upgrade --exclude starship
mise --cd "$HOME" prune
```

on Linux aarch64 hosts using the static musl build, prefix self-update with `MISE_LIBC=musl`. Upgrade the active prompt separately with `mise-upgrade-starship`, then start a new shell. Removing a package from the dotfiles does not automatically uninstall an existing copy.

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
agents/                         # shared agent instructions and upstream skills
tests/                          # repo-only tests
docs/                           # repo-only documentation
```

`agents/skills/` contains upstream [skills.sh](https://skills.sh/) packages, not a portfolio of skills authored here. Private harness configuration and homelab skills live in separate repositories.

## docs

- [secrets](docs/secrets.md) - token and secrets (backed by bitwarden)
- [ssh](docs/ssh.md) - reproducible ssh config and keys (from bitwarden manifest file)
- [scoping](docs/scoping.md) - define machine roles, non-interactive options
- [themes](docs/themes.md) - global theming, how to switch and add new
- [testing](docs/testing.md) - ci pipeline and branch testing
- [zsh performance](docs/zsh-perf.md) - documentation of small zsh/starship performance tweaks
