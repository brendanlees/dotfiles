# dotfiles

my personal setup for macos, linux and windows environments, managed by [chezmoi](https://www.chezmoi.io/).

---

## approach

machine roles (`work/personal/homelab`) to scope, sync and distribute configuration across multiple operating systems, while also checking machine environment type (`desktop/headless`) to determine depth of configuration.

[mise](https://github.com/jdx/mise) for cross-platform CLI tools, package managers to cover system dependencies and desktop apps. configuration stays in each tool's native format, with chezmoi / go templating where a role or shared theme actually changes it.

tests to focus on bootstrap, role changes and scripts that can overwrite or remove files. CI to handle syntax and template validation. 

`agents/skills/` contains upstream [skills.sh](https://skills.sh/) skills, private harness configuration and private/custom skills live in external repositories.

custom distributed theming system to sync shell and (most) cli tooling.


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


## installation

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

update mise tools explicitly when convenient:

```sh
mise --cd "$HOME" self-update
mise --cd "$HOME" upgrade --exclude starship
mise --cd "$HOME" prune
```

## docs and reference notes

- [secrets](docs/secrets.md) - token and secrets integration (backed by bitwarden)
- [ssh](docs/ssh.md) - reproducible ssh config and keys (from a bitwarden manifest file)
- [scoping](docs/scoping.md) - define machine roles, non-interactive options
- [themes](docs/themes.md) - global theming, how to switch and add new
- [testing](docs/testing.md) - ci pipeline and branch testing
- [zsh performance](docs/zsh-perf.md) - documentation of small zsh/starship performance tweaks
