#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="$ROOT/home/dot_config/aerospace/executable_move-spotify-to-music.sh"

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT
mkdir -p "$TEMP_DIR/bin"
cat >"$TEMP_DIR/bin/sleep" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >"$DELAY_FILE"
SH
cat >"$TEMP_DIR/bin/aerospace" <<'SH'
#!/bin/sh
set -eu
case "$1" in
  list-windows)
    # Discover the windows after the delay, not before it.
    test -f "$DELAY_FILE"
    test "$*" = 'list-windows --all --format %{window-id}|%{app-bundle-id}'
    printf '%s\n' '42|com.spotify.client' '99|dev.zed.Zed' '100|com.spotify.client'
    ;;
  move-node-to-workspace)
    printf '%s\n' "$*" >>"$MOVES_FILE"
    # A window closing during placement must not block the remaining windows.
    test "$3" != 42
    ;;
  *) exit 1 ;;
esac
SH
chmod +x "$TEMP_DIR/bin/sleep" "$TEMP_DIR/bin/aerospace"
PATH="$TEMP_DIR/bin:$PATH" MOVES_FILE="$TEMP_DIR/moves" DELAY_FILE="$TEMP_DIR/delay" \
  "$HELPER" --delay 1
[[ $(<"$TEMP_DIR/delay") == 1 ]]
printf '%s\n' \
  'move-node-to-workspace --window-id 42 9-music' \
  'move-node-to-workspace --window-id 100 9-music' >"$TEMP_DIR/expected"
cmp "$TEMP_DIR/expected" "$TEMP_DIR/moves"
echo 'AeroSpace delayed Spotify placement ok'
