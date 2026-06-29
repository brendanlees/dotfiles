#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG="$ROOT/dot_config/aerospace/aerospace.toml"
HELPER="$ROOT/dot_config/aerospace/executable_move-spotify-to-music.sh"

python3 - "$CONFIG" <<'PY'
import pathlib
import re
import sys

config = pathlib.Path(sys.argv[1]).read_text()
match = re.search(
    r"# --- 9\. music ---\n"
    r"\[\[on-window-detected\]\]\n"
    r"if\.app-id = 'com\.spotify\.client'\n"
    r"run = \[\n(?P<body>.*?)\n\]",
    config,
    re.S,
)
assert match, "Spotify on-window-detected rule should use an array with immediate and delayed placement commands"
body = match.group("body")
assert "'move-node-to-workspace 9-music'" in body, "Spotify rule should still move the detected window immediately"
assert "move-spotify-to-music.sh --delay 1" in body, "Spotify rule should schedule a delayed window-id sweep"
PY

if [ ! -x "$HELPER" ]; then
  printf 'expected executable helper at %s\n' "$HELPER" >&2
  exit 1
fi

grep -F "%{window-id}|%{app-bundle-id}" "$HELPER" >/dev/null
grep -F "com.spotify.client" "$HELPER" >/dev/null
grep -F 'move-node-to-workspace --window-id "$wid" 9-music' "$HELPER" >/dev/null
