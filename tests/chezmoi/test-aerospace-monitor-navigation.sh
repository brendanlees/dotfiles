#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG="$ROOT/home/dot_config/aerospace/aerospace.toml"

python3 - "$CONFIG" <<'PY'
import pathlib
import re
import sys

config = pathlib.Path(sys.argv[1]).read_text()
expected = {
    "cmd-alt-shift-h": "focus-monitor left",
    "cmd-alt-shift-j": "focus-monitor down",
    "cmd-alt-shift-k": "focus-monitor up",
    "cmd-alt-shift-l": "focus-monitor right",
    "cmd-alt-shift-i": "move-workspace-to-monitor iPad",
}
for key, command in expected.items():
    pattern = rf"^{re.escape(key)}\s*=\s*'{re.escape(command)}'$"
    assert re.search(pattern, config, re.MULTILINE), f"{key} should run {command!r}"

assert "[workspace-to-monitor-force-assignment]" not in config, (
    "monitor navigation should move the current workspace at runtime, "
    "not force one workspace to the iPad"
)
PY
