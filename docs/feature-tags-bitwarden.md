# Feature Tags & Bitwarden Integration

Continuation context for next agent session.

## Branch

`feature/bitwarden-feature-tags` — worktree at `.worktrees/feature/bitwarden-feature-tags/`

## What's Done

- `.chezmoi.toml.tmpl` — four feature flags with `promptBoolOnce` flow:
  ```
  Is this a personal machine?
    yes → Is this machine used for homelab management?
          Is this machine also used for work?
    no  → Is this a work machine?
  Is this an ephemeral environment?
  ```
  Ephemeral auto-detected via `CODESPACES`, `REMOTE_CONTAINERS`, `GITPOD_WORKSPACE_ID`, `CI`.
  `bitwarden.unlock = "auto"` enabled when `personal = true`.

- `dot_config/git/config.tmpl` — git identity: Bitwarden on personal, `promptStringOnce` on work, fallback to `chezmoi.username`

- `private_dot_config/private_env_tokens.sh.tmpl` — `GITHUB_TOKEN` from Bitwarden item `Github` / field `read_only_token`, sourced in zshrc on personal machines

- `.chezmoiscripts/run_once_generate_ssh_key.sh.tmpl` — generates `~/.ssh/<hostname>` (ed25519, comment `user@hostname`) on personal machines if key doesn't already exist

- `.chezmoiexternal.toml.tmpl` — nvim config skipped on ephemeral machines

- `dot_zshrc.tmpl` — DietPi PATH/login via runtime `[[ -d /boot/dietpi ]]` check (no template flag); `.bw` PATH and token sourcing gated on `personal`

- `.chezmoiignore` — `private_dot_config/private_env_tokens.sh` excluded on non-personal machines

## Still To Do

- SSH config templates (`dot_ssh/config.tmpl`, `dot_ssh/config.d/`)
- Bitwarden templates for service keys (fetched on `homelab` machines)
- `.chezmoiignore` gates for SSH config.d files per flag

## SSH Config Structure (existing, to be templated)

```
~/.ssh/config               — Include config.d/*, OrbStack (darwin only), Match all
~/.ssh/config.d/github      — personal
~/.ssh/config.d/homelab     — homelab
~/.ssh/config.d/work        — work
```

## Bitwarden Setup Required

### Items That Already Exist
| Item | Used For |
|------|----------|
| `Github` | `GITHUB_TOKEN` via field `read_only_token` (already wired) |

### Items to Create

**Git Config** (type: Login)
- Username: personal email address
- Custom field `name`: full name

**SSH — GitHub** (type: Login)
- Attachment: `id_gh` (private key file `~/.ssh/keys/github/id_gh`)

**SSH — Homelab Pi** (type: Login)
- Attachment: `id_pi` (used by: pihole, rpi1)

**SSH — Homelab Proxmox** (type: Login)
- Attachment: `id_pv` (used by: pve1, pve2)

**SSH — Homelab TrueNAS** (type: Login)
- Attachment: `id_tn` (used by: truenas, truenas-root)

**SSH — Homelab xbxd** (type: Login)
- Attachment: `hl_xbxd` (used by: hass, servarr-dev, servarr, traefik, gitea)

**SSH — Homelab Ubuntu** (type: Login)
- Attachment: `id_ub` (used by: duplicacy, local-stdy01)

**SSH — Work** (type: Login)
- Attachment: `stdy_ad` (used by: vultr-syd01)

### Notes
- Attachment name in Bitwarden must match the key filename exactly (chezmoi uses it as the target filename)
- Passwords for homelab hosts noted as `# pw: (in bw)` in config — already in vault, no action needed
- The per-machine key (`~/.ssh/<hostname>`) is generated fresh on each machine — not stored in Bitwarden
