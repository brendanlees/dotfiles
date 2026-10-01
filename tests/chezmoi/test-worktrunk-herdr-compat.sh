#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
config="$repo_root/home/dot_config/worktrunk/config.toml"

python3 - "$config" <<'PY'
import json
import os
import shlex
import subprocess
import sys
import tempfile
import tomllib
from pathlib import Path

config = tomllib.loads(Path(sys.argv[1]).read_text())
assert "-m gpt-6-luna " in config["commit"]["generation"]["command"]
commands = {
    hook: next(iter(config[hook].values()))
    for hook in ("post-switch", "post-start")
}
branch = "feature-multiplexer"
worktree = "/tmp/worktree with 'quotes'"
commands = {
    hook: command.replace("{{ branch | sanitize }}", shlex.quote(branch)).replace(
        "{{ worktree_path }}", shlex.quote(worktree)
    )
    for hook, command in commands.items()
}

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    log = root / "calls.jsonl"
    for name in ("herdr", "tmux"):
        stub = root / name
        stub.write_text(f"#!{sys.executable}\n" + '''
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
with open(os.environ["CALL_LOG"], "a") as log:
    log.write(json.dumps([Path(sys.argv[0]).name, *args]) + "\\n")
if args[:2] == ["tab", "get"] or args[:1] == ["display-message"]:
    if os.environ.get("FAIL_QUERY"):
        sys.exit(1)
    count = int(os.environ["PANE_COUNT"])
    print(json.dumps({"result": {"tab": {"pane_count": count}}})
          if args[0] == "tab" else count)
''')
        stub.chmod(0o755)

    def run(hook, context, count=1, fail=False):
        env = os.environ.copy()
        for key in ("HERDR_ENV", "HERDR_TAB_ID", "HERDR_PANE_ID", "TMUX", "TMUX_PANE"):
            env.pop(key, None)
        env.update(context, PATH=f"{root}:{env['PATH']}", CALL_LOG=str(log),
                   PANE_COUNT=str(count), FAIL_QUERY="1" if fail else "")
        log.write_text("")
        result = subprocess.run(["sh", "-c", commands[hook]], env=env,
                                capture_output=True, text=True)
        assert (result.returncode != 0) == fail, result.stderr
        return [json.loads(line) for line in log.read_text().splitlines()]

    tmux = {"TMUX": "/tmp/tmux,1,0", "TMUX_PANE": "%7"}
    herdr = {"HERDR_ENV": "1", "HERDR_TAB_ID": "w1:t2", "HERDR_PANE_ID": "w1:p3"}
    for context in ({}, {"TMUX_PANE": "%7"}, {"TMUX": "/tmp/tmux,1,0"}):
        for hook in commands:
            assert run(hook, context) == []

    for context in (tmux, {**tmux, "HERDR_ENV": "0"}, herdr, {**tmux, **herdr}):
        is_herdr = context.get("HERDR_ENV") == "1"
        rename = (["herdr", "tab", "rename", "w1:t2", branch] if is_herdr else
                  ["tmux", "rename-window", "-t", "%7", branch])
        query = (["herdr", "tab", "get", "w1:t2"] if is_herdr else
                 ["tmux", "display-message", "-p", "-t", "%7", "#{window_panes}"])
        split = (["herdr", "pane", "split", "--pane", "w1:p3", "--direction", "right",
                  "--cwd", worktree, "--no-focus"] if is_herdr else
                 ["tmux", "split-window", "-h", "-d", "-t", "%7", "-c", worktree])
        assert run("post-switch", context) == [rename]
        for count in (1, 2, 3):
            assert run("post-start", context, count) == [query] + ([split] if count == 1 else [])
        assert run("post-start", context, fail=True) == [query]
PY

echo "Worktrunk multiplexer routing, pane setup, and commit model ok"
