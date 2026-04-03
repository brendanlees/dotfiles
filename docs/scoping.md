# machine scoping

dotfiles are scoped by machine role. on first init, chezmoi prompts interactively to configure:

| flag        | effect                                          |
| ----------- | ----------------------------------------------- |
| `personal`  | apply personal and homelab admin config         |
| `work`      | apply work config                               |
| `homelab`   | apply homelab environment config                |
| `ephemeral` | auto-detected for ci/containers; minimal config |
| `headless`  | skip gui config (ghostty, kanata); auto-set for homelab, prompted for work-only |

known hostnames can also be auto-assigned without prompting in `.chezmoi.toml.tmpl`.

## skip prompts via flags

data flags can be added to `chezmoi init` to bypass interactive prompts:

```sh
chezmoi init --apply --data='{"personal":true,"work":false,"homelab":false}' brendanlees
```

## configure via ansible

if provisioning non-interactively (e.g. from an ansible role), pass the data block in the chezmoi init task:

```yaml
- name: apply dotfiles
  command: >
    chezmoi init --apply
    --data='{"work":true,"headless":true}'
    brendanlees
  become: false
```
