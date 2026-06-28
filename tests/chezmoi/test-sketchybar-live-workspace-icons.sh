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
export MUTED=0xff808080
export GREEN=0xff00ff00
export YELLOW=0xffffff00
export ORANGE=0xffffa500
export RED=0xffff0000
export BLUE=0xff0000ff
export MAGENTA=0xffff00ff
export CYAN=0xff00ffff
export ACCENT=0xff00ff80
export LABEL_COLOR=$WHITE
export SPACES_COLOR=$BLUE
export FRONT_APP_COLOR=$MAGENTA
export CALENDAR_COLOR=$CYAN
export SPOTIFY_COLOR=$ACCENT
export PILL_BG=0x88262626
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
assert_log_contains 'background.border_color=0xffffff00'

: > "$LOG"
SENDER=front_app_switched INFO=Arc NAME=space.4-files FOCUSED_WORKSPACE=4-files run_plugin "$CONFIG/plugins/aerospace.sh" 4-files
assert_log_contains 'space.4-files icon.color=0xffffffff'
assert_log_contains 'label=:arc:'
assert_log_contains 'label.drawing=on'

: > "$LOG"
SENDER=aerospace_workspace_change NAME=space.2-code FOCUSED_WORKSPACE=4-files run_plugin "$CONFIG/plugins/aerospace.sh" 2-code
assert_log_contains 'space.2-code icon.color=0xff808080'
assert_log_contains 'label=:ghostty:'
assert_log_contains 'label.drawing=on'

: > "$LOG"
SENDER=aerospace_workspace_change NAME=space.6-misc1 FOCUSED_WORKSPACE=4-files run_plugin "$CONFIG/plugins/aerospace.sh" 6-misc1
assert_log_contains 'space.6-misc1 icon.color=0xff808080'
assert_log_contains 'label.drawing=off'
