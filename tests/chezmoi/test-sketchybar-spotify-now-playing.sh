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
export SPOTIFY_COLOR=0xff00ff80
SH

cp "$ROOT/dot_config/sketchybar/plugins/executable_spotify.sh" "$CONFIG/plugins/spotify.sh" 2>/dev/null || : > "$CONFIG/plugins/spotify.sh"
chmod +x "$CONFIG/plugins/spotify.sh"

python3 - "$CONFIG/plugins/spotify.sh" <<'PY'
import pathlib
import re
import sys

script = pathlib.Path(sys.argv[1]).read_text()
metadata_tells = re.findall(r'osascript .*tell application "Spotify" to (?:player state|artist of current track|name of current track|artwork url of current track)', script)
assert not metadata_tells, "Spotify metadata reads must be guarded in one osascript invocation to avoid relaunching Spotify during Cmd-Q"
PY

cat > "$BIN/sketchybar" <<'SH'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$SKETCHYBAR_STUB_LOG"
SH
chmod +x "$BIN/sketchybar"

cat > "$BIN/pgrep" <<'SH'
#!/usr/bin/env sh
if [ -n "${PGREP_STUB_VALUES:-}" ] && [ -s "$PGREP_STUB_VALUES" ]; then
  sed -n '1p' "$PGREP_STUB_VALUES"
  sed '1d' "$PGREP_STUB_VALUES" > "$PGREP_STUB_VALUES.tmp"
  mv "$PGREP_STUB_VALUES.tmp" "$PGREP_STUB_VALUES"
else
  printf '12345
'
fi
SH
chmod +x "$BIN/pgrep"

cat > "$BIN/osascript" <<'SH'
#!/usr/bin/env sh
stdin="$(cat)"
script="$* $stdin"
scenario="${SPOTIFY_SCENARIO:-playing}"
if [ -n "${OSASCRIPT_STUB_LOG:-}" ]; then
  case "$script" in
    *'tell application "Spotify" to quit'*) printf 'quit\n' >> "$OSASCRIPT_STUB_LOG" ;;
    *) printf 'call\n' >> "$OSASCRIPT_STUB_LOG" ;;
  esac
fi
if [ -n "${SPOTIFY_OSASCRIPT_SLEEP:-}" ]; then
  sleep "$SPOTIFY_OSASCRIPT_SLEEP"
fi

state_for_scenario() {
  case "$scenario" in
    paused) printf 'paused\n' ;;
    stopped) printf 'stopped\n' ;;
    *) printf 'playing\n' ;;
  esac
}

artist_for_scenario() {
  case "$scenario" in
    long) printf 'Very Long Artist Name\n' ;;
    empty) printf '\n' ;;
    *) printf 'Emma Ruth Rundle\n' ;;
  esac
}

title_for_scenario() {
  case "$scenario" in
    long) printf 'Extremely Long Track Title\n' ;;
    empty) printf '\n' ;;
    *) printf 'Haunted Houses\n' ;;
  esac
}

case "$script" in
  *'tell application "Spotify" to quit'*)
    ;;
  *'application "Spotify" is running'*'player state as string'*)
    if [ "$scenario" = "not_running" ]; then
      printf 'not_running\n'
    else
      state_for_scenario
      artist_for_scenario
      title_for_scenario
      printf '\n'
    fi
    ;;
  *'application "Spotify" is running'*)
    if [ "$scenario" = "not_running" ]; then
      printf 'not_running\n'
    else
      printf 'true\n'
    fi
    ;;
  *'player state as string'*)
    state_for_scenario
    ;;
  *'artist of current track'*)
    artist_for_scenario
    ;;
  *'name of current track'*)
    title_for_scenario
    ;;
  *'artwork url of current track'*)
    printf '\n'
    ;;
  *)
    printf 'unexpected osascript: %s\n' "$script" >&2
    exit 1
    ;;
esac
SH
chmod +x "$BIN/osascript"

run_plugin() {
  local scenario="${SPOTIFY_SCENARIO:-playing}"
  env     PATH="$BIN:$PATH"     CONFIG_DIR="$CONFIG"     SKETCHYBAR_STUB_LOG="$LOG"     OSASCRIPT_STUB_LOG="${OSASCRIPT_STUB_LOG:-}"     SPOTIFY_OSASCRIPT_SLEEP="${SPOTIFY_OSASCRIPT_SLEEP:-}"     SPOTIFY_SCENARIO="$scenario"     NAME=spotify     "$CONFIG/plugins/spotify.sh"
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
assert_log_contains 'icon=▶'
assert_log_contains 'icon.color=0xff00ff80'
assert_log_contains 'background.border_color=0xff00ff80'
assert_log_contains 'label=Emma Ruth Rundle — Haunted Houses'

: > "$LOG"
SPOTIFY_SCENARIO=paused run_plugin
assert_log_contains 'spotify drawing=on'
assert_log_contains 'icon=⏸'
assert_log_contains 'label=Emma Ruth Rundle — Haunted Houses'

: > "$LOG"
SPOTIFY_SCENARIO=not_running run_plugin
assert_log_contains 'spotify drawing=off'

: > "$LOG"
SPOTIFY_SCENARIO=empty run_plugin
assert_log_contains 'spotify drawing=on'
assert_log_contains 'label=Spotify'

: > "$LOG"
SPOTIFY_SCENARIO=long SPOTIFY_LABEL_MAX_CHARS=20 run_plugin
assert_log_contains 'spotify drawing=on'
assert_log_contains 'label=Very Long Artist Na…'

OSASCRIPT_LOG="$TMP/osascript.log"
: > "$LOG"
: > "$OSASCRIPT_LOG"
OSASCRIPT_STUB_LOG="$OSASCRIPT_LOG" SPOTIFY_OSASCRIPT_SLEEP=0.2 SPOTIFY_SCENARIO=playing run_plugin &
pid1=$!
OSASCRIPT_STUB_LOG="$OSASCRIPT_LOG" SPOTIFY_OSASCRIPT_SLEEP=0.2 SPOTIFY_SCENARIO=playing run_plugin &
pid2=$!
wait "$pid1" "$pid2"
osascript_calls="$(wc -l < "$OSASCRIPT_LOG" | tr -d ' ')"
if [ "$osascript_calls" -ne 1 ]; then
  printf 'expected 1 osascript call for concurrent plugin runs, got %s
' "$osascript_calls" >&2
  exit 1
fi

PGREP_VALUES="$TMP/pgrep-values"
OSASCRIPT_LOG="$TMP/osascript-pid-race.log"
printf '100
200
' > "$PGREP_VALUES"
: > "$LOG"
: > "$OSASCRIPT_LOG"
PGREP_STUB_VALUES="$PGREP_VALUES" OSASCRIPT_STUB_LOG="$OSASCRIPT_LOG" SPOTIFY_SCENARIO=playing run_plugin
assert_log_contains 'spotify drawing=off'
if ! grep -q '^quit$' "$OSASCRIPT_LOG"; then
  printf 'expected plugin to quit relaunched Spotify after PID changed during metadata read
' >&2
  exit 1
fi

: > "$LOG"
CONFIG_DIR="$CONFIG" ITEM_DIR="$CONFIG/items" PLUGIN_DIR="$CONFIG/plugins" FONT="JetBrainsMono Nerd Font Mono" ICON_COLOR=0xffffffff SPOTIFY_COLOR=0xff00ff80 WHITE=0xffffffff PILL_BG=0x88262626 SKETCHYBAR_STUB_LOG="$LOG" PATH="$BIN:$PATH" bash "$ROOT/dot_config/sketchybar/items/spotify.sh"
assert_log_contains '--add item spotify right'
assert_log_contains 'icon=:spotify:'
assert_log_contains 'icon.font=sketchybar-app-font:Regular:14.0'
assert_log_contains 'icon.color=0xff00ff80'
assert_log_contains 'background.border_color=0xff00ff80'
assert_log_contains 'drawing=off'
assert_log_contains 'update_freq=15'
assert_log_contains 'script='
assert_log_contains 'spotify.sh'
assert_log_contains 'tell application "Spotify" to activate'
