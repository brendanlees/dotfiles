# Herdr Plus Starter Configuration Design

## Goal

Add `cloudmanic/herdr-plus` to the existing declarative Herdr plugin stack and provide a small, understandable Projects configuration based on the explicit sessions already used by sesh. Herdr Plus will fill sesh's project-launcher role inside Herdr without changing the existing sesh/tmux workflow.

## Scope

- Keep sesh and tmux configuration unchanged.
- Install Herdr Plus through the existing `.chezmoidata/herdr.yml` plugin reconciliation mechanism.
- Pin the plugin to commit `f32b0825f12543c1d03e54fb10d1741c40d66cdc` (manifest version `0.1.16`).
- Add explicit Herdr Plus projects corresponding to named sesh sessions enabled by the current chezmoi role flags.
- Bind Herdr `prefix+K` to the Herdr Plus Projects action.
- Do not reproduce sesh wildcard discovery, zoxide integration, sorting, blacklist, or preview behavior.
- Do not configure Herdr Plus Quick Actions or worktree auto-layouts.

## Declarative layout

Herdr provisions plugin configuration under:

```text
~/.config/herdr/plugins/config/cloudmanic.herdr-plus/
```

Chezmoi will manage starter project TOML files beneath its `projects/` directory. Each file represents one project. Role-specific files will follow existing chezmoi conditions so machines receive only the projects associated with their active scopes.

The project files are intentionally independent of the sesh files. This duplicates a small amount of starter configuration but avoids introducing a shared schema, conversion script, or runtime filesystem discovery. The configurations can diverge naturally as Herdr Plus usage develops.

## Starter projects

Each project preserves the corresponding sesh session's `name`, expanded `path` as `working_dir`, and optional `startup_command`. A project contains one tab. Sessions with a startup command run it in that tab; sessions without one open a normal shell.

### Base

- `dotfiles` — `~/{{ .chezmoi_dir }}`
- `nvim-config` — `~/.config/nvim`
- `tmux-config` — `~/{{ .chezmoi_dir }}/dot_config/tmux`, starting `nvim tmux.conf.tmpl`

### Personal scope

These mirror the sessions currently imported when `.personal` is enabled:

- `hass-config`
- `homelab`
- `pi-config`
- `claude-config`
- `hermes-config`
- `hermes-folder`

Their paths and startup commands remain equivalent to `dot_config/sesh/configs/personal.toml.tmpl`.

### Work scope

- `steady-servers`, including its existing Tailscale and Ansible startup command

### Homelab scope

- `home`
- `docker`, retaining the existing `/opt/docker/compose` path selection
- `opt`

## Plugin and key configuration

`.chezmoidata/herdr.yml` gains a plugin entry with:

- ID: `cloudmanic.herdr-plus`
- Source: `cloudmanic/herdr-plus`
- Ref: `f32b0825f12543c1d03e54fb10d1741c40d66cdc`

`dot_config/herdr/config.toml.tmpl` gains a `plugin_action` command:

```toml
[[keys.command]]
key = "prefix+K"
type = "plugin_action"
command = "cloudmanic.herdr-plus.projects"
description = "herdr-plus: projects"
```

Quick Actions remain available from Herdr's plugin action menu but receive no dedicated binding.

## Reconciliation and removal

The existing Herdr plugin installer remains the sole plugin lifecycle mechanism. Adding the plugin to `.chezmoidata/herdr.yml` causes installation at the pinned ref, while later removing it from the data file causes uninstall through the existing state ledger.

Chezmoi owns only the starter project files it declares. Herdr Plus's persistent plugin configuration directory and any future user-created project files remain otherwise untouched.

## Validation

Tests will verify:

- The reconciler installs both managed plugins at their pinned refs and records both in its state ledger.
- Removed plugins are still uninstalled.
- Herdr's rendered configuration binds `prefix+K` to `cloudmanic.herdr-plus.projects`.
- Base project templates render expected names, paths, tabs, and startup commands.
- Personal, work, and homelab projects obey their existing role conditions.
- The stale `test-herdr-plugins.sh` dependency on the removed Neovim bridge is deleted; navigation ownership moved in commit `3cf3a11`, so that assertion no longer belongs to plugin reconciliation coverage.

Relevant chezmoi tests and static checks will run before completion.

## Non-goals

- Sharing a single project schema between sesh and Herdr Plus
- Translating sesh wildcard entries into generated projects
- Removing or changing sesh/tmux bindings
- Adding multi-tab or multi-pane project layouts
- Adding worktree layouts or Quick Actions
- Automatically discovering repositories at chezmoi apply time
