#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG="$ROOT/home/dot_config/aerospace/aerospace.toml"

python3 - "$CONFIG" <<'PY'
import pathlib
import re
import sys
import tomllib

config = pathlib.Path(sys.argv[1]).read_text()
parsed = tomllib.loads(config)
assert parsed['config-version'] == 2
assert parsed['persistent-workspaces'] == [
    '1-browser',
    '2-code',
    '3-email',
    '4-files',
    '5-docs',
    '6-misc1',
    '7-misc2',
    '8-notes',
    '9-music',
]
assert parsed['on-focused-monitor-changed'] == [
    'move-mouse monitor-lazy-center',
    'exec-and-forget /bin/bash -lc "$HOME/.config/aerospace/notify-sketchybar.sh"',
]
expected = {
    "cmd-alt-shift-h": "focus-monitor left",
    "cmd-alt-shift-j": "focus-monitor up",
    "cmd-alt-shift-k": "focus-monitor down",
    "cmd-alt-shift-l": "focus-monitor right",
    "cmd-alt-shift-i": "move-workspace-to-monitor iPad secondary",
    "cmd-alt-shift-comma": "move-workspace-to-monitor main",
}
for key, command in expected.items():
    pattern = rf"^{re.escape(key)}\s*=\s*'{re.escape(command)}'$"
    assert re.search(pattern, config, re.MULTILINE), f"{key} should run {command!r}"

assert "[workspace-to-monitor-force-assignment]" not in config, (
    "monitor navigation should move the current workspace at runtime, "
    "not force one workspace to the iPad"
)
PY
