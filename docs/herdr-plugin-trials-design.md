# Herdr Plugin Trials Design

## Goal

Add three third-party Herdr plugins to the chezmoi-managed desired-state list for a reversible trial:

- `smarzban/herdr-file-viewer`
- `persiyanov/herdr-reviewr`
- `thanhdat77/herdr-navigator`

## Desired State

Pin the latest stable release commit for each plugin in `.chezmoidata/herdr.yml`:

| Plugin ID | Source | Release | Commit |
| --- | --- | --- | --- |
| `herdr-file-viewer` | `smarzban/herdr-file-viewer` | v1.14.0 | `96fcc0a2bdd2727ec88c38f8c8806f97b7ca0ea0` |
| `persiyanov.reviewr` | `persiyanov/herdr-reviewr` | v0.25.0 | `f1dd491e47ef55410eca7c73daebe3726f06bda0` |
| `herdr-navigator` | `thanhdat77/herdr-navigator` | v0.3.3 | `03b803a00341d58382b6cda70a7cd618af5b8806` |

Do not add Herdr keybindings during the trial. The plugins remain available through `herdr plugin action invoke` without reserving global shortcuts.

## Configuration

Manage Reviewr's plugin config at `dot_config/herdr/plugins/config/persiyanov.reviewr/config.toml` with:

```toml
auto_open = false
```

This prevents Reviewr from automatically opening whenever Herdr creates a worktree. Explicit open and toggle actions remain available.

No additional File Viewer or Navigator configuration is required for the initial trial.

## Security and Runtime Behavior

Herdr plugins run unsandboxed with the current user's permissions.

- File Viewer runs explicit actions only. Its install hook downloads a release binary, verifies SHA-256, and falls back to a local Cargo build.
- Reviewr downloads and verifies a release binary. It registers a worktree-created event, but the managed `auto_open = false` setting suppresses automatic opening. Its explicit send action can place review comments into an agent's input, and its PR view can call authenticated repository CLIs.
- Navigator builds its Rust source locally. It can inspect Herdr workspaces, agents, projects, sessions, remotes, and directories, and can execute integrations configured by the user.

The exact reviewed commits are pinned so future upstream changes are not installed implicitly.

## Testing and Verification

Extend `tests/chezmoi/test-herdr-plugins.sh` to verify that the rendered reconciler:

1. Installs all three sources with the expected full commit SHAs.
2. Records all three plugin IDs, sources, and refs in the managed state ledger.
3. Preserves existing plugin reconciliation behavior.
4. Includes the managed Reviewr setting `auto_open = false`.

Run:

```sh
bash tests/chezmoi/test-herdr-plugins.sh
bash tests/chezmoi/test-herdr-config.sh
chezmoi diff
```

The existing reconciler stops on installation failure and only replaces the state ledger after successful installs. Removing the three entries and Reviewr config later provides the rollback path.
