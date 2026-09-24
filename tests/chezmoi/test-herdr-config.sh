#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

chezmoi data --source "$repo_root" --format json >"$tmpdir/data.json"
chezmoi execute-template --source "$repo_root" --override-data '{"theme":"guts"}' \
  --file "$repo_root/home/dot_config/herdr/config.toml.tmpl" >"$tmpdir/config.toml"

python3 - "$tmpdir/data.json" "$tmpdir/config.toml" "$repo_root/home/dot_config/herdr/executable_pi-navigation.sh" <<'PY'
import json
import os
import subprocess
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

# Each chord has one owner, and only foreground Pi receives it directly.
assert config["keys"]["navigate_workspace_up"] == ""
assert config["keys"]["navigate_workspace_down"] == ""
commands = {c["key"]: c for c in config["keys"]["command"]}
root = Path(sys.argv[2]).parent
helper = Path(sys.argv[3])
mock = root / "herdr"
log = root / "calls.json"
mock.write_text('''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
if args[:2] == ["pane", "process-info"]:
    assert args == ["pane", "process-info", "--pane", "active:p2"]
    print(json.dumps({"result": {"process_info": {"foreground_processes": [{"name": os.environ["TEST_PROCESS"]}]}}}))
else:
    Path(os.environ["TEST_LOG"]).write_text(json.dumps(args))
''')
mock.chmod(0o755)
for direction, key in [("down", "ctrl+j"), ("up", "ctrl+k")]:
    command = commands[key]
    assert command["type"] == "shell"
    assert command["command"] == f'exec "$HOME/.config/herdr/pi-navigation.sh" {direction}'
    for process in ["pi", "nvim", "zsh", "python"]:
        env = dict(os.environ, HERDR_BIN_PATH=str(mock), HERDR_ACTIVE_PANE_ID="active:p2",
                   HERDR_PANE_ID="stale:p1", TEST_PROCESS=process, TEST_LOG=str(log))
        subprocess.run(["bash", str(helper), direction], env=env, check=True)
        expected = (["pane", "send-keys", "active:p2", key] if process == "pi" else
                    ["plugin", "action", "invoke", f"vim-herdr-navigation.{direction}"])
        assert json.loads(log.read_text()) == expected
# Horizontal chords remain owned by the existing Vim navigation plugin.
for key, direction in [("ctrl+h", "left"), ("ctrl+l", "right")]:
    assert commands[key]["command"] == f"vim-herdr-navigation.{direction}"

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
