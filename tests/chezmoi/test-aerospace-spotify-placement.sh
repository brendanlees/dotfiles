#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_ROOT="$ROOT/home"
CONFIG="$SOURCE_ROOT/dot_config/aerospace/aerospace.toml"
HELPER="$SOURCE_ROOT/dot_config/aerospace/executable_move-spotify-to-music.sh"
PLACEMENT_HELPER="$SOURCE_ROOT/dot_config/aerospace/executable_move-window-if-first.sh"

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
assert "move-window-if-first.sh" in body, "Spotify should use first-window placement"
assert "'move-node-to-workspace 9-music'" not in body, "Spotify must not force every window to the music workspace"
assert "move-spotify-to-music.sh --delay 1" in body, "Spotify rule should retain delayed placement"
PY

for helper in "$HELPER" "$PLACEMENT_HELPER"; do
  if [ ! -x "$helper" ]; then
    printf 'expected executable helper at %s\n' "$helper" >&2
    exit 1
  fi
done

grep -F "%{window-id}|%{app-bundle-id}" "$HELPER" >/dev/null
grep -F "com.spotify.client" "$HELPER" >/dev/null
grep -F "move-node-to-workspace --window-id \"\$wid\" 9-music" "$HELPER" >/dev/null
