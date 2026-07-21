# Herdr–Worktrunk Integration Design

## Goal

Integrate Worktrunk into Herdr through `devashish2203/herdr-worktrunk` while preserving the existing tmux-specific Worktrunk behavior. Worktrunk remains the sole owner of Git worktree creation, switching, and removal.

## Architecture

Install `herdr-worktrunk` through the repository's existing declarative Herdr plugin reconciliation. Pin the plugin to a reviewed full commit SHA. Configure it in native `workspace` mode so Worktrunk-created checkouts appear as Herdr linked-worktree workspaces.

The plugin invokes `wt` for lifecycle operations and then opens, focuses, or closes the corresponding Herdr workspace. Do not add Herdr-specific Worktrunk hooks, `wt-herdr`, or `@yassimba/pi-herdr-worktree`.

## Herdr Configuration

Add these plugin actions to the rendered Herdr key configuration:

- `prefix+shift+g` → `worktrunk.open` for switching to or creating a worktree from the default branch.
- `prefix+shift+c` → `worktrunk.open-current` for creating from the current branch.
- `prefix+shift+d` → `worktrunk.remove` for safe removal through Worktrunk.

Manage the plugin's user configuration with:

```toml
open_mode = "workspace"
```

Resolve the plugin-owned configuration directory through Herdr rather than hard-coding generated plugin checkout paths.

## Worktrunk and tmux Compatibility

Retain the existing tmux-oriented `post-switch` window rename and `post-start` pane-count hooks. Rewrite their guards as explicit conditionals:

- Under tmux, preserve their current behavior.
- Under Herdr or a plain terminal, perform no action and return success.

This prevents an absent `TMUX` or `TMUX_PANE` variable from making a Worktrunk hook fail while requiring no Herdr-specific hook rules.

## Safety and Error Handling

- Audit the pinned plugin manifest and all executable shell entrypoints before installation.
- Retain Worktrunk's confirmation and dirty/unmerged-worktree safeguards.
- If `wt` fails, allow the plugin to display the error without creating partial Herdr state.
- Keep Herdr generated runtime files out of chezmoi desired state.
- Do not introduce a second worktree lifecycle owner.

## Testing and Validation

- Extend Herdr plugin reconciliation tests for the pinned `worktrunk` plugin.
- Extend rendered Herdr configuration tests for all three action bindings.
- Verify the managed plugin configuration renders `open_mode = "workspace"`.
- Test that tmux hooks retain their commands and use successful no-op guards outside tmux.
- Run focused chezmoi tests and inspect `chezmoi diff`.
- Record the pre-existing `test-herdr-plugins.sh` baseline failure caused by the absent `dot_config/nvim/after/plugin/herdr_nav.lua`; do not repair it as part of this feature.

## Documentation

Update Herdr plugin-management documentation with the plugin's source, pin, behavior, dependencies, configuration, and reviewed execution surface. Document that Worktrunk remains authoritative and that tmux hooks are intentionally retained for tmux sessions.

## Out of Scope

- Installing `@yassimba/pi-herdr-worktree`.
- Installing `mattarau/wt-herdr`.
- Replacing Worktrunk with Herdr-native worktree creation.
- Repairing the unrelated missing Neovim Herdr navigation bridge.
