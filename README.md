# dotfiles

my personal setup for macos, linux and windows environments, managed by [chezmoi](https://www.chezmoi.io/).

---

## approach

- machine roles (`work/personal/homelab`) to scope, sync and distribute configuration across multiple operating systems, while also checking machine environment type (`desktop/headless`) to determine depth of configuration.
- [mise](https://github.com/jdx/mise) for cross-platform CLI tools, package managers to cover system dependencies and desktop apps.
- configuration stays in each tools native format, with chezmoi / go templating where a role or shared theme actually changes it.
- tests to focus on bootstrap, role changes and scripts that can overwrite or remove files.
- CI to handle syntax and template validation.
- `agents/skills/` to sync upstream [skills.sh](https://skills.sh/) skills
- custom agent harness configurations and skills synced from personal/private external repositories.
- custom distributed theming to sync shell and (most) cli tooling.


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

## docs

- [installation](docs/installation.md) - install and maintenance commands and process
- [secrets](docs/secrets.md) - token and secrets integration (backed by bitwarden)
- [ssh](docs/ssh.md) - reproducible ssh config and keys (from a bitwarden manifest file)
- [scoping](docs/scoping.md) - define machine roles, non-interactive options
- [themes](docs/themes.md) - global theming, how to switch and add new
- [testing](docs/testing.md) - ci pipeline and branch testing
- [zsh performance](docs/zsh-perf.md) - documentation of small zsh/starship performance tweaks
