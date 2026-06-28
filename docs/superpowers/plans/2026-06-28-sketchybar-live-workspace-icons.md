# SketchyBar Live Workspace Icons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make SketchyBar workspace items keep their workspace number while showing a representative live app icon from AeroSpace state, add app-font icons to the front-app item, and hide battery while on AC power.

**Architecture:** Keep the existing SketchyBar item/plugin split. `items/spaces.sh` defines workspace item layout and subscriptions; `plugins/executable_aerospace.sh` becomes the event-driven workspace state updater that queries AeroSpace JSON and maps app names through `icon_map.sh`. `plugins/executable_front_app.sh` maps the active app name through the same icon map, and `plugins/executable_battery.sh` becomes exception-only by hiding on AC power.

**Tech Stack:** chezmoi source files, Bash, SketchyBar CLI, AeroSpace CLI JSON output, `font-sketchybar-app-font`, Python 3 for test assertions and robust JSON parsing inside the workspace updater.

## Global Constraints

- Work in `/Users/brendan/.local/share/chezmoi.feat-sketchybar-live-workspace-icons` on branch `feat/sketchybar-live-workspace-icons`.
- Preserve workspace-number muscle memory: each workspace item must continue to display the numeric prefix from the AeroSpace workspace name.
- Workspace app icons must be derived from live AeroSpace window/app state, not workspace name suffixes such as `browser`, `code`, or `files`.
- Use only one representative app icon per workspace in this slice; do not render every app in a workspace.
- If a workspace has no windows, render number-only state by hiding the app-icon label.
- Reuse `dot_config/sketchybar/plugins/executable_icon_map.sh` as the app-name-to-icon boundary.
- Keep `dot_config/sketchybar/items/app_itsycal.sh` and `dot_config/sketchybar/items/app_soundsource.sh` unsourced in this slice.
- Hide the battery item when `pmset` reports AC power or when no battery percentage is available.
- Avoid high-frequency polling; `update_freq=60` is the maximum safety refresh rate for workspace app icons.

---

## File Structure

- Create `tests/chezmoi/test-sketchybar-live-workspace-icons.sh`: regression test harness with fake `sketchybar`, `aerospace`, and `pmset` commands. It exercises front-app icon mapping, battery hide/show behavior, and live workspace app icon behavior without requiring a running SketchyBar instance.
- Modify `dot_config/sketchybar/items/front_app.sh`: enable the front-app icon, set it to use `sketchybar-app-font`, and keep the app name as the label.
- Modify `dot_config/sketchybar/plugins/executable_front_app.sh`: on `front_app_switched`, call `icon_map.sh` and set both icon and label.
- Modify `dot_config/sketchybar/plugins/executable_battery.sh`: parse `pmset` once, hide on AC/no percentage, otherwise keep existing discharging thresholds.
- Modify `dot_config/sketchybar/items/spaces.sh`: keep workspace number as the item icon, use the item label for the live app icon, subscribe to `aerospace_workspace_change`, `front_app_switched`, and `system_woke`, and add `update_freq=60` as a safety refresh.
- Modify `dot_config/sketchybar/plugins/executable_aerospace.sh`: keep focus color/background behavior and add representative app selection from AeroSpace JSON.

---

### Task 1: Add SketchyBar regression test harness

**Files:**
- Create: `tests/chezmoi/test-sketchybar-live-workspace-icons.sh`

**Interfaces:**
- Consumes: existing source scripts under `dot_config/sketchybar/plugins/`.
- Produces: executable test command `bash tests/chezmoi/test-sketchybar-live-workspace-icons.sh` that later tasks must make pass.

- [ ] **Step 1: Create the failing test file**

Create `tests/chezmoi/test-sketchybar-live-workspace-icons.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="${TMPDIR:-/tmp}/sketchybar-live-workspace-icons-test-$$"
CONFIG="$TMP/config"
BIN="$TMP/bin"
LOG="$TMP/sketchybar.log"
mkdir -p "$CONFIG/plugins" "$BIN"
trap 'rm -rf "$TMP"' EXIT

cat > "$CONFIG/colors.sh" <<'SH'
#!/bin/bash
export WHITE=0xffffffff
export GREY=0xff808080
export GREEN=0xff00ff00
export YELLOW=0xffffff00
export ORANGE=0xffffa500
export RED=0xffff0000
export BLUE=0xff0000ff
SH

cp "$ROOT/dot_config/sketchybar/icons.sh" "$CONFIG/icons.sh"
cp "$ROOT/dot_config/sketchybar/plugins/executable_icon_map.sh" "$CONFIG/plugins/icon_map.sh"
cp "$ROOT/dot_config/sketchybar/plugins/executable_front_app.sh" "$CONFIG/plugins/front_app.sh"
cp "$ROOT/dot_config/sketchybar/plugins/executable_battery.sh" "$CONFIG/plugins/battery.sh"
cp "$ROOT/dot_config/sketchybar/plugins/executable_aerospace.sh" "$CONFIG/plugins/aerospace.sh"
chmod +x "$CONFIG/plugins/"*.sh

cat > "$BIN/sketchybar" <<'SH'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$SKETCHYBAR_STUB_LOG"
SH
chmod +x "$BIN/sketchybar"

cat > "$BIN/aerospace" <<'SH'
#!/usr/bin/env sh
mode=""
workspace=""
focused="no"
while [ "$#" -gt 0 ]; do
  case "$1" in
    list-workspaces) mode="workspaces" ;;
    list-windows) mode="windows" ;;
    --focused) focused="yes" ;;
    --workspace) shift; workspace="${1:-}" ;;
  esac
  shift || true
done

if [ "$mode" = "workspaces" ] && [ "$focused" = "yes" ]; then
  printf '4-files\n'
  exit 0
fi

if [ "$mode" = "windows" ]; then
  case "$workspace" in
    4-files)
      printf '[{"app-name":"Arc","window-id":41,"window-title":"Arc"}]\n'
      ;;
    2-code)
      printf '[{"app-name":"Ghostty","window-id":22,"window-title":"shell"},{"app-name":"Hermes","window-id":23,"window-title":"Hermes"}]\n'
      ;;
    6-misc1)
      printf '[]\n'
      ;;
    *)
      printf '[]\n'
      ;;
  esac
  exit 0
fi

exit 1
SH
chmod +x "$BIN/aerospace"

cat > "$BIN/pmset" <<'SH'
#!/usr/bin/env sh
case "${PMSET_SCENARIO:-ac}" in
  ac)
    cat <<'OUT'
Now drawing from 'AC Power'
 -InternalBattery-0 (id=1234567) 100%; charged; 0:00 remaining present: true
OUT
    ;;
  battery)
    cat <<'OUT'
Now drawing from 'Battery Power'
 -InternalBattery-0 (id=1234567) 42%; discharging; 2:10 remaining present: true
OUT
    ;;
esac
SH
chmod +x "$BIN/pmset"

run_plugin() {
  PATH="$BIN:$PATH" CONFIG_DIR="$CONFIG" SKETCHYBAR_STUB_LOG="$LOG" "$@"
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
SENDER=front_app_switched INFO=Arc NAME=front_app run_plugin "$CONFIG/plugins/front_app.sh"
assert_log_contains 'front_app icon=:arc:'
assert_log_contains 'label=Arc'

: > "$LOG"
PMSET_SCENARIO=ac NAME=battery run_plugin "$CONFIG/plugins/battery.sh"
assert_log_contains 'battery drawing=off'

: > "$LOG"
PMSET_SCENARIO=battery NAME=battery run_plugin "$CONFIG/plugins/battery.sh"
assert_log_contains 'battery drawing=on'
assert_log_contains 'label=42%'

: > "$LOG"
SENDER=front_app_switched INFO=Arc NAME=space.4-files FOCUSED_WORKSPACE=4-files run_plugin "$CONFIG/plugins/aerospace.sh" 4-files
assert_log_contains 'space.4-files background.drawing=on'
assert_log_contains 'icon.color=0xffffffff'
assert_log_contains 'label=:arc:'
assert_log_contains 'label.drawing=on'

: > "$LOG"
SENDER=aerospace_workspace_change NAME=space.2-code FOCUSED_WORKSPACE=4-files run_plugin "$CONFIG/plugins/aerospace.sh" 2-code
assert_log_contains 'space.2-code background.drawing=off'
assert_log_contains 'icon.color=0xff808080'
assert_log_contains 'label=:ghostty:'
assert_log_contains 'label.drawing=on'

: > "$LOG"
SENDER=aerospace_workspace_change NAME=space.6-misc1 FOCUSED_WORKSPACE=4-files run_plugin "$CONFIG/plugins/aerospace.sh" 6-misc1
assert_log_contains 'space.6-misc1 background.drawing=off'
assert_log_contains 'label.drawing=off'
```

- [ ] **Step 2: Make the test executable**

Run:

```bash
chmod +x tests/chezmoi/test-sketchybar-live-workspace-icons.sh
```

Expected: command exits 0.

- [ ] **Step 3: Run the test and verify it fails against current code**

Run:

```bash
bash tests/chezmoi/test-sketchybar-live-workspace-icons.sh
```

Expected: FAIL because the current `front_app.sh` plugin does not set `icon=:arc:`, the current battery plugin draws on AC power, and the current AeroSpace plugin does not set workspace app-icon labels.

- [ ] **Step 4: Commit the failing regression test**

Run:

```bash
git add tests/chezmoi/test-sketchybar-live-workspace-icons.sh
git commit -m "test: cover live sketchybar workspace signals"
```

Expected: commit succeeds with only the new test file staged.

---

### Task 2: Add app-font icon mapping to the front-app item

**Files:**
- Modify: `dot_config/sketchybar/items/front_app.sh`
- Modify: `dot_config/sketchybar/plugins/executable_front_app.sh`
- Test: `tests/chezmoi/test-sketchybar-live-workspace-icons.sh`

**Interfaces:**
- Consumes: `plugins/icon_map.sh APP_NAME -> APP_FONT_TOKEN` where unknown names return `:default:`.
- Produces: `front_app` SketchyBar item with `icon=<mapped app token>` and `label=<front app name>` on `front_app_switched`.

- [ ] **Step 1: Confirm the regression test currently fails at the front-app assertion**

Run:

```bash
bash tests/chezmoi/test-sketchybar-live-workspace-icons.sh
```

Expected: FAIL with a Python assertion containing `missing 'front_app icon=:arc:'`.

- [ ] **Step 2: Replace `items/front_app.sh` with icon-plus-label setup**

Replace the full file `dot_config/sketchybar/items/front_app.sh` with:

```bash
#!/bin/bash

sketchybar --add item front_app left \
  --set front_app \
    icon.font="sketchybar-app-font:Regular:16.0" \
    icon.padding_right=5 \
    label.font="$FONT:Semibold:13.0" \
    script="$PLUGIN_DIR/front_app.sh" \
  --subscribe front_app front_app_switched
```

- [ ] **Step 3: Replace `plugins/executable_front_app.sh` with icon mapping logic**

Replace the full file `dot_config/sketchybar/plugins/executable_front_app.sh` with:

```bash
#!/bin/bash

CONFIG_DIR="${CONFIG_DIR:-${HOME}/.config/sketchybar}"

if [ "$SENDER" = "front_app_switched" ]; then
  app_name="${INFO:-}"
  icon=":default:"
  icon_map="$CONFIG_DIR/plugins/icon_map.sh"

  if [ -n "$app_name" ] && [ -x "$icon_map" ]; then
    icon="$($icon_map "$app_name" 2>/dev/null || printf ':default:')"
  fi

  if [ -z "$icon" ]; then
    icon=":default:"
  fi

  sketchybar --set "$NAME" icon="$icon" label="$app_name"
fi
```

- [ ] **Step 4: Syntax-check the touched scripts**

Run:

```bash
bash -n dot_config/sketchybar/items/front_app.sh
bash -n dot_config/sketchybar/plugins/executable_front_app.sh
```

Expected: both commands exit 0.

- [ ] **Step 5: Run the regression test and verify front-app assertions pass**

Run:

```bash
bash tests/chezmoi/test-sketchybar-live-workspace-icons.sh
```

Expected: FAIL later at `battery drawing=off` or a workspace label assertion, not at `front_app icon=:arc:`.

- [ ] **Step 6: Commit the front-app change**

Run:

```bash
git add dot_config/sketchybar/items/front_app.sh dot_config/sketchybar/plugins/executable_front_app.sh
git commit -m "feat: show front app icon in sketchybar"
```

Expected: commit succeeds with only the two front-app files staged.

---

### Task 3: Hide battery on AC power

**Files:**
- Modify: `dot_config/sketchybar/plugins/executable_battery.sh`
- Test: `tests/chezmoi/test-sketchybar-live-workspace-icons.sh`

**Interfaces:**
- Consumes: `pmset -g batt` output.
- Produces: `sketchybar --set "$NAME" drawing=off` when output indicates `AC Power` or contains no percentage; existing icon/percentage behavior while discharging.

- [ ] **Step 1: Confirm the regression test currently fails at the battery AC assertion**

Run:

```bash
bash tests/chezmoi/test-sketchybar-live-workspace-icons.sh
```

Expected: FAIL with a Python assertion containing `missing 'battery drawing=off'`.

- [ ] **Step 2: Replace `plugins/executable_battery.sh` with AC-hide logic**

Replace the full file `dot_config/sketchybar/plugins/executable_battery.sh` with:

```bash
#!/bin/bash

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

BATTERY_INFO="$(pmset -g batt)"
PERCENTAGE="$(printf '%s\n' "$BATTERY_INFO" | grep -Eo '[0-9]+%' | head -n 1 | cut -d% -f1)"
AC_POWER="$(printf '%s\n' "$BATTERY_INFO" | grep 'AC Power' || true)"

if [ -z "$PERCENTAGE" ] || [ -n "$AC_POWER" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

case ${PERCENTAGE} in
  9[0-9]|100) ICON="$ICON_BATTERY_100"; COLOR="$GREEN" ;;
  [6-8][0-9]) ICON="$ICON_BATTERY_75";  COLOR="$GREEN" ;;
  [3-5][0-9]) ICON="$ICON_BATTERY_50";  COLOR="$YELLOW" ;;
  [1-2][0-9]) ICON="$ICON_BATTERY_25";  COLOR="$ORANGE" ;;
  *)          ICON="$ICON_BATTERY_0";    COLOR="$RED" ;;
esac

sketchybar --set "$NAME" \
  drawing=on \
  icon="$ICON" \
  icon.color="$COLOR" \
  label="${PERCENTAGE}%"
```

- [ ] **Step 3: Syntax-check the battery plugin**

Run:

```bash
bash -n dot_config/sketchybar/plugins/executable_battery.sh
```

Expected: command exits 0.

- [ ] **Step 4: Run the regression test and verify battery assertions pass**

Run:

```bash
bash tests/chezmoi/test-sketchybar-live-workspace-icons.sh
```

Expected: FAIL later at a workspace app-icon assertion, not at `battery drawing=off` or `label=42%`.

- [ ] **Step 5: Commit the battery change**

Run:

```bash
git add dot_config/sketchybar/plugins/executable_battery.sh
git commit -m "feat: hide sketchybar battery on AC power"
```

Expected: commit succeeds with only the battery plugin staged.

---

### Task 4: Render live AeroSpace app icons in workspace items

**Files:**
- Modify: `dot_config/sketchybar/items/spaces.sh`
- Modify: `dot_config/sketchybar/plugins/executable_aerospace.sh`
- Test: `tests/chezmoi/test-sketchybar-live-workspace-icons.sh`

**Interfaces:**
- Consumes: `aerospace list-workspaces --focused`, `aerospace list-windows --workspace "$workspace" --json`, and `plugins/icon_map.sh "$app_name"`.
- Produces: each `space.<workspace>` item uses `icon=<workspace number>` and `label=<mapped app icon>` when the workspace has a representative app; empty workspaces set `label.drawing=off`.

- [ ] **Step 1: Confirm the regression test currently fails at workspace label assertions**

Run:

```bash
bash tests/chezmoi/test-sketchybar-live-workspace-icons.sh
```

Expected: FAIL with a Python assertion containing either `missing 'label=:arc:'`, `missing 'label=:ghostty:'`, or `missing 'label.drawing=off'` for a workspace item.

- [ ] **Step 2: Replace `items/spaces.sh` with number-plus-live-label setup**

Replace the full file `dot_config/sketchybar/items/spaces.sh` with:

```bash
#!/bin/bash

if ! command -v aerospace >/dev/null 2>&1; then
  exit 0
fi

WORKSPACES=$(aerospace list-workspaces --all)
FOCUSED=$(aerospace list-workspaces --focused)
APP_FONT="sketchybar-app-font"

while IFS= read -r workspace; do
  [ -n "$workspace" ] || continue

  num="${workspace%%-*}"

  if [ "$workspace" = "$FOCUSED" ]; then
    BG_DRAWING=on
    IC_COLOR=$WHITE
  else
    BG_DRAWING=off
    IC_COLOR=$GREY
  fi

  sketchybar --add item space."$workspace" left \
    --set space."$workspace" \
      icon="$num" \
      icon.font="$FONT:Bold:13.0" \
      icon.color="$IC_COLOR" \
      icon.padding_left=8 \
      icon.padding_right=4 \
      background.color="$BLUE" \
      background.corner_radius=5 \
      background.height=22 \
      background.drawing="$BG_DRAWING" \
      label.drawing=off \
      label.font="$APP_FONT:Regular:14.0" \
      label.color="$IC_COLOR" \
      label.padding_left=0 \
      label.padding_right=8 \
      update_freq=60 \
      script="$PLUGIN_DIR/aerospace.sh $workspace" \
      click_script="aerospace workspace $workspace" \
    --subscribe space."$workspace" aerospace_workspace_change front_app_switched system_woke
done <<< "$WORKSPACES"
```

- [ ] **Step 3: Replace `plugins/executable_aerospace.sh` with live representative-app logic**

Replace the full file `dot_config/sketchybar/plugins/executable_aerospace.sh` with:

```bash
#!/bin/bash

CONFIG_DIR="${CONFIG_DIR:-${HOME}/.config/sketchybar}"
# shellcheck source=dot_config/sketchybar/colors.sh
source "$CONFIG_DIR/colors.sh"

aerospace_bin="$(command -v aerospace || true)"
if [ -z "$aerospace_bin" ] && [ -x /opt/homebrew/bin/aerospace ]; then
  aerospace_bin=/opt/homebrew/bin/aerospace
fi

workspace="${1:-}"
if [ -z "$workspace" ]; then
  exit 0
fi

focused_workspace="${FOCUSED_WORKSPACE:-}"
if [ -z "$focused_workspace" ] && [ -n "$aerospace_bin" ]; then
  focused_workspace="$($aerospace_bin list-workspaces --focused 2>/dev/null || true)"
fi

item_name="${NAME:-space.$workspace}"

if [ "$workspace" = "$focused_workspace" ]; then
  BG_DRAWING=on
  IC_COLOR="$WHITE"
else
  BG_DRAWING=off
  IC_COLOR="$GREY"
fi

representative_app() {
  local target_workspace=$1

  if [ "$target_workspace" = "$focused_workspace" ] && [ -n "${INFO:-}" ]; then
    printf '%s\n' "$INFO"
    return 0
  fi

  if [ -z "$aerospace_bin" ]; then
    return 0
  fi

  "$aerospace_bin" list-windows --workspace "$target_workspace" --json 2>/dev/null \
    | /usr/bin/python3 -c '
import json
import sys
try:
    windows = json.load(sys.stdin)
except Exception:
    windows = []
for window in windows:
    app = window.get("app-name", "")
    if app:
        print(app)
        break
'
}

app_name="$(representative_app "$workspace" || true)"

if [ -n "$app_name" ]; then
  icon_map="$CONFIG_DIR/plugins/icon_map.sh"
  app_icon=":default:"
  if [ -x "$icon_map" ]; then
    app_icon="$($icon_map "$app_name" 2>/dev/null || printf ':default:')"
  fi
  if [ -z "$app_icon" ]; then
    app_icon=":default:"
  fi

  sketchybar --set "$item_name" \
    background.drawing="$BG_DRAWING" \
    icon.color="$IC_COLOR" \
    label="$app_icon" \
    label.color="$IC_COLOR" \
    label.drawing=on
else
  sketchybar --set "$item_name" \
    background.drawing="$BG_DRAWING" \
    icon.color="$IC_COLOR" \
    label="" \
    label.drawing=off
fi
```

- [ ] **Step 4: Syntax-check the workspace scripts**

Run:

```bash
bash -n dot_config/sketchybar/items/spaces.sh
bash -n dot_config/sketchybar/plugins/executable_aerospace.sh
```

Expected: both commands exit 0.

- [ ] **Step 5: Run the regression test and verify all assertions pass**

Run:

```bash
bash tests/chezmoi/test-sketchybar-live-workspace-icons.sh
```

Expected: PASS with no output.

- [ ] **Step 6: Commit the workspace icon change**

Run:

```bash
git add dot_config/sketchybar/items/spaces.sh dot_config/sketchybar/plugins/executable_aerospace.sh
git commit -m "feat: show live app icons for aerospace spaces"
```

Expected: commit succeeds with only the two workspace files staged.

---

### Task 5: Run final verification and record results

**Files:**
- No source changes expected unless verification reveals a defect.

**Interfaces:**
- Consumes: all changes from Tasks 1–4.
- Produces: verified branch ready for review or execution handoff.

- [ ] **Step 1: Run the targeted SketchyBar test**

Run:

```bash
bash tests/chezmoi/test-sketchybar-live-workspace-icons.sh
```

Expected: PASS with no output.

- [ ] **Step 2: Syntax-check all touched SketchyBar shell files**

Run:

```bash
bash -n dot_config/sketchybar/items/front_app.sh
bash -n dot_config/sketchybar/items/spaces.sh
bash -n dot_config/sketchybar/plugins/executable_front_app.sh
bash -n dot_config/sketchybar/plugins/executable_battery.sh
bash -n dot_config/sketchybar/plugins/executable_aerospace.sh
```

Expected: all commands exit 0.

- [ ] **Step 3: Run shellcheck on touched shell files and the new test**

Run:

```bash
shellcheck -e SC1091 \
  dot_config/sketchybar/items/front_app.sh \
  dot_config/sketchybar/items/spaces.sh \
  dot_config/sketchybar/plugins/executable_front_app.sh \
  dot_config/sketchybar/plugins/executable_battery.sh \
  dot_config/sketchybar/plugins/executable_aerospace.sh \
  tests/chezmoi/test-sketchybar-live-workspace-icons.sh
```

Expected: command exits 0.

- [ ] **Step 4: Run chezmoi dry-run verification**

Run:

```bash
chezmoi apply --source "$PWD" --dry-run --verbose --exclude=externals
```

Expected: command exits 0. The output may list would-change paths, but it must not contain template render errors.

- [ ] **Step 5: Run changed-file audit if available**

Run:

```bash
if command -v fallow >/dev/null 2>&1; then
  fallow audit --changed-since main
else
  echo "fallow not installed; skipped changed-file audit"
fi
```

Expected: either `fallow` exits 0 or the command prints `fallow not installed; skipped changed-file audit`.

- [ ] **Step 6: Inspect final diff**

Run:

```bash
git diff --stat main...HEAD
git diff --check main...HEAD
```

Expected: stat lists only the planned SketchyBar/test/docs files, and `git diff --check` exits 0.

- [ ] **Step 7: Report manual checks not fully automatable**

Report these checks to the user:

```text
Manual follow-up after applying config:
- Reload SketchyBar or run chezmoi apply.
- Move Arc or another mapped app between AeroSpace workspaces and confirm the app icon follows that workspace after an event or the 60-second safety refresh.
- Confirm empty workspaces display number-only state.
- Confirm battery is hidden while connected to AC power and appears when discharging.
```

Expected: user receives the manual checklist with the automated verification results.
