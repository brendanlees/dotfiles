# SketchyBar live workspace icons design

## Goal

Make the SketchyBar AeroSpace workspace items reflect live app state instead of treating workspace names such as `1-browser` or `4-files` as rigid truth. The bar should preserve workspace-number muscle memory while showing the representative app icon currently associated with each workspace.

This is the first signal-focused slice of a broader SketchyBar evolution. It should improve workspace/front-app signal and reduce clutter without introducing heavier polling integrations yet.

## Current state

`dot_config/sketchybar/items/spaces.sh` creates one SketchyBar item per AeroSpace workspace and displays the numeric prefix from each workspace name. Focus styling is updated by `plugins/executable_aerospace.sh` when the custom `aerospace_workspace_change` event fires.

`plugins/executable_icon_map.sh` maps app names to `font-sketchybar-app-font` glyph tokens, but the workspace items do not use it. `items/front_app.sh` currently displays only the active app name. `items/app_itsycal.sh` and `items/app_soundsource.sh` exist as static click targets but are not sourced by `executable_sketchybarrc`.

`plugins/executable_battery.sh` always shows battery state when `pmset` returns a percentage, including while on AC power.

## Design

### Workspace items

Each AeroSpace workspace item should display the workspace number plus one representative live app icon for that workspace.

The number remains the stable identifier for keyboard/workspace muscle memory. The app icon is derived from live AeroSpace window/app state, not from the workspace suffix. If Arc is moved from workspace `1-browser` to `4-files`, the Arc icon should follow the app to workspace 4 after the next workspace refresh.

Workspace names remain useful as human labels and click targets, but they are not the source of truth for icon state.

### Representative app selection

The first slice uses one representative app icon per workspace, not all app icons. This keeps the bar compact and avoids overflow handling.

Selection rules:

1. For the focused workspace, prefer the actual focused/front app when that information is available.
2. For inactive workspaces, query AeroSpace for windows/apps in that workspace and use the best available first/current representative app from the CLI output.
3. If a workspace has no windows, show only the workspace number and no app icon.
4. If the representative app is not present in `icon_map.sh`, use the existing default icon fallback.

Implementation should verify the exact AeroSpace CLI flags and output format before coding this selector.

### Icon mapping

Keep `plugins/executable_icon_map.sh` as the app-name-to-icon boundary. Workspace scripts should call it with real app names, not workspace purpose names. This keeps the map reusable for both workspace items and the front-app item.

If future work needs workspace-purpose fallback icons, add that as a separate mapper or an explicit fallback mode rather than mixing legacy workspace naming into the app-name map.

### Front app item

Change `front_app` from text-only to icon plus app name.

On `front_app_switched`, the plugin should:

1. read the active app name from SketchyBar's event info;
2. map it through `icon_map.sh`;
3. set the item icon to the mapped app glyph;
4. set the label to the app name.

Unknown apps use the default icon. The item should remain readable even when app-icon mapping is incomplete.

### Battery item

Make battery an exception-only signal:

- hide the battery item when `pmset` reports AC power;
- hide the item when no battery percentage is available;
- show the existing battery icon, percentage, and color thresholds only while discharging.

This reduces right-side clutter on desktops or laptops connected to power.

### Deferred integrations

Do not source the existing `app_itsycal.sh` or `app_soundsource.sh` in this first slice. They should become dynamic before being shown.

Future slices can add:

- SoundSource output volume, output mute, input device, and mic status;
- Spotify or general now-playing state;
- Tailscale/VPN/network state;
- calendar/upcoming-events popup anchored to an Itsycal/calendar item;
- tmux/sesh active session and git branch state;
- package update count with low-frequency cached refresh.

## Event and refresh model

Prefer event-driven updates over frequent polling.

Required triggers:

- `aerospace_workspace_change` refreshes workspace focus and representative app icons.
- `front_app_switched` refreshes the front-app icon/label and can also refresh workspace icon state for the focused workspace.

Optional safety net:

- Add a low-frequency workspace icon refresh only if AeroSpace does not provide reliable events for all relevant app moves/window changes. A 30–60 second interval is acceptable; high-frequency polling is not.

The implementation should avoid clearing all workspace icons on transient AeroSpace query failures. Existing item state can remain until the next successful refresh, or a specific item can fall back to number-only when its workspace is empty.

## Failure handling

- If `aerospace` is unavailable, skip dynamic workspace setup or render number-only workspace items.
- If a workspace query fails, do not fail the whole SketchyBar reload.
- If `icon_map.sh` returns no value, use `:default:`.
- If a workspace has no windows, show number-only state.
- If `pmset` does not return battery information, hide the battery item.

## Verification

Before implementation is considered complete:

- syntax-check touched shell scripts with `bash -n`;
- run `shellcheck` where practical for touched shell scripts;
- run a chezmoi render or dry-run check from the source tree;
- verify the front-app item shows an app icon plus app name;
- verify moving an app from one AeroSpace workspace to another causes the app icon to follow after the refresh event/safety refresh;
- verify empty workspaces remain number-only;
- verify battery hides while on AC power and still displays while discharging if that state can be tested safely.
