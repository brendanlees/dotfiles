#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
config="$repo_root/dot_config/worktrunk/config.toml"

python3 - "$config" <<'PY'
import os
import subprocess
import sys
import tomllib
from pathlib import Path

config = tomllib.loads(Path(sys.argv[1]).read_text())
commands = [
    config["post-switch"]["tmux-rename"],
    config["post-start"]["tmux-split"],
]
assert "tmux rename-window" in commands[0]
assert "tmux list-panes" in commands[1]
env = os.environ.copy()
env.pop("TMUX", None)
env.pop("TMUX_PANE", None)
for command in commands:
    result = subprocess.run(["sh", "-c", command], env=env)
    assert result.returncode == 0, (command, result.returncode)
PY

echo "Worktrunk tmux guards ok"
