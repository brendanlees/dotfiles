# Herdr Last Workspace Plugin Design

## Goal

Replace Herdr's built-in previous-workspace binding with the `third774/herdr-last-workspace` plugin while preserving the existing `prefix+L` shortcut.

## Design

Add the plugin to `.chezmoidata/herdr.yml` using manifest ID `third774.last-workspace`, source `third774/herdr-last-workspace`, and reviewed commit `8b55ebf15deaa52b49ff1c2500aab0c19c729420`.

Remove `previous_workspace = "prefix+L"` from `[keys]`. Add a `plugin_action` command binding `prefix+L` to `third774.last-workspace.toggle`. The plugin's focus and close event handlers will maintain its previous-workspace state.

The plugin builds a Rust binary with Cargo and supports macOS and Linux. It requires Herdr 0.7.0 or newer. Plugin code runs unsandboxed under the current user.

## Validation

Extend the plugin reconciliation test to verify the pinned install and state-ledger entry. Extend the rendered Herdr configuration test to verify that the built-in binding is absent and the plugin action uses `prefix+L`. Update the plugin-management documentation with the reviewed manifest behavior and dependency.

Run:

```sh
bash tests/chezmoi/test-herdr-plugins.sh
bash tests/chezmoi/test-herdr-config.sh
chezmoi diff
```

## Scope

No other Herdr shortcuts, plugin settings, or workspace navigation behavior will change.
