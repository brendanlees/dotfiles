# SketchyBar Spotify Now Playing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a right-side SketchyBar item that shows a truncated `Artist — Title` label while Spotify is playing and hides when Spotify is inactive.

**Architecture:** Keep the existing SketchyBar item/plugin split. `items/spotify.sh` defines the right-side item, icon, click action, and polling interval. `plugins/executable_spotify.sh` queries Spotify through AppleScript, formats/truncates text, and updates item visibility.

**Tech Stack:** chezmoi source files, Bash, SketchyBar CLI, Spotify AppleScript, Python 3 for Unicode-safe truncation in the plugin and for test assertions.

## Global Constraints

- Work in `/Users/brendan/.local/share/chezmoi.feat-sketchybar-spotify-now-playing` on branch `feat/sketchybar-spotify-now-playing`.
- The item is Spotify-specific; do not implement generic media support.
- Show the item only when Spotify player state is `playing`.
- Hide the item when Spotify is paused, stopped, not running, or AppleScript fails.
- Display text format is `Artist — Title` with an em dash and spaces.
- Truncate display text to 40 characters by default and append `…` when truncated.
- Poll with `update_freq=15`; do not add event integration in this slice.
- Click action opens/activates Spotify.
- Do not implement playback controls, popups, album art, Web API auth, or progress indicators.

---

## File Structure

- Create `tests/chezmoi/test-sketchybar-spotify-now-playing.sh`: focused regression test with stubbed `sketchybar` and `osascript` commands.
- Create `dot_config/sketchybar/items/spotify.sh`: right-side SketchyBar item definition.
- Create `dot_config/sketchybar/plugins/executable_spotify.sh`: Spotify AppleScript status plugin.
- Modify `dot_config/sketchybar/executable_sketchybarrc`: source `spotify.sh` in the right-side item section.

---

### Task 1: Add Spotify now-playing regression test

**Files:**
- Create: `tests/chezmoi/test-sketchybar-spotify-now-playing.sh`

**Interfaces:**
- Consumes: source files `dot_config/sketchybar/items/spotify.sh` and `dot_config/sketchybar/plugins/executable_spotify.sh` once later tasks create them.
- Produces: executable test command `bash tests/chezmoi/test-sketchybar-spotify-now-playing.sh` that validates playing, paused, not-running, truncation, and item setup behavior.

- [ ] **Step 1: Create the failing test file**

Create `tests/chezmoi/test-sketchybar-spotify-now-playing.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="${TMPDIR:-/tmp}/sketchybar-spotify-now-playing-test-$$"
CONFIG="$TMP/config"
BIN="$TMP/bin"
LOG="$TMP/sketchybar.log"
mkdir -p "$CONFIG/plugins" "$BIN"
trap 'rm -rf "$TMP"' EXIT

cat > "$CONFIG/colors.sh" <<'SH'
#!/bin/bash
export ICON_COLOR=0xffffffff
export LABEL_COLOR=0xffeeeeee
export GREY=0xff808080
SH

cp "$ROOT/dot_config/sketchybar/plugins/executable_spotify.sh" "$CONFIG/plugins/spotify.sh" 2>/dev/null || : > "$CONFIG/plugins/spotify.sh"
chmod +x "$CONFIG/plugins/spotify.sh"

cat > "$BIN/sketchybar" <<'SH'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$SKETCHYBAR_STUB_LOG"
SH
chmod +x "$BIN/sketchybar"

cat > "$BIN/osascript" <<'SH'
#!/usr/bin/env sh
script="$*"
scenario="${SPOTIFY_SCENARIO:-playing}"

case "$script" in
  *'application "Spotify" is running'*)
    if [ "$scenario" = "not_running" ]; then
      printf 'false\n'
    else
      printf 'true\n'
    fi
    ;;
  *'player state as string'*)
    case "$scenario" in
      paused) printf 'paused\n' ;;
      stopped) printf 'stopped\n' ;;
      *) printf 'playing\n' ;;
    esac
    ;;
  *'artist of current track'*)
    case "$scenario" in
      long) printf 'Very Long Artist Name\n' ;;
      empty) printf '\n' ;;
      *) printf 'Emma Ruth Rundle\n' ;;
    esac
    ;;
  *'name of current track'*)
    case "$scenario" in
      long) printf 'Extremely Long Track Title\n' ;;
      empty) printf '\n' ;;
      *) printf 'Haunted Houses\n' ;;
    esac
    ;;
  *)
    printf 'unexpected osascript: %s\n' "$script" >&2
    exit 1
    ;;
esac
SH
chmod +x "$BIN/osascript"

run_plugin() {
  PATH="$BIN:$PATH" CONFIG_DIR="$CONFIG" SKETCHYBAR_STUB_LOG="$LOG" NAME=spotify "$CONFIG/plugins/spotify.sh"
}

assert_log_contains() {
  local needle=$1
  python3 - "$LOG" "$needle" <<'PY'
import pathlib
import sys
log = pathlib.Path(sys.argv[1]).read_text()
needle = sys.argv[2]
assert needle in log, f"missing {needle!r} in:\n{log}"
PY
}

: > "$LOG"
SPOTIFY_SCENARIO=playing run_plugin
assert_log_contains 'spotify drawing=on'
assert_log_contains 'icon=:spotify:'
assert_log_contains 'label=Emma Ruth Rundle — Haunted Houses'

: > "$LOG"
SPOTIFY_SCENARIO=paused run_plugin
assert_log_contains 'spotify drawing=off'

: > "$LOG"
SPOTIFY_SCENARIO=not_running run_plugin
assert_log_contains 'spotify drawing=off'

: > "$LOG"
SPOTIFY_SCENARIO=empty run_plugin
assert_log_contains 'spotify drawing=off'

: > "$LOG"
SPOTIFY_SCENARIO=long SPOTIFY_LABEL_MAX_CHARS=20 run_plugin
assert_log_contains 'spotify drawing=on'
assert_log_contains 'label=Very Long Artist Na…'

: > "$LOG"
CONFIG_DIR="$CONFIG" ITEM_DIR="$CONFIG/items" PLUGIN_DIR="$CONFIG/plugins" FONT="JetBrainsMono Nerd Font Mono" ICON_COLOR=0xffffffff SKETCHYBAR_STUB_LOG="$LOG" PATH="$BIN:$PATH" bash "$ROOT/dot_config/sketchybar/items/spotify.sh"
assert_log_contains '--add item spotify right'
assert_log_contains 'icon=:spotify:'
assert_log_contains 'icon.font=sketchybar-app-font:Regular:16.0'
assert_log_contains 'drawing=off'
assert_log_contains 'update_freq=15'
assert_log_contains 'script='
assert_log_contains 'spotify.sh'
assert_log_contains 'tell application "Spotify" to activate'
```

- [ ] **Step 2: Make the test executable**

Run:

```bash
chmod +x tests/chezmoi/test-sketchybar-spotify-now-playing.sh
```

Expected: command exits 0.

- [ ] **Step 3: Run the test and verify it fails against current code**

Run:

```bash
bash tests/chezmoi/test-sketchybar-spotify-now-playing.sh
```

Expected: FAIL because `dot_config/sketchybar/plugins/executable_spotify.sh` and `dot_config/sketchybar/items/spotify.sh` do not exist yet.

- [ ] **Step 4: Commit the failing regression test**

Run:

```bash
git add tests/chezmoi/test-sketchybar-spotify-now-playing.sh
git commit -m "test: cover sketchybar spotify now playing"
```

Expected: commit succeeds with only the new test staged.

---

### Task 2: Add Spotify AppleScript plugin

**Files:**
- Create: `dot_config/sketchybar/plugins/executable_spotify.sh`
- Test: `tests/chezmoi/test-sketchybar-spotify-now-playing.sh`

**Interfaces:**
- Consumes: Spotify AppleScript commands for running state, player state, current track artist, and current track title.
- Produces: target plugin `spotify.sh` that sets `$NAME` drawing on with `icon=:spotify:` and truncated label while playing; otherwise sets drawing off.

- [ ] **Step 1: Confirm the regression test currently fails at the playing-state assertion**

Run:

```bash
bash tests/chezmoi/test-sketchybar-spotify-now-playing.sh
```

Expected: FAIL with a Python assertion containing `missing 'spotify drawing=on'`.

- [ ] **Step 2: Create `plugins/executable_spotify.sh`**

Create `dot_config/sketchybar/plugins/executable_spotify.sh` with this exact content:

```bash
#!/bin/bash

CONFIG_DIR="${CONFIG_DIR:-${HOME}/.config/sketchybar}"
# shellcheck source=dot_config/sketchybar/colors.sh
source "$CONFIG_DIR/colors.sh"

hide_item() {
  sketchybar --set "$NAME" drawing=off label=""
}

is_running="$(osascript -e 'application "Spotify" is running' 2>/dev/null || true)"
if [ "$is_running" != "true" ]; then
  hide_item
  exit 0
fi

player_state="$(osascript -e 'tell application "Spotify" to player state as string' 2>/dev/null || true)"
if [ "$player_state" != "playing" ]; then
  hide_item
  exit 0
fi

artist="$(osascript -e 'tell application "Spotify" to artist of current track' 2>/dev/null || true)"
title="$(osascript -e 'tell application "Spotify" to name of current track' 2>/dev/null || true)"

if [ -n "$artist" ] && [ -n "$title" ]; then
  track="$artist — $title"
elif [ -n "$title" ]; then
  track="$title"
elif [ -n "$artist" ]; then
  track="$artist"
else
  hide_item
  exit 0
fi

max_chars="${SPOTIFY_LABEL_MAX_CHARS:-40}"
label="$(/usr/bin/python3 - "$track" "$max_chars" <<'PY'
import sys

text = sys.argv[1]
try:
    max_chars = int(sys.argv[2])
except Exception:
    max_chars = 40

if max_chars < 2:
    max_chars = 2

if len(text) > max_chars:
    text = text[: max_chars - 1] + "…"

print(text)
PY
)"

sketchybar --set "$NAME" \
  drawing=on \
  icon=":spotify:" \
  icon.color="$ICON_COLOR" \
  label="$label" \
  label.color="$LABEL_COLOR"
```

- [ ] **Step 3: Syntax-check the plugin**

Run:

```bash
bash -n dot_config/sketchybar/plugins/executable_spotify.sh
```

Expected: command exits 0.

- [ ] **Step 4: Run the regression test and verify plugin assertions pass**

Run:

```bash
bash tests/chezmoi/test-sketchybar-spotify-now-playing.sh
```

Expected: FAIL later at an item setup assertion such as `missing '--add item spotify right'`, not at playing, paused, not-running, empty, or truncation assertions.

- [ ] **Step 5: Commit the plugin**

Run:

```bash
git add dot_config/sketchybar/plugins/executable_spotify.sh
git commit -m "feat: add spotify now playing plugin"
```

Expected: commit succeeds with only the new plugin staged.

---

### Task 3: Add and source Spotify SketchyBar item

**Files:**
- Create: `dot_config/sketchybar/items/spotify.sh`
- Modify: `dot_config/sketchybar/executable_sketchybarrc`
- Test: `tests/chezmoi/test-sketchybar-spotify-now-playing.sh`

**Interfaces:**
- Consumes: `$PLUGIN_DIR/spotify.sh`, generated from `plugins/executable_spotify.sh`.
- Produces: right-side item named `spotify`, initially hidden, polling every 15 seconds, clickable to activate Spotify.

- [ ] **Step 1: Confirm the regression test currently fails at item setup**

Run:

```bash
bash tests/chezmoi/test-sketchybar-spotify-now-playing.sh
```

Expected: FAIL with a Python assertion containing `missing '--add item spotify right'`.

- [ ] **Step 2: Create `items/spotify.sh`**

Create `dot_config/sketchybar/items/spotify.sh` with this exact content:

```bash
#!/bin/bash

sketchybar --add item spotify right \
  --set spotify \
    drawing=off \
    icon=":spotify:" \
    icon.font="sketchybar-app-font:Regular:16.0" \
    icon.color="$ICON_COLOR" \
    label.font="$FONT:Regular:13.0" \
    label.color="$LABEL_COLOR" \
    update_freq=15 \
    script="$PLUGIN_DIR/spotify.sh" \
    click_script="osascript -e 'tell application \"Spotify\" to activate'"
```

- [ ] **Step 3: Source the item in `executable_sketchybarrc`**

In `dot_config/sketchybar/executable_sketchybarrc`, change the right item section from:

```bash
source "$ITEM_DIR/app_soundsource.sh"
source "$ITEM_DIR/calendar.sh"
source "$ITEM_DIR/battery.sh"
```

to:

```bash
source "$ITEM_DIR/spotify.sh"
source "$ITEM_DIR/app_soundsource.sh"
source "$ITEM_DIR/calendar.sh"
source "$ITEM_DIR/battery.sh"
```

- [ ] **Step 4: Syntax-check the item and bar config**

Run:

```bash
bash -n dot_config/sketchybar/items/spotify.sh
bash -n dot_config/sketchybar/executable_sketchybarrc
```

Expected: both commands exit 0.

- [ ] **Step 5: Run the regression test and verify all assertions pass**

Run:

```bash
bash tests/chezmoi/test-sketchybar-spotify-now-playing.sh
```

Expected: PASS with no output.

- [ ] **Step 6: Verify `sketchybarrc` sources the item exactly once**

Run:

```bash
test "$(grep -c 'spotify.sh' dot_config/sketchybar/executable_sketchybarrc)" -eq 1
```

Expected: command exits 0.

- [ ] **Step 7: Commit the item wiring**

Run:

```bash
git add dot_config/sketchybar/items/spotify.sh dot_config/sketchybar/executable_sketchybarrc
git commit -m "feat: show spotify now playing in sketchybar"
```

Expected: commit succeeds with only the item and `sketchybarrc` staged.

---

### Task 4: Run final verification and record manual checks

**Files:**
- No source changes expected unless verification reveals a defect.

**Interfaces:**
- Consumes: all changes from Tasks 1–3.
- Produces: verified branch ready to merge or keep for review.

- [ ] **Step 1: Run the targeted Spotify test**

Run:

```bash
bash tests/chezmoi/test-sketchybar-spotify-now-playing.sh
```

Expected: PASS with no output.

- [ ] **Step 2: Syntax-check touched shell files**

Run:

```bash
bash -n dot_config/sketchybar/items/spotify.sh
bash -n dot_config/sketchybar/plugins/executable_spotify.sh
bash -n dot_config/sketchybar/executable_sketchybarrc
```

Expected: all commands exit 0.

- [ ] **Step 3: Run shellcheck on touched files and test**

Run:

```bash
shellcheck -e SC1091 \
  dot_config/sketchybar/items/spotify.sh \
  dot_config/sketchybar/plugins/executable_spotify.sh \
  dot_config/sketchybar/executable_sketchybarrc \
  tests/chezmoi/test-sketchybar-spotify-now-playing.sh
```

Expected: command exits 0.

- [ ] **Step 4: Run the full chezmoi shell test suite**

Run:

```bash
for test in tests/chezmoi/*.sh; do
  echo "==> $test"
  bash "$test"
done
```

Expected: every test exits 0.

- [ ] **Step 5: Run CI-style chezmoi dry-run verification**

Run:

```bash
cfg=/tmp/chezmoi-spotify-ci-config.toml
CHEZMOI_ROLE=ephemeral,headless chezmoi init --source="$PWD" --config="$cfg" --apply=false
CHEZMOI_ROLE=ephemeral,headless chezmoi apply --source "$PWD" --config="$cfg" --dry-run --verbose --exclude=externals >/tmp/chezmoi-spotify-dry-run.log
```

Expected: both commands exit 0. The dry-run output may list would-change paths, but it must not contain template render errors.

- [ ] **Step 6: Run changed-file audit if available**

Run:

```bash
if command -v fallow >/dev/null 2>&1; then
  fallow audit --changed-since main
else
  echo "fallow not installed; skipped changed-file audit"
fi
```

Expected: either `fallow` exits 0 or the command prints `fallow not installed; skipped changed-file audit`.

- [ ] **Step 7: Inspect final diff**

Run:

```bash
git diff --stat main...HEAD
git diff --check main...HEAD
git status --short --branch
```

Expected: stat lists only the planned docs, SketchyBar, and test files; `git diff --check` exits 0; working tree is clean.

- [ ] **Step 8: Report manual follow-up checks**

Report this checklist to the user:

```text
Manual follow-up after applying config:
- Run `chezmoi apply` and `sketchybar --reload`.
- Start Spotify playback and confirm the Spotify item appears on the right.
- Confirm the label is `Artist — Title` and is truncated for long tracks.
- Pause or stop Spotify and confirm the item hides after the 15-second refresh or `sketchybar --update`.
- Click the item and confirm Spotify activates.
```

Expected: user receives the manual checklist with the automated verification results.
