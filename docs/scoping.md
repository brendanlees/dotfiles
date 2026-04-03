# Machine Scoping

Dotfiles are scoped by machine role. On first init, chezmoi prompts interactively to configure:

| Flag        | Effect                                          |
| ----------- | ----------------------------------------------- |
| `personal`  | apply personal and homelab admin config         |
| `work`      | apply work config                               |
| `homelab`   | apply homelab environment config                |
| `ephemeral` | auto-detected for CI/containers; minimal config |

Known hostnames can also be auto-assigned without prompting in `.chezmoi.toml.tmpl`.

## Skip prompts via flags

Data flags can be added to `chezmoi init` to bypass interactive prompts:

```sh
chezmoi init --apply --data='{"personal":true,"work":false,"homelab":false}' brendanlees
```

## Configure via Ansible

If provisioning non-interactively (e.g. from an Ansible role), pass the data block in the chezmoi init task:

```yaml
- name: Apply dotfiles
  command: >
    chezmoi init --apply
    --data='{"personal":true,"headless":false}'
    brendanlees
  become: false
```
