#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
template="$repo_root/dot_config/herdr/config.toml.tmpl"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

if [[ ! -f "$template" ]]; then
  echo "missing HerdR config template: $template" >&2
  exit 1
fi

rendered="$tmpdir/config.toml"
data_file="$tmpdir/data.json"
chezmoi data --source "$repo_root" --format json >"$data_file"
chezmoi execute-template \
  --source "$repo_root" \
  --override-data '{"theme":"guts"}' \
  <"$template" >"$rendered"

python3 - "$data_file" "$rendered" <<'PY'
import json
import sys
import tomllib
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text())
doc = tomllib.loads(Path(sys.argv[2]).read_text())
palette = data["themes"]["guts"]["palette"]

assert doc["terminal"] == {
    "default_shell": "zsh",
    "shell_mode": "auto",
    "new_cwd": "follow",
}

keys = doc["keys"]
assert keys["prefix"] == "ctrl+b"
assert keys["detach"] == "prefix+d"
assert keys["reload_config"] == "prefix+r"
assert keys["new_tab"] == "prefix+c"
assert keys["rename_tab"] == "prefix+comma"
assert keys["previous_tab"] == ["prefix+p", "ctrl+shift+h"]
assert keys["next_tab"] == ["prefix+n", "ctrl+shift+l"]
assert keys["switch_tab"] == "prefix+1..9"
assert keys["close_tab"] == "prefix+ampersand"
assert keys["copy_mode"] == "prefix+["
assert keys["split_vertical"] == "prefix+percent"
assert keys["split_horizontal"] == "prefix+double_quote"
assert keys["close_pane"] == "prefix+x"
assert keys["zoom"] == ["prefix+z", "ctrl+f"]
assert keys["resize_mode"] == ""
for field in (
    "focus_pane_left",
    "focus_pane_down",
    "focus_pane_up",
    "focus_pane_right",
):
    assert keys[field] == ""

commands = keys["command"]
assert len(commands) == 4
for command, direction, key in zip(
    commands,
    ("left", "down", "up", "right"),
    ("prefix+h", "prefix+j", "prefix+k", "prefix+l"),
    strict=True,
):
    assert command["key"] == key
    assert command["type"] == "shell"
    assert f"--direction {direction}" in command["command"]
    assert "--amount 0.05" in command["command"]
    assert '"$HERDR_BIN_PATH"' in command["command"]
    assert '"$HERDR_ACTIVE_PANE_ID"' in command["command"]

assert doc["ui"]["mouse_capture"] is True
assert doc["ui"]["prompt_new_tab_name"] is False
assert doc["ui"]["pane_borders"] is True
assert doc["ui"]["pane_gaps"] is False
assert doc["ui"]["accent"] == palette["accent"]
assert doc["ui"]["sound"]["enabled"] is False
assert doc["advanced"]["scrollback_limit_bytes"] == 100_000_000

assert doc["theme"]["name"] == "terminal"
assert doc["theme"]["auto_switch"] is False
assert doc["theme"]["custom"] == {
    "panel_bg": palette["bg"],
    "surface0": palette["surface"],
    "surface1": palette["surface_alt"],
    "surface_dim": palette["tool_neutral_bg"],
    "overlay0": palette["border"],
    "overlay1": palette["comment"],
    "text": palette["fg"],
    "subtext0": palette["muted"],
    "accent": palette["accent"],
    "mauve": palette["secondary"],
    "green": palette["success"],
    "yellow": palette["warn"],
    "red": palette["error"],
    "blue": palette["primary"],
    "teal": palette["info"],
    "peach": palette["orange"],
}
PY

windows_ignore="$tmpdir/windows-ignore"
darwin_ignore="$tmpdir/darwin-ignore"
chezmoi execute-template \
  --source "$repo_root" \
  --override-data '{"chezmoi":{"os":"windows"}}' \
  <"$repo_root/.chezmoiignore" >"$windows_ignore"
chezmoi execute-template \
  --source "$repo_root" \
  --override-data '{"chezmoi":{"os":"darwin"}}' \
  <"$repo_root/.chezmoiignore" >"$darwin_ignore"
grep -Fxq '.config/herdr' "$windows_ignore"
if grep -Fxq '.config/herdr' "$darwin_ignore"; then
  echo "HerdR config must remain managed on macOS" >&2
  exit 1
fi

echo "HerdR config template ok"
