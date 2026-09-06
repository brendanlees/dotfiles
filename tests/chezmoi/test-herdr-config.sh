#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

chezmoi data --source "$repo_root" --format json >"$tmpdir/data.json"
chezmoi execute-template --source "$repo_root" --override-data '{"theme":"guts"}' \
  --file "$repo_root/home/dot_config/herdr/config.toml.tmpl" >"$tmpdir/config.toml"

python3 - "$tmpdir/data.json" "$tmpdir/config.toml" <<'PY'
import json
import sys
import tomllib
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text())
config = tomllib.loads(Path(sys.argv[2]).read_text())
palette = data["themes"]["guts"]["palette"]

# Runtime commands must target the invoking server and pane, not a default one.
resize = [c for c in config["keys"]["command"] if "pane resize" in c["command"]]
assert resize
for command in resize:
    assert '"$HERDR_BIN_PATH"' in command["command"]
    assert '"$HERDR_ACTIVE_PANE_ID"' in command["command"]

# Check the palette bridge, not keybinding order or cosmetic defaults.
assert config["ui"]["accent"] == palette["accent"]
assert config["theme"]["custom"]["panel_bg"] == palette["bg"]
assert config["theme"]["custom"]["text"] == palette["fg"]
PY

for os in windows darwin; do
  chezmoi execute-template --source "$repo_root" \
    --override-data "{\"personal\":false,\"work\":false,\"homelab\":false,\"ephemeral\":true,\"headless\":true,\"chezmoi\":{\"os\":\"$os\"}}" \
    --file "$repo_root/home/.chezmoiignore" >"$tmpdir/$os.ignore"
done
grep -Fxq '.config/herdr' "$tmpdir/windows.ignore"
if grep -Fxq '.config/herdr' "$tmpdir/darwin.ignore"; then
  echo 'Herdr must remain managed on macOS' >&2
  exit 1
fi

echo 'Herdr runtime config contract ok'
