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
