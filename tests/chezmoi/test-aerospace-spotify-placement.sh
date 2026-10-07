#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG="$ROOT/home/dot_config/aerospace/aerospace.toml"
HELPER="$ROOT/home/dot_config/aerospace/executable_move-spotify-to-music.sh"

python3 - "$CONFIG" <<'PY'
import pathlib
import sys
import tomllib

parsed = tomllib.loads(pathlib.Path(sys.argv[1]).read_text())
rule = next(rule for rule in parsed['on-window-detected']
            if rule['if'] == 'test %{app-bundle-id} = com.spotify.client')
assert rule['run'] == [
    'move-node-to-workspace 9-music',
    'exec-and-forget /bin/bash -lc "$HOME/.config/aerospace/move-spotify-to-music.sh --delay 1"',
], 'Spotify should have immediate native routing and delayed placement'
PY

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT
mkdir -p "$TEMP_DIR/bin"
cat >"$TEMP_DIR/bin/aerospace" <<'SH'
#!/bin/sh
case "$1" in
  list-windows)
    printf '%s\n' '42|com.spotify.client' '99|dev.zed.Zed' '100|com.spotify.client'
    ;;
  move-node-to-workspace)
    printf '%s\n' "$*" >>"$MOVES_FILE"
    ;;
  *) exit 1 ;;
esac
SH
chmod +x "$TEMP_DIR/bin/aerospace"
PATH="$TEMP_DIR/bin:$PATH" MOVES_FILE="$TEMP_DIR/moves" \
  "$HELPER" --delay 0
printf '%s\n' \
  'move-node-to-workspace --window-id 42 9-music' \
  'move-node-to-workspace --window-id 100 9-music' >"$TEMP_DIR/expected"
cmp "$TEMP_DIR/expected" "$TEMP_DIR/moves"
