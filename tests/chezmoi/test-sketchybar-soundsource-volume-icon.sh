#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="${TMPDIR:-/tmp}/sketchybar-soundsource-volume-icon-test-$$"
CONFIG="$TMP/config"
BIN="$TMP/bin"
BIN_NO_BD="$TMP/bin-no-bd"
LOG="$TMP/sketchybar.log"
mkdir -p "$CONFIG/plugins" "$BIN" "$BIN_NO_BD"
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
cp "$BIN/sketchybar" "$BIN_NO_BD/sketchybar"
chmod +x "$BIN_NO_BD/sketchybar"

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
PATH="$BIN_NO_BD:/usr/bin:/bin:/usr/sbin:/sbin" CONFIG_DIR="$CONFIG" SKETCHYBAR_STUB_LOG="$LOG" NAME=soundsource "$CONFIG/plugins/soundsource.sh"
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
