# SketchyBar right-anchor polish design

## Goal

Make the right side of SketchyBar feel more deliberate by keeping date/time as the final right-side anchor, adding a subtle tmux-inspired braille separator to that date/time segment, and shelving the SoundSource item for now.

## Current state

The right-side section currently sources Spotify, SoundSource, calendar, and battery items. Calendar renders only a label and no icon. Battery can appear to the right of calendar depending on item source order, so the date/time is not guaranteed to be the final visual anchor.

The tmux config uses a flat status style with braille bracket cues for active windows. For SketchyBar, the desired adaptation is more subtle: a muted braille separator near the date/time rather than heavy segment brackets everywhere.

SoundSource currently works as a hotkey launcher, but the user wants it hidden/shelved for now while keeping the source file around for later.

## Design

Update the right-side SketchyBar order to prioritize signal and a stable final anchor:

```bash
source "$ITEM_DIR/spotify.sh"
# source "$ITEM_DIR/app_soundsource.sh" # shelved for now
source "$ITEM_DIR/battery.sh"
source "$ITEM_DIR/calendar.sh"
```

This keeps Spotify and battery to the left of date/time and makes calendar/date the last sourced right item.

Update the calendar item so it owns a muted braille separator icon:

- icon drawing on;
- icon glyph `⣿`;
- icon color `GREY`;
- label remains the formatted date/time;
- plugin remains responsible only for updating the label.

The separator should be subtle and not introduce popup/control behavior.

## Files

- Modify `dot_config/sketchybar/executable_sketchybarrc` to reorder right-side item sourcing and comment out SoundSource.
- Modify `dot_config/sketchybar/items/calendar.sh` to show the braille separator icon.
- Keep `dot_config/sketchybar/items/app_soundsource.sh` unchanged so the item can be restored later.
- Add or update focused shell tests for right-side order and calendar separator setup.

## Failure handling

No new runtime failure modes are expected. If Spotify or battery are hidden by their own plugins, calendar/date should remain visible and anchored at the far right.

## Deferred work

Do not implement paired separators for every dynamic right-side module in this slice. If the single calendar separator feels too sparse after dogfooding, add dynamic paired separators later.

Do not delete SoundSource files or tests; only stop sourcing the item from the bar config.

## Verification

Before implementation is complete:

- test that `app_soundsource.sh` is commented out, not deleted;
- test that right-side source order places `calendar.sh` after `battery.sh`;
- test that calendar has icon `⣿`, icon color `GREY`, and label remains script-driven;
- syntax-check touched shell files with `bash -n`;
- run `shellcheck` for touched shell files and tests;
- run the full `tests/chezmoi/*.sh` shell suite;
- run a CI-style `chezmoi apply --dry-run --exclude=externals` render check;
- manually apply/reload SketchyBar and confirm date/time is the far-right visual anchor.
