# HerdR tmux-compatible configuration design

## Goal

Add a macOS/Linux HerdR configuration that preserves the core keyboard and interaction patterns from `dot_config/tmux/tmux.conf.tmpl`, while integrating HerdR colors with the existing chezmoi-driven theme registry.

This is an evaluation base, not a complete tmux emulation layer. Native HerdR actions are preferred where they preserve the same behavior; a small number of custom command bindings are acceptable when they avoid retraining established muscle memory.

## Scope

- Add a managed `~/.config/herdr/config.toml` template for macOS and Linux.
- Preserve the default `ctrl+b` prefix.
- Map tmux pane, tab, reload, detach, split, copy, close, zoom, and resize behavior as closely as HerdR permits.
- Render HerdR's exposed custom colors from the active `.chezmoidata/themes.yml` palette.
- Reload the default running HerdR server after `theme` applies a new palette.
- Document HerdR in `docs/themes.md`.
- Add focused validation for template rendering and critical mappings.

## Non-goals

- Reproduce TPM plugins, `vim-tmux-navigator`, sesh, resurrect/continuum, fzf-url, or other tmux integrations.
- Add a HerdR plugin or a general socket API helper.
- Reorder HerdR tabs with `ctrl+shift+alt+h/l`; HerdR exposes no native/configurable tab-reorder action. Its raw API has `tab.move`, but a custom socket client is excessive for this evaluation base.
- Support Windows in this first configuration.
- Reload every named HerdR session. The first implementation reloads the documented default server target only.

## Configuration architecture

Create `dot_config/herdr/config.toml.tmpl`. The template selects the active palette once:

```gotemplate
{{- $p := (index .themes .theme).palette -}}
```

The file remains declarative. Native HerdR key actions handle direct mappings. Four `[[keys.command]]` entries call the documented HerdR CLI to resize the active pane by 5%, using `HERDR_BIN_PATH` and `HERDR_ACTIVE_PANE_ID` supplied to custom commands.

Add `.config/herdr` to the Windows section of `.chezmoiignore`, leaving the config managed on macOS and Linux.

## Key and behavior mapping

| tmux behavior | HerdR mapping | Notes |
| --- | --- | --- |
| Prefix | `ctrl+b` | Same default prefix. |
| New window | `prefix+c` → new tab | HerdR tabs are the closest tmux-window equivalent. |
| Detach | `prefix+d` | Replaces HerdR's default `prefix+q`. |
| Reload | `prefix+r` | Matches the custom tmux reload binding. |
| Resize left/down/up/right | `prefix+h/j/k/l` | Custom CLI commands resize by `0.05`; repeatable tmux bindings are not available. |
| Previous/next window | `ctrl+shift+h/l` → previous/next tab | Keep `prefix+p/n` as secondary native bindings. |
| Close pane | `prefix+x` | Exact mapping. |
| Close window | `prefix+ampersand` → close tab | Uses HerdR's named punctuation syntax. |
| Zoom pane | `ctrl+f` and `prefix+z` | Keeps the custom direct chord and tmux's standard chord. |
| Split side-by-side | `prefix+percent` | tmux's `%` split, expressed with HerdR's named punctuation. |
| Split stacked | `prefix+double_quote` | tmux's `"` split, expressed with HerdR's named punctuation. |
| Select window 1–9 | `prefix+1..9` → switch tab | HerdR uses one-based indexed jumps. |
| Copy mode | `prefix+[` | HerdR's built-in copy mode already supports vi/tmux movement, `v` selection, and `y` copy. |
| Rename window | `prefix+comma` → rename tab | Preserves tmux's manual rename chord. |
| Reorder windows | Unmapped | No native/configurable HerdR action; pane swaps are not equivalent. |

HerdR's default `focus_pane_left/down/up/right` bindings are explicitly emptied so the resize commands can own `prefix+h/j/k/l` without conflict. HerdR navigate-mode pane movement remains available as the non-plugin keyboard fallback, along with mouse focus.

The built-in resize-mode binding is emptied because `prefix+r` is reserved for reload and direct resize commands provide the tmux-compatible path.

## Terminal and UI behavior

- `terminal.default_shell = "zsh"`.
- `terminal.shell_mode = "auto"`, preserving login-shell behavior on macOS.
- `terminal.new_cwd = "follow"`, matching new tmux windows in the active pane's directory.
- Mouse capture and pane borders remain enabled.
- Pane gaps are disabled so split panes share dividers more like tmux.
- New-tab naming prompts are disabled so `prefix+c` creates immediately.
- Sound notifications are disabled; HerdR's sidebar and semantic agent states remain available.
- Scrollback is set to `100_000_000` bytes per pane as a conservative byte-based approximation of the tmux configuration's one-million-line intent.

Tmux settings with no useful HerdR equivalent—terminal capability flags, escape timing, title formatting, top status-bar formatting, border line style, and tmux server environment behavior—are intentionally omitted.

## Theme mapping

Use `theme.name = "terminal"` as the base so any future unexposed color falls back to the host terminal. Disable automatic light/dark switching because chezmoi remains the source of truth. Override all currently exposed HerdR custom tokens:

| HerdR token | Palette key |
| --- | --- |
| `panel_bg` | `bg` |
| `surface0` | `surface` |
| `surface1` | `surface_alt` |
| `surface_dim` | `tool_neutral_bg` |
| `overlay0` | `border` |
| `overlay1` | `comment` |
| `text` | `fg` |
| `subtext0` | `muted` |
| `accent` | `accent` |
| `mauve` | `secondary` |
| `green` | `success` |
| `yellow` | `warn` |
| `red` | `error` |
| `blue` | `primary` |
| `teal` | `info` |
| `peach` | `orange` |

Set `ui.accent` from the same palette `accent`. No `apps.herdr` registry field is needed because the template consumes semantic palette values directly.

## Theme-switch data flow

1. `theme <name>` writes the host-local selection to `.chezmoidata/local.yml`.
2. `chezmoi apply` re-renders `~/.config/herdr/config.toml` with the selected palette.
3. If `herdr` is installed and a HerdR process is running, the switcher calls `herdr server reload-config`.
4. Reload failure emits a warning and does not prevent the remaining application reloads.

Named HerdR sessions are a documented limitation for this first pass. If the evaluation adopts them, the switcher can later enumerate sessions and reload each server.

## Error handling

- HerdR's own startup/reload diagnostics remain authoritative for invalid semantic settings.
- The template test parses rendered TOML before changes land.
- The theme switcher checks both command availability and a running process before attempting reload.
- HerdR reload errors are non-fatal because theme switching must continue reloading other applications.
- Resize commands use HerdR-provided environment variables rather than assuming a socket path or executable location.

## Verification

Add a focused shell test that:

- renders `dot_config/herdr/config.toml.tmpl` through chezmoi;
- parses the result with Python `tomllib`;
- verifies the critical key mappings and four resize commands;
- verifies representative palette interpolation;
- verifies Windows ignores `.config/herdr`;
- verifies the theme switcher includes guarded HerdR reload behavior.

Run the relevant chezmoi shell tests and static checks. If a local HerdR binary is available, also perform a non-disruptive config-load smoke check; absence of the binary does not fail repository validation.

## Authoritative sources

- HerdR configuration: https://herdr.dev/docs/configuration/
- HerdR keyboard behavior: https://herdr.dev/docs/keyboard/
- HerdR config reference: https://herdr.dev/docs/config-reference/
- HerdR CLI reference: https://herdr.dev/docs/cli-reference/
- HerdR keybinding parser and conflict behavior: https://github.com/ogulcancelik/herdr/blob/master/src/config/keybinds.rs
- HerdR custom theme tokens: https://github.com/ogulcancelik/herdr/blob/master/src/config/theme.rs
