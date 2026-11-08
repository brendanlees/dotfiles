#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

python3 - "$tmpdir" "$repo_root/home/dot_config/herdr/executable_pi-navigation.sh" <<'PY'
import json
import os
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
helper = Path(sys.argv[2])
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
    for process in ["pi", "nvim", "zsh", "python"]:
        env = dict(os.environ, HERDR_BIN_PATH=str(mock), HERDR_ACTIVE_PANE_ID="active:p2",
                   HERDR_PANE_ID="stale:p1", TEST_PROCESS=process, TEST_LOG=str(log))
        subprocess.run(["bash", str(helper), direction], env=env, check=True)
        expected = (["pane", "send-keys", "active:p2", key] if process == "pi" else
                    ["plugin", "action", "invoke", f"vim-herdr-navigation.{direction}"])
        assert json.loads(log.read_text()) == expected
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

echo 'Herdr active-pane navigation and OS routing ok'
