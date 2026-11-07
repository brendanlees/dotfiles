# machine scoping

dotfiles are scoped by machine role. on first init, chezmoi prompts interactively to configure:

| flag        | effect                                                                          |
| ----------- | ------------------------------------------------------------------------------- |
| `personal`  | apply personal and homelab admin config                                         |
| `work`      | apply work config                                                               |
| `homelab`   | apply homelab environment config                                                |
| `ephemeral` | auto-detected for ci/containers; minimal config                                 |
| `headless`  | skip gui config (ghostty, kanata); auto-set for homelab, prompted for work-only |
| `minimal`   | only a small zshrc and a standalone neovim config; no mise, scripts or externals |

known hostnames can also be auto-assigned without prompting in `home/.chezmoi.toml.tmpl`.

## non-interactive initialization

set `CHEZMOI_ROLE` to a comma-separated list before running `chezmoi init`:

```sh
CHEZMOI_ROLE=personal,work chezmoi init --apply brendanlees
```

valid tokens: `personal`, `work`, `homelab`, `headless`, `ephemeral`, `minimal`. tokens are additive, so `personal,work` sets both flags true. anything not listed stays false. CI uses `CHEZMOI_ROLE=ephemeral,headless` for non-interactive validation.

precedence: `CHEZMOI_ROLE` environment variable, then hostname defaults, then interactive prompts. the environment is read at init time; changing it before a plain `chezmoi apply` does not reinitialize the role.

`chezmoi init --data` is a boolean flag, not a JSON data argument. use the role environment variable for initialization; `--override-data` is useful for temporary rendering and tests.

## minimal hosts

`minimal` is for hosts that only need a shell and an editor, such as the Home Assistant SSH add-on. It implies `headless` and must be requested with `CHEZMOI_ROLE`. It manages two targets:

- `~/.zshrc`, rendered from `.chezmoitemplates/zshrc-minimal.zsh`
- `~/.config/nvim-minimal/init.lua`, selected with `NVIM_APPNAME=nvim-minimal`

tools come from the host's package manager, because mise's prebuilt binaries can need glibc. The Neovim config uses Neovim 0.12's built-in `vim.pack` to install mini.nvim, and still opens without it if GitHub is unreachable. It starts `yaml-language-server` when it is installed, with Home Assistant's YAML tags allowed.

the Home Assistant Advanced SSH add-on recreates its container on each start, so its options install the packages and apply the role every time:

```yaml
packages: [neovim, git, ripgrep, fd, nodejs, npm, tree-sitter-yaml, tree-sitter-json, tree-sitter-bash, tree-sitter-python]
init_commands:
  - sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- -b /root/.local/bin
  - npm install -g --no-fund --no-audit yaml-language-server@2
  - CHEZMOI_ROLE=minimal /root/.local/bin/chezmoi init --apply brendanlees
```

## configure via ansible

set `dotfile_roles` to a list such as `[homelab, headless]`. pass it through the task environment rather than a shell-quoted JSON argument:

```yaml
- name: Initialize chezmoi with scope
  ansible.builtin.command: chezmoi init --apply brendanlees
  environment:
    CHEZMOI_ROLE: "{{ dotfile_roles | join(',') }}"
  args:
    creates: "{{ ansible_env.HOME }}/.local/share/chezmoi/.git"
```

run this as the intended dotfiles owner. an existing checkout can be reinitialized explicitly when its role changes.

## root on servers

root keeps its own global mise tools. `~/.config/mise/miserc.toml` ignores project configs under `/home`, rather than trusting code owned by every user there. This removes the repeated trust warnings without granting those configs root execution.

if you intentionally need project-specific tools as root, override `MISE_IGNORED_CONFIG_PATHS` for that session and explicitly trust the particular project. Ordinary user accounts keep mise's normal trust behaviour.

## private agent configuration

personal machines bootstrap private `.pi` and `.claude` repositories. those repositories own their settings, packages and instructions; dotfiles supply the shared theme bridge and the `~/.agents` link.

removing the personal role stops managing the private harness repositories; it must not delete them or unrelated user directories. `~/.agents` is a managed symlink, so it is removed when no longer in scope, leaving its source intact.

on personal macOS and Windows machines, `cz-private-agent-skills reconcile` links direct skills from the configured private checkout into the shared skill directory. It clones a missing checkout but does not pull or reset an existing one. `deactivate` removes only owned links and Git excludes, keeping the checkout and machine configuration. Updating or deleting the private repository is an explicit Git/filesystem operation, outside this helper.
