# SketchyBar Spotify now-playing design

## Goal

Add a compact right-side SketchyBar item that shows the currently playing Spotify track. The item should be signal-only: visible when Spotify is playing, hidden when Spotify is paused, stopped, unavailable, or not running.

## Current state

SketchyBar currently has no Spotify-specific item. The bar already sources right-side SoundSource, calendar, and battery items. `plugins/executable_icon_map.sh` includes a Spotify app-font mapping, but this slice can use a simple Nerd Font or app-font Spotify icon directly.

Local probing confirms Spotify is installed and AppleScript exposes the required state:

```bash
osascript -e 'tell application "Spotify" to player state as string'
osascript -e 'tell application "Spotify" to artist of current track & " - " & name of current track'
```

Those commands returned `playing` and a valid artist/title string while Spotify was playing.

## Design

Create a Spotify-specific SketchyBar item with three responsibilities:

1. poll Spotify's AppleScript API at a low frequency;
2. show icon plus bounded `Artist — Title` text while playback state is `playing`;
3. hide the item when Spotify is paused, stopped, not running, or returns an error.

The first slice should not implement playback controls, popups, album art, general media support, or per-player abstraction.

## Bar behavior

When Spotify is playing:

- item drawing is on;
- icon is visible and colored normally;
- label contains `Artist — Title`, truncated to a fixed maximum length;
- clicking opens/activates Spotify.

When Spotify is paused/stopped/unavailable:

- item drawing is off;
- no stale track text remains visible.

## Text formatting

The plugin should build a display string as:

```text
Artist — Title
```

Use an em dash with spaces for readability. Truncate the final string to a bounded width, roughly 40 characters, and append an ellipsis when truncated. This keeps the right side of the bar from expanding unpredictably.

## Refresh behavior

Use polling via SketchyBar `update_freq`, not event integration, for this first slice. A 15-second refresh interval is a reasonable default: quick enough for track changes, low enough to avoid excessive AppleScript calls.

## Files

- Create `dot_config/sketchybar/items/spotify.sh` to define the right-side item.
- Create `dot_config/sketchybar/plugins/executable_spotify.sh` to query Spotify and update item state.
- Modify `dot_config/sketchybar/executable_sketchybarrc` to source the Spotify item on the right side.
- Add a focused shell test under `tests/chezmoi/` with stubbed `osascript` and `sketchybar` commands.
- Add icon exports in `dot_config/sketchybar/icons.sh` only if the implementation does not use an inline icon constant.

## Failure handling

- If Spotify is not running, hide the item.
- If AppleScript errors, hide the item.
- If player state is not `playing`, hide the item.
- If artist or title is missing, use whichever value exists; if both are missing, hide the item.
- The plugin should never fail SketchyBar reload just because Spotify is unavailable.

## Deferred work

Do not include these in the first slice:

- play/pause/next controls;
- hover/click popup;
- album art;
- generic macOS now-playing support;
- Spotify Web API or authentication;
- track-progress indicators;
- SoundSource interaction.

## Verification

Before implementation is complete:

- run a focused shell test covering playing, paused, stopped, not-running/error, and truncation behavior;
- syntax-check touched shell files with `bash -n`;
- run `shellcheck` for touched shell files and the new test;
- run the full `tests/chezmoi/*.sh` shell suite;
- run a CI-style `chezmoi apply --dry-run --exclude=externals` render check;
- manually apply/reload SketchyBar and confirm Spotify appears only while playing, shows truncated `Artist — Title`, and clicking opens Spotify.
