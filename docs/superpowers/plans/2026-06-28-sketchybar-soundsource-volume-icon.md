# SketchyBar SoundSource Volume Icon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the existing unused SoundSource SketchyBar item into a compact icon-only status item that shows active, silent, or unknown hardware/display volume state and opens SoundSource on click.

**Architecture:** Keep the current SketchyBar item/plugin split. `items/app_soundsource.sh` defines the right-side item and launcher behavior; `plugins/executable_soundsource.sh` reads BetterDisplay's DDC-backed `volume` property and maps it to icon/color state. `icons.sh` owns reusable volume glyph names, and `executable_sketchybarrc` wires the item into the right side.

**Tech Stack:** chezmoi source files, Bash, SketchyBar CLI, BetterDisplay CLI (`betterdisplaycli` or `BetterDisplayCLI`), Python 3 only for bounded subprocess timeout/parsing in the plugin and for test assertions.

> Superseded: SoundSource status polling was dropped after dogfooding. The item is now launcher-only and sends the SoundSource widget hotkey.

## Global Constraints

- Work in `/Users/brendan/.local/share/chezmoi.feat-sketchybar-soundsource-volume-icon` on branch `feat/sketchybar-soundsource-volume-icon`.
- The bar item is icon-only: no percentage label and no popup in this slice.
- The item click action must continue to activate SoundSource.
- Status source is BetterDisplay CLI `get -volume`, representing hardware/display output volume rather than SoundSource per-app state.
- Interpret BetterDisplay volume values greater than `0` as active/audible.
- Interpret BetterDisplay volume value `0` as silent/muted-ish.
- Treat missing BetterDisplay CLI, command failure, timeout, or unparsable output as unknown.
- Poll at `update_freq=60`; do not add high-frequency polling or event integration in this slice.
- Do not implement input/microphone status, output device names, popups, Shortcuts integration, or volume-setting controls.

---

## File Structure

- Create `tests/chezmoi/test-sketchybar-soundsource-volume-icon.sh`: focused regression test with stubbed `sketchybar`, `betterdisplaycli`, and `BetterDisplayCLI` commands.
- Modify `dot_config/sketchybar/icons.sh`: add volume icon exports for active, muted, and unknown states.
- Create `dot_config/sketchybar/plugins/executable_soundsource.sh`: read BetterDisplay volume with a timeout and set the item icon/color.
- Modify `dot_config/sketchybar/items/app_soundsource.sh`: make the existing SoundSource item script-driven, icon-only, and low-frequency.
- Modify `dot_config/sketchybar/executable_sketchybarrc`: source `app_soundsource.sh` in the right-side item section.

---

### Task 1: Add SoundSource volume icon regression test

**Files:**
- Create: `tests/chezmoi/test-sketchybar-soundsource-volume-icon.sh`

**Interfaces:**
- Consumes: source scripts under `dot_config/sketchybar/`.
- Produces: executable test command `bash tests/chezmoi/test-sketchybar-soundsource-volume-icon.sh` that later tasks must make pass.

- [ ] **Step 1: Create the failing test file**

Create `tests/chezmoi/test-sketchybar-soundsource-volume-icon.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="${TMPDIR:-/tmp}/sketchybar-soundsource-volume-icon-test-$$"
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
export ORANGE=0xffffa500
SH

cp "$ROOT/dot_config/sketchybar/icons.sh" "$CONFIG/icons.sh"
cp "$ROOT/dot_config/sketchybar/plugins/executable_soundsource.sh" "$CONFIG/plugins/soundsource.sh" 2>/dev/null || : > "$CONFIG/plugins/soundsource.sh"
chmod +x "$CONFIG/plugins/soundsource.sh"

cat > "$BIN/sketchybar" <<'SH'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$SKETCHYBAR_STUB_LOG"
SH
chmod +x "$BIN/sketchybar"

cat > "$BIN/betterdisplaycli" <<'SH'
#!/usr/bin/env sh
case "${BETTERDISPLAY_SCENARIO:-active}" in
  active)
    printf '1.0\n'
    ;;
  silent)
    printf '0\n'
    ;;
  invalid)
    printf 'not-a-number\n'
    ;;
  fail)
    exit 1
    ;;
esac
SH
chmod +x "$BIN/betterdisplaycli"

run_plugin() {
  PATH="$BIN:$PATH" CONFIG_DIR="$CONFIG" SKETCHYBAR_STUB_LOG="$LOG" NAME=soundsource "$CONFIG/plugins/soundsource.sh"
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
BETTERDISPLAY_SCENARIO=active run_plugin
assert_log_contains 'soundsource icon=󰕾'
assert_log_contains 'icon.color=0xffffffff'
assert_log_contains 'label.drawing=off'

: > "$LOG"
BETTERDISPLAY_SCENARIO=silent run_plugin
assert_log_contains 'soundsource icon=󰖁'
assert_log_contains 'icon.color=0xffffa500'
assert_log_contains 'label.drawing=off'

: > "$LOG"
BETTERDISPLAY_SCENARIO=invalid run_plugin
assert_log_contains 'soundsource icon=󰕾'
assert_log_contains 'icon.color=0xff808080'
assert_log_contains 'label.drawing=off'

: > "$LOG"
PATH="/usr/bin:/bin:/usr/sbin:/sbin" CONFIG_DIR="$CONFIG" SKETCHYBAR_STUB_LOG="$LOG" NAME=soundsource "$CONFIG/plugins/soundsource.sh"
assert_log_contains 'soundsource icon=󰕾'
assert_log_contains 'icon.color=0xff808080'
assert_log_contains 'label.drawing=off'

: > "$LOG"
CONFIG_DIR="$CONFIG" ITEM_DIR="$CONFIG/items" PLUGIN_DIR="$CONFIG/plugins" FONT="JetBrainsMono Nerd Font Mono" ICON_COLOR=0xffffffff GREY=0xff808080 SKETCHYBAR_STUB_LOG="$LOG" PATH="$BIN:$PATH" bash "$ROOT/dot_config/sketchybar/items/app_soundsource.sh"
assert_log_contains '--add item soundsource right'
assert_log_contains 'update_freq=60'
assert_log_contains 'script='
assert_log_contains 'soundsource.sh'
assert_log_contains 'click_script=osascript -e'
```

- [ ] **Step 2: Make the test executable**

Run:

```bash
chmod +x tests/chezmoi/test-sketchybar-soundsource-volume-icon.sh
```

Expected: command exits 0.

- [ ] **Step 3: Run the test and verify it fails against current code**

Run:

```bash
bash tests/chezmoi/test-sketchybar-soundsource-volume-icon.sh
```

Expected: FAIL because `dot_config/sketchybar/plugins/executable_soundsource.sh` does not exist yet and the current item does not set `update_freq=60` or `script="$PLUGIN_DIR/soundsource.sh"`.

- [ ] **Step 4: Commit the failing regression test**

Run:

```bash
git add tests/chezmoi/test-sketchybar-soundsource-volume-icon.sh
git commit -m "test: cover sketchybar soundsource volume icon"
```

Expected: commit succeeds with only the new test file staged.

---

### Task 2: Add volume icon exports and BetterDisplay-backed plugin

**Files:**
- Modify: `dot_config/sketchybar/icons.sh`
- Create: `dot_config/sketchybar/plugins/executable_soundsource.sh`
- Test: `tests/chezmoi/test-sketchybar-soundsource-volume-icon.sh`

**Interfaces:**
- Consumes: `betterdisplaycli get -volume` or `BetterDisplayCLI get -volume`, returning a scalar such as `1.0` or `0`.
- Produces: `plugins/soundsource.sh` target script that sets `icon`, `icon.color`, and `label.drawing=off` for the SketchyBar item named by `$NAME`.

- [ ] **Step 1: Confirm the regression test currently fails at the active-state assertion**

Run:

```bash
bash tests/chezmoi/test-sketchybar-soundsource-volume-icon.sh
```

Expected: FAIL with a Python assertion containing `missing 'soundsource icon=󰕾'`.

- [ ] **Step 2: Add reusable volume icons to `icons.sh`**

Append this block to `dot_config/sketchybar/icons.sh` after the calendar icons:

```bash

# volume
export ICON_VOLUME=󰕾
export ICON_VOLUME_MUTED=󰖁
export ICON_VOLUME_UNKNOWN=󰕾
```

- [ ] **Step 3: Create `plugins/executable_soundsource.sh`**

Create `dot_config/sketchybar/plugins/executable_soundsource.sh` with this exact content:

```bash
#!/bin/bash

CONFIG_DIR="${CONFIG_DIR:-${HOME}/.config/sketchybar}"
# shellcheck source=dot_config/sketchybar/colors.sh
source "$CONFIG_DIR/colors.sh"
# shellcheck source=dot_config/sketchybar/icons.sh
source "$CONFIG_DIR/icons.sh"

betterdisplay_bin="$(command -v betterdisplaycli || command -v BetterDisplayCLI || true)"
state="unknown"

if [ -n "$betterdisplay_bin" ] && [ -x "$betterdisplay_bin" ] && [ -x /usr/bin/python3 ]; then
  state="$(/usr/bin/python3 - "$betterdisplay_bin" <<'PY' 2>/dev/null || printf 'unknown'
import subprocess
import sys

try:
    result = subprocess.run(
        [sys.argv[1], "get", "-volume"],
        capture_output=True,
        check=True,
        text=True,
        timeout=3,
    )
    first_line = result.stdout.strip().splitlines()[0]
    volume = float(first_line)
except Exception:
    print("unknown")
    sys.exit(0)

if volume <= 0:
    print("silent")
else:
    print("active")
PY
)"
fi

case "$state" in
  active)
    icon="$ICON_VOLUME"
    color="$ICON_COLOR"
    ;;
  silent)
    icon="$ICON_VOLUME_MUTED"
    color="$ORANGE"
    ;;
  *)
    icon="$ICON_VOLUME_UNKNOWN"
    color="$GREY"
    ;;
esac

sketchybar --set "$NAME" \
  icon="$icon" \
  icon.color="$color" \
  label.drawing=off
```

- [ ] **Step 4: Syntax-check the new plugin and icons file**

Run:

```bash
bash -n dot_config/sketchybar/icons.sh
bash -n dot_config/sketchybar/plugins/executable_soundsource.sh
```

Expected: both commands exit 0.

- [ ] **Step 5: Run the regression test and verify plugin assertions pass**

Run:

```bash
bash tests/chezmoi/test-sketchybar-soundsource-volume-icon.sh
```

Expected: FAIL later at `missing 'update_freq=60'`, not at active, silent, invalid, or missing BetterDisplay plugin state assertions.

- [ ] **Step 6: Commit the plugin change**

Run:

```bash
git add dot_config/sketchybar/icons.sh dot_config/sketchybar/plugins/executable_soundsource.sh
git commit -m "feat: add soundsource volume status plugin"
```

Expected: commit succeeds with only `icons.sh` and the new plugin staged.

---

### Task 3: Wire the SoundSource item into SketchyBar

**Files:**
- Modify: `dot_config/sketchybar/items/app_soundsource.sh`
- Modify: `dot_config/sketchybar/executable_sketchybarrc`
- Test: `tests/chezmoi/test-sketchybar-soundsource-volume-icon.sh`

**Interfaces:**
- Consumes: `$PLUGIN_DIR/soundsource.sh` target script produced from `plugins/executable_soundsource.sh`.
- Produces: right-side SketchyBar item named `soundsource` with `update_freq=60`, icon-only status, and click-to-open SoundSource behavior.

- [ ] **Step 1: Confirm the regression test currently fails at item wiring**

Run:

```bash
bash tests/chezmoi/test-sketchybar-soundsource-volume-icon.sh
```

Expected: FAIL with a Python assertion containing `missing 'update_freq=60'`.

- [ ] **Step 2: Replace `items/app_soundsource.sh` with script-driven item setup**

Replace the full file `dot_config/sketchybar/items/app_soundsource.sh` with:

```bash
#!/bin/bash

sketchybar --add item soundsource right \
  --set soundsource \
    icon="$ICON_VOLUME_UNKNOWN" \
    icon.font="$FONT:Bold:16.0" \
    icon.color="$GREY" \
    label.drawing=off \
    update_freq=60 \
    script="$PLUGIN_DIR/soundsource.sh" \
    click_script="osascript -e 'tell application \"SoundSource\" to activate'"
```

- [ ] **Step 3: Source the item in `executable_sketchybarrc`**

In `dot_config/sketchybar/executable_sketchybarrc`, change the right item section from:

```bash
source "$ITEM_DIR/calendar.sh"
source "$ITEM_DIR/battery.sh"
```

to:

```bash
source "$ITEM_DIR/app_soundsource.sh"
source "$ITEM_DIR/calendar.sh"
source "$ITEM_DIR/battery.sh"
```

- [ ] **Step 4: Syntax-check the touched files**

Run:

```bash
bash -n dot_config/sketchybar/items/app_soundsource.sh
bash -n dot_config/sketchybar/executable_sketchybarrc
```

Expected: both commands exit 0.

- [ ] **Step 5: Run the regression test and verify all assertions pass**

Run:

```bash
bash tests/chezmoi/test-sketchybar-soundsource-volume-icon.sh
```

Expected: PASS with no output.

- [ ] **Step 6: Verify `sketchybarrc` sources the item exactly once**

Run:

```bash
test "$(grep -c 'app_soundsource.sh' dot_config/sketchybar/executable_sketchybarrc)" -eq 1
```

Expected: command exits 0.

- [ ] **Step 7: Commit the wiring change**

Run:

```bash
git add dot_config/sketchybar/items/app_soundsource.sh dot_config/sketchybar/executable_sketchybarrc
git commit -m "feat: show soundsource volume icon in sketchybar"
```

Expected: commit succeeds with only the item and `sketchybarrc` staged.

---

### Task 4: Run final verification and record manual checks

**Files:**
- No source changes expected unless verification reveals a defect.

**Interfaces:**
- Consumes: all changes from Tasks 1–3.
- Produces: verified branch ready to merge or keep for review.

- [ ] **Step 1: Run the targeted SoundSource test**

Run:

```bash
bash tests/chezmoi/test-sketchybar-soundsource-volume-icon.sh
```

Expected: PASS with no output.

- [ ] **Step 2: Syntax-check all touched SketchyBar shell files**

Run:

```bash
bash -n dot_config/sketchybar/icons.sh
bash -n dot_config/sketchybar/items/app_soundsource.sh
bash -n dot_config/sketchybar/plugins/executable_soundsource.sh
bash -n dot_config/sketchybar/executable_sketchybarrc
```

Expected: all commands exit 0.

- [ ] **Step 3: Run shellcheck on touched shell files and the new test**

Run:

```bash
shellcheck -e SC1091 \
  dot_config/sketchybar/icons.sh \
  dot_config/sketchybar/items/app_soundsource.sh \
  dot_config/sketchybar/plugins/executable_soundsource.sh \
  dot_config/sketchybar/executable_sketchybarrc \
  tests/chezmoi/test-sketchybar-soundsource-volume-icon.sh
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
cfg=/tmp/chezmoi-soundsource-ci-config.toml
CHEZMOI_ROLE=ephemeral,headless chezmoi init --source="$PWD" --config="$cfg" --apply=false
CHEZMOI_ROLE=ephemeral,headless chezmoi apply --source "$PWD" --config="$cfg" --dry-run --verbose --exclude=externals >/tmp/chezmoi-soundsource-dry-run.log
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
- Confirm the SoundSource icon appears on the right side.
- Confirm clicking the icon opens SoundSource.
- Confirm `betterdisplaycli get -volume` greater than 0 shows the active volume icon.
- If practical, set the display volume to 0 and confirm the muted icon appears after the 60-second refresh or `sketchybar --update`.
- If BetterDisplay CLI is unavailable or DDC volume cannot be read, confirm the item falls back to the grey unknown icon.
```

Expected: user receives the manual checklist with the automated verification results.
