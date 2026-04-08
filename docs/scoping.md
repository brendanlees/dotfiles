# machine scoping

dotfiles are scoped by machine role. on first init, chezmoi prompts interactively to configure:

| flag        | effect                                                                          |
| ----------- | ------------------------------------------------------------------------------- |
| `personal`  | apply personal and homelab admin config                                         |
| `work`      | apply work config                                                               |
| `homelab`   | apply homelab environment config                                                |
| `ephemeral` | auto-detected for ci/containers; minimal config                                 |
| `headless`  | skip gui config (ghostty, kanata); auto-set for homelab, prompted for work-only |

known hostnames can also be auto-assigned without prompting in `.chezmoi.toml.tmpl`.

## skip prompts via flags

data flags can be added to `chezmoi init` to bypass interactive prompts:

```sh
chezmoi init --apply --data='{"personal":true,"work":false,"homelab":false}' brendanlees
```

## skip prompts via env var

set `CHEZMOI_ROLE` (comma-separated) before running `chezmoi init` — useful when you don't want to type a long `--data=` json blob, or when something else (mise, direnv, systemd unit) is already managing per-machine env:

```sh
CHEZMOI_ROLE=personal,work chezmoi init --apply brendanlees
```

valid tokens: `personal`, `work`, `homelab`, `headless`, `ephemeral`. tokens are additive, so `personal,work` sets both flags true. anything not listed stays false. ci uses `CHEZMOI_ROLE=ephemeral,headless` for non-interactive validation — see [testing](testing.md).

env vars are read from the chezmoi process at init time, so any of these work:

- inline prefix (`CHEZMOI_ROLE=… chezmoi init`)
- shell `export`
- mise `[env]` block in `~/.config/mise/config.toml` (set once per machine, persists across shells)
- direnv `.envrc`

precedence: `CHEZMOI_ROLE` env var → hostname allow-list → interactive prompts.

## configure via ansible

if provisioning non-interactively (e.g. from an ansible role)

```yaml
- name: Initialize chezmoi with scope (primary user)
  vars:
    _scope: "{{ {'personal': false, 'work': false, 'homelab': false, 'headless': false, 'ephemeral': false} | combine(dotfile_scope) }}"
  shell: "chezmoi init --apply --data='{{ _scope | to_json }}' {{ dotfile_repo }}"
  timeout: 60
  when:
    - chezmoi_binary_user.rc == 0
    - not chezmoi_source_user.stat.exists
    - dotfile_scope is defined
```
