#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE="$ROOT/home/dot_config/sketchybar"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export CONFIG_DIR="$TMP/config" TMPDIR="$TMP" NAME=spotify
export SKETCHYBAR_LOG="$TMP/sketchybar.log" OSASCRIPT_LOG="$TMP/osascript.log"
mkdir -p "$CONFIG_DIR/plugins" "$CONFIG_DIR/items" "$TMP/bin"
export PATH="$TMP/bin:$PATH"

chezmoi execute-template --source "$ROOT" \
  --file "$SOURCE/colors.sh.tmpl" > "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/colors.sh"
cp "$SOURCE/plugins/executable_spotify.sh" "$CONFIG_DIR/plugins/spotify.sh"
chmod +x "$CONFIG_DIR/plugins/spotify.sh"

cat > "$TMP/bin/sketchybar" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >> "$SKETCHYBAR_LOG"
SH

cat > "$TMP/bin/pgrep" <<'SH'
#!/bin/sh
if [ "$SPOTIFY_SCENARIO" = restarted ] && [ -f "$TMPDIR/pid-read" ]; then
  printf '200\n'
else
  touch "$TMPDIR/pid-read"
  printf '100\n'
fi
SH

cat > "$TMP/bin/osascript" <<'SH'
#!/bin/sh
script="$* $(cat)"
case "$script" in
  *'tell application "Spotify" to quit'*)
    printf 'quit\n' >> "$OSASCRIPT_LOG"
    exit 0 ;;
esac
printf 'read\n' >> "$OSASCRIPT_LOG"
# Reject unguarded or separate metadata reads, which caused the relaunch bug.
case "$script" in
  *'if application "Spotify" is running then'*'player state as string'*) ;;
  *) exit 1 ;;
esac
case "$SPOTIFY_SCENARIO" in
  closed) printf 'not_running\n' ;;
  failed) exit 1 ;;
  empty) printf 'playing\n\n\n' ;;
  long) printf 'playing\nBjörk\nabcdefghijklmnopqrstuvwxyz0123456789abcdef\n' ;;
  paused) printf 'paused\nEmma Ruth Rundle\nHaunted Houses\n' ;;
  *) printf 'playing\nEmma Ruth Rundle\nHaunted Houses\n' ;;
esac
SH
chmod +x "$TMP/bin/"*

assert_log() {
  if ! grep -Fq -- "$1" "$SKETCHYBAR_LOG"; then
    printf 'missing %s in:\n' "$1" >&2
    cat "$SKETCHYBAR_LOG" >&2
    exit 1
  fi
}

run_plugin() {
  : > "$SKETCHYBAR_LOG"
  : > "$OSASCRIPT_LOG"
  rm -f "$TMP/pid-read"
  SPOTIFY_SCENARIO="$1" "$CONFIG_DIR/plugins/spotify.sh"
}

run_plugin playing
assert_log 'spotify drawing=on'
assert_log 'label=Emma Ruth Rundle — Haunted Houses'
test "$(cat "$OSASCRIPT_LOG")" = read

run_plugin paused
assert_log 'spotify drawing=on'
assert_log 'label=Emma Ruth Rundle — Haunted Houses'

for scenario in closed failed; do
  run_plugin "$scenario"
  assert_log 'spotify drawing=off label='
  test "$(cat "$OSASCRIPT_LOG")" = read
done

run_plugin empty
assert_log 'label=Spotify'
run_plugin long
assert_log 'label=Björk — abcdefghijklmnopqrstuvwxyz01234…'

run_plugin restarted
assert_log 'spotify drawing=off'
test "$(cat "$OSASCRIPT_LOG")" = "$(printf 'read\nquit')"

# A refresh already in progress must prevent another metadata read.
mkdir "$TMP/sketchybar-spotify-${UID:-$(id -u)}.lock"
run_plugin playing
test ! -s "$OSASCRIPT_LOG"
rmdir "$TMP/sketchybar-spotify-${UID:-$(id -u)}.lock"

# Exercise the real bar entrypoint, stubbing only unrelated items.
for item in "$SOURCE/items/"*.sh; do
  : > "$CONFIG_DIR/items/$(basename "$item")"
done
cp "$SOURCE/items/spotify.sh" "$CONFIG_DIR/items/spotify.sh"
: > "$CONFIG_DIR/icons.sh"
: > "$SKETCHYBAR_LOG"
bash "$SOURCE/executable_sketchybarrc"
assert_log '--add event spotify_change com.spotify.client.PlaybackStateChanged'
assert_log "script=$CONFIG_DIR/plugins/spotify.sh"
assert_log '--subscribe spotify spotify_change media_change'
assert_log 'tell application "Spotify" to activate'
