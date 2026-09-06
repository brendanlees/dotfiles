# machine scoping

dotfiles are scoped by machine role. on first init, chezmoi prompts interactively to configure:

| flag        | effect                                                                          |
| ----------- | ------------------------------------------------------------------------------- |
| `personal`  | apply personal and homelab admin config                                         |
| `work`      | apply work config                                                               |
| `homelab`   | apply homelab environment config                                                |
| `ephemeral` | auto-detected for ci/containers; minimal config                                 |
| `headless`  | skip gui config (ghostty, kanata); auto-set for homelab, prompted for work-only |

known hostnames can also be auto-assigned without prompting in `home/.chezmoi.toml.tmpl`.

## non-interactive initialization

set `CHEZMOI_ROLE` to a comma-separated list before running `chezmoi init`:

```sh
CHEZMOI_ROLE=personal,work chezmoi init --apply brendanlees
```

valid tokens: `personal`, `work`, `homelab`, `headless`, `ephemeral`. tokens are additive, so `personal,work` sets both flags true. anything not listed stays false. CI uses `CHEZMOI_ROLE=ephemeral,headless` for non-interactive validation.

precedence: `CHEZMOI_ROLE` environment variable, then hostname defaults, then interactive prompts. the environment is read at init time; changing it before a plain `chezmoi apply` does not reinitialize the role.

`chezmoi init --data` is a boolean flag, not a JSON data argument. use the role environment variable for initialization; `--override-data` is useful for temporary rendering and tests.

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

## private agent configuration

personal machines bootstrap private `.pi` and `.claude` repositories. those repositories own their settings, packages and instructions; dotfiles supply the shared theme bridge and the `~/.agents` link.

removing the personal role stops managing the private harness repositories; it must not delete them or unrelated user directories. `~/.agents` is a managed symlink, so it is removed when no longer in scope, leaving its source intact.
