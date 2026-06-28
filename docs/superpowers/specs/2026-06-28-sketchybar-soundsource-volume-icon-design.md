# SketchyBar SoundSource volume icon design

## Goal

Turn the existing unused SoundSource SketchyBar item into a compact right-side audio status icon and launcher. The first slice should answer one simple question: is output volume effectively active or silent?

## Current state

`dot_config/sketchybar/items/app_soundsource.sh` exists but is not sourced by `dot_config/sketchybar/executable_sketchybarrc`. The item is currently a static launcher with a volume icon, no label, and a click action that activates SoundSource.

Local probing showed that macOS `get volume settings` and standard CoreAudio properties do not expose readable output volume/mute for the current output device. BetterDisplay CLI is installed and can read DDC display volume from the current Dell display via:

```bash
betterdisplaycli get -volume
```

This returns a scalar value such as `1.0` for 100%.

## Design

Source the SoundSource item in the right-side SketchyBar section, but keep it intentionally minimal:

- no percentage label;
- no popup in this slice;
- icon-only status;
- click opens SoundSource.

Add a SoundSource plugin that reads hardware/display output volume through BetterDisplay CLI:

```bash
betterdisplaycli get -volume
```

The plugin maps the scalar to three visual states:

1. **Active/audible**: value greater than `0`; show a normal volume icon in the standard icon color.
2. **Silent/muted-ish**: value equal to `0`; show a muted volume icon in a warning/dim color.
3. **Unknown**: BetterDisplay CLI missing, command fails, or output is unparsable; show the neutral SoundSource/volume icon in grey.

This status represents hardware/display output volume, not SoundSource's internal per-app mute state. That trade-off is intentional because the hardware volume is reliably observable on this setup while SoundSource internal state is not yet proven scriptable.

## Files

- Modify `dot_config/sketchybar/executable_sketchybarrc` to source the SoundSource item on the right side.
- Modify `dot_config/sketchybar/items/app_soundsource.sh` to configure the item as an icon-only status item with a script and update frequency.
- Create `dot_config/sketchybar/plugins/executable_soundsource.sh` to read BetterDisplay volume and update icon/color.
- Optionally add icon exports in `dot_config/sketchybar/icons.sh` if the existing volume icons are not clear enough.
- Add a focused shell test under `tests/chezmoi/` with stubbed `betterdisplaycli` and `sketchybar` commands.

## Refresh behavior

Use low-frequency polling only. DDC reads can be slower than ordinary shell status checks, so the item should use `update_freq=60` unless implementation testing shows the call is consistently fast enough for a shorter interval.

No event integration is required in this first slice.

## Failure handling

- If `betterdisplaycli` is unavailable, show the unknown state and keep click-to-open working.
- If the command times out or fails, show the unknown state.
- If the output is not a number, show the unknown state.
- If SoundSource is not installed, clicking may fail silently, but the bar should not fail to load.

## Deferred work

Do not attempt these in this slice:

- SoundSource per-app mute/volume state;
- input/microphone status;
- output device name;
- popup controls;
- Shortcuts-based SoundSource automation;
- setting or changing volume from SketchyBar.

## Verification

Before implementation is complete:

- run the new focused shell test with stubbed active, zero, missing, and invalid BetterDisplay outputs;
- syntax-check touched shell files with `bash -n`;
- run `shellcheck` for touched shell files and the new test;
- run a CI-style `chezmoi apply --dry-run --exclude=externals` render check;
- manually apply/reload SketchyBar and confirm the SoundSource icon is visible, click launches SoundSource, and the icon reflects BetterDisplay volume state when practical.
