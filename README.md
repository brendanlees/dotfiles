# dotfiles

managed by [chezmoi](https://www.chezmoi.io/).

## quick install

**macos:**

```sh
brew install chezmoi && chezmoi init --apply brendanlees
```

**linux:**

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply brendanlees
```

on first run you'll be prompted to set your machine role. see [scoping](docs/scoping.md) to skip prompts or provision via ansible.

## architecture

```
.chezmoi.toml.tmpl        # template config — sets role flags (personal/work/homelab/ephemeral)
.chezmoiexternal.toml.tmpl # external sources (fetched files, archives)
.chezmoiscripts/
  run_once_before_*       # bootstrap: install chezmoi deps, mise
  run_after_*             # post-apply: install tools, tmux plugins
.chezmoitemplates/        # shared template partials
dot_zshrc.tmpl            # zsh config
dot_aliases/              # alias files, sourced by zshrc
dot_config/               # xdg config (git, mise, starship, ghostty, …)
```

role flags gate which config and packages are applied per machine type.

## docs

- [usage](docs/usage.md) — updating, re-installing
- [scoping](docs/scoping.md) — machine roles, skipping prompts, ansible
- [inspiration](docs/inspiration.md) — reference repos and tools
