#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LAUNCHER="$ROOT/dot_local/bin/executable_headroom-herdr"
TMPDIR="${TMPDIR:-/tmp}/headroom-herdr-launcher-test-$$"
BIN="$TMPDIR/bin"
LOG="$TMPDIR/herdr.log"
CONFIG="$TMPDIR/config"
PROXY_HELP_LOG="$TMPDIR/proxy-help.log"
NO_HERDR_BIN="$TMPDIR/no-herdr-bin"
mkdir -p "$BIN" "$NO_HERDR_BIN" "$CONFIG/zsh/aliases.d"
trap 'rm -rf "$TMPDIR"' EXIT

cat > "$CONFIG/zsh/aliases.d/headroom.zsh" <<'ZSH'
hr-proxy-claude() {
  printf '%s\n' "$*" >> "$PROXY_HELP_LOG"
}
ZSH

cat > "$BIN/herdr" <<'PY'
#!/usr/bin/env python3
import json
import os
import shlex
import sys
from pathlib import Path

args = sys.argv[1:]
log_path = Path(os.environ["HERDR_STUB_LOG"])
with log_path.open("a") as fh:
    fh.write(shlex.join(args) + "\n")

scenario = os.environ.get("HERDR_SCENARIO", "new")
result = {"type": "ok"}

if args[:2] == ["workspace", "list"]:
    workspaces = []
    create_has_run = any(
        line.startswith("workspace create ")
        for line in log_path.read_text().splitlines()
    )
    if scenario in {"healthy-existing", "stale-existing"} or (
        scenario in {"incomplete-create", "ambiguous-incomplete-create"} and not create_has_run
    ):
        workspaces = [{
            "workspace_id": "wExistingQ",
            "label": "headroom",
            "focused": False,
            "active_tab_id": "wExistingQ:tR",
            "number": 8,
            "pane_count": 4,
            "tab_count": 1,
            "agent_status": "unknown",
        }]
    elif scenario == "incomplete-create" and create_has_run:
        workspaces = [{"workspace_id": "wCreatedZ", "label": "headroom"}]
    elif scenario == "ambiguous-incomplete-create" and create_has_run:
        workspaces = [
            {"workspace_id": "wCreatedZ", "label": "headroom"},
            {"workspace_id": "wConcurrent", "label": "headroom"},
        ]
    elif scenario == "invalid-existing-id":
        workspace = {"label": "headroom"}
        invalid_id_kind = os.environ["HERDR_INVALID_ID_KIND"]
        if invalid_id_kind == "empty":
            workspace["workspace_id"] = ""
        elif invalid_id_kind == "non-string":
            workspace["workspace_id"] = 42
        workspaces = [workspace]
    result = {"type": "workspace_list", "workspaces": workspaces}
elif args[:2] == ["workspace", "create"]:
    if scenario in {"incomplete-create", "ambiguous-incomplete-create"}:
        result = {"type": "workspace_created", "workspace": {"label": "headroom"}}
    else:
        result = {
            "type": "workspace_created",
            "workspace": {"workspace_id": "wCreatedZ", "label": "headroom"},
        }
elif args[:2] == ["pane", "list"]:
    result = {
        "type": "pane_list",
        "panes": [{"pane_id": "wCreatedZ:pProxyA", "workspace_id": "wCreatedZ"}],
    }
elif args[:2] == ["pane", "split"]:
    split_lines = [
        line for line in log_path.read_text().splitlines()
        if line.startswith("pane split ")
    ]
    split_index = len(split_lines) - 1
    if os.environ.get("HERDR_FAIL_SPLIT") == str(split_index + 1):
        print("injected split failure", file=sys.stderr)
        raise SystemExit(1)
    pane_ids = ["wCreatedZ:pStats7", "wCreatedZ:pCodex2", "wCreatedZ:pShimX"]
    result = {"type": "pane_split", "pane": {"pane_id": pane_ids[split_index]}}

print(json.dumps({"id": "stub", "result": result}))
PY
chmod +x "$BIN/herdr"

cat > "$BIN/curl" <<'SH'
#!/usr/bin/env sh
[ "${HERDR_HEALTHY:-0}" = 1 ]
SH
chmod +x "$BIN/curl"

run_launcher() {
  PATH="$BIN:$PATH" \
  HERDR_STUB_LOG="$LOG" \
  PROXY_HELP_LOG="$PROXY_HELP_LOG" \
  XDG_CONFIG_HOME="$CONFIG" \
  HERDR_ENV=1 \
  HERDR_WORKSPACE_ID=wCaller \
  HERDR_TAB_ID=wCaller:tCaller \
  HERDR_PANE_ID=wCaller:pCaller \
  HEADROOM_PORT=18883 \
  HEADROOM_CODEX_PROXY_PORT=18884 \
  HEADROOM_CODEX_SHIM_PORT=18885 \
  HEADROOM_PROXY_PANE_COLOR='#658594' \
  HEADROOM_STATS_PANE_COLOR='#8a9a7b' \
  HEADROOM_SHIM_PANE_COLOR='#a292a3' \
  zsh "$LAUNCHER" "$@"
}

for help_arg in -h --help help; do
  : > "$LOG"
  : > "$PROXY_HELP_LOG"
  PATH="$BIN:$PATH" \
    HERDR_STUB_LOG="$LOG" \
    PROXY_HELP_LOG="$PROXY_HELP_LOG" \
    XDG_CONFIG_HOME="$CONFIG" \
    env -u HERDR_ENV -u HERDR_WORKSPACE_ID -u HERDR_TAB_ID -u HERDR_PANE_ID \
      zsh "$LAUNCHER" "$help_arg"
  [ ! -s "$LOG" ]
  grep -Fxq -- "$help_arg" "$PROXY_HELP_LOG"
done

: > "$LOG"
HERDR_SCENARIO=new HERDR_HEALTHY=0 run_launcher --label "two words"
python3 - "$LOG" "$PWD" <<'PY'
import shlex
import sys
from pathlib import Path

lines = Path(sys.argv[1]).read_text().splitlines()
cwd = sys.argv[2]
assert lines[0].startswith("workspace list"), lines
create = shlex.split(next(line for line in lines if line.startswith("workspace create ")))
assert create == ["workspace", "create", "--cwd", cwd, "--label", "headroom", "--focus"], lines
assert "pane list --workspace wCreatedZ" in lines, lines
assert "pane rename wCreatedZ:pProxyA proxy" in lines, lines
assert "pane split wCreatedZ:pProxyA --direction right --no-focus" in lines, lines
assert "pane rename wCreatedZ:pStats7 stats" in lines, lines
assert "pane split wCreatedZ:pStats7 --direction down --no-focus" in lines, lines
assert "pane rename wCreatedZ:pCodex2 codex-proxy" in lines, lines
assert "pane split wCreatedZ:pCodex2 --direction down --no-focus" in lines, lines
assert "pane rename wCreatedZ:pShimX codex-shim" in lines, lines
run_lines = [line for line in lines if line.startswith("pane run ")]
normalized_run_lines = [line.replace("\\", "") for line in run_lines]
assert len(run_lines) == 4, lines
assert any(line.startswith("pane run wCreatedZ:pProxyA ") and "hr-proxy-claude --foreground" in line and "https://openrouter.ai/api/v1" in line and "--label" in line and "two words" in line for line in normalized_run_lines), lines
assert any(line.startswith("pane run wCreatedZ:pStats7 ") and "hr-watch-stats" in line for line in normalized_run_lines), lines
assert any(line.startswith("pane run wCreatedZ:pCodex2 ") and "hr-proxy-codex" in line for line in normalized_run_lines), lines
assert any(line.startswith("pane run wCreatedZ:pShimX ") and "hr-codex-shim" in line for line in normalized_run_lines), lines
assert not any(line.startswith("workspace close wCreatedZ") for line in lines), lines
PY

: > "$LOG"
HERDR_SCENARIO=healthy-existing HERDR_HEALTHY=1 run_launcher
python3 - "$LOG" <<'PY'
import sys
from pathlib import Path
lines = Path(sys.argv[1]).read_text().splitlines()
assert lines == ["workspace list", "workspace focus wExistingQ"], lines
PY

: > "$LOG"
HERDR_SCENARIO=stale-existing HERDR_HEALTHY=0 run_launcher
python3 - "$LOG" <<'PY'
import sys
from pathlib import Path
lines = Path(sys.argv[1]).read_text().splitlines()
close_idx = lines.index("workspace close wExistingQ")
create_idx = next(i for i, line in enumerate(lines) if line.startswith("workspace create "))
assert close_idx < create_idx, lines
PY

: > "$LOG"
HERDR_SCENARIO=new HERDR_HEALTHY=1 run_launcher
python3 - "$LOG" <<'PY'
import sys
from pathlib import Path
lines = Path(sys.argv[1]).read_text().splitlines()
assert lines == ["workspace list"], lines
PY

for invalid_id_kind in missing empty non-string; do
  : > "$LOG"
  set +e
  HERDR_SCENARIO=invalid-existing-id \
  HERDR_INVALID_ID_KIND="$invalid_id_kind" \
  HERDR_HEALTHY=0 \
    run_launcher >/dev/null 2>&1
  status=$?
  set -e
  [ "$status" -ne 0 ]
  python3 - "$LOG" <<'PY'
import sys
from pathlib import Path
lines = Path(sys.argv[1]).read_text().splitlines()
assert lines == ["workspace list"], lines
PY
done

: > "$LOG"
CREATE_FAILURE_STDERR="$TMPDIR/create-failure.stderr"
set +e
HERDR_SCENARIO=incomplete-create HERDR_HEALTHY=0 run_launcher \
  >/dev/null 2>"$CREATE_FAILURE_STDERR"
status=$?
set -e
[ "$status" -eq 1 ]
grep -Fxq 'missing created workspace ID' "$CREATE_FAILURE_STDERR"
python3 - "$LOG" <<'PY'
import sys
from pathlib import Path
lines = Path(sys.argv[1]).read_text().splitlines()
assert lines.count("workspace close wExistingQ") == 1, lines
assert lines.count("workspace close wCreatedZ") == 1, lines
assert lines.index("workspace close wExistingQ") < next(
    i for i, line in enumerate(lines) if line.startswith("workspace create ")
), lines
assert lines[-2:] == ["workspace list", "workspace close wCreatedZ"], lines
assert not any(line.startswith("pane ") for line in lines), lines
PY

: > "$LOG"
set +e
HERDR_SCENARIO=ambiguous-incomplete-create HERDR_HEALTHY=0 run_launcher >/dev/null 2>&1
status=$?
set -e
[ "$status" -ne 0 ]
python3 - "$LOG" <<'PY'
import sys
from pathlib import Path
lines = Path(sys.argv[1]).read_text().splitlines()
assert lines.count("workspace close wExistingQ") == 1, lines
assert "workspace close wCreatedZ" not in lines, lines
assert "workspace close wConcurrent" not in lines, lines
assert lines[-1] == "workspace list", lines
PY

: > "$LOG"
set +e
HERDR_SCENARIO=new HERDR_HEALTHY=0 HERDR_FAIL_SPLIT=2 run_launcher >/dev/null 2>&1
status=$?
set -e
[ "$status" -ne 0 ]
grep -Fxq 'workspace close wCreatedZ' "$LOG"

HELPER="$ROOT/dot_config/zsh/exact_aliases.d/headroom.zsh.tmpl"

cat > "$BIN/tmux" <<'SH'
#!/usr/bin/env sh
printf 'unexpected tmux dispatch: %s\n' "$*" >&2
exit 97
SH
chmod +x "$BIN/tmux"

cat > "$BIN/headroom" <<'SH'
#!/usr/bin/env sh
printf 'headroom %s\n' "$*" >> "$HEADROOM_STUB_LOG"
SH
chmod +x "$BIN/headroom"

: > "$LOG"
PATH="$BIN:$ROOT/dot_local/bin:$PATH" \
HERDR_STUB_LOG="$LOG" \
HERDR_SCENARIO=new \
HERDR_HEALTHY=0 \
HERDR_ENV=1 \
HERDR_WORKSPACE_ID=wCaller \
HERDR_TAB_ID=wCaller:tCaller \
HERDR_PANE_ID=wCaller:pCaller \
TMUX=/tmp/tmux-stub \
HEADROOM_PORT=18883 \
HEADROOM_CODEX_PROXY_PORT=18884 \
HEADROOM_CODEX_SHIM_PORT=18885 \
zsh -fc "source '$HELPER'; hr-proxy-pi --dispatch-check"
grep -Fq 'workspace create' "$LOG"
grep -Fq -- '--dispatch-check' "$LOG"

: > "$LOG"
HEADROOM_LOG="$TMPDIR/headroom.log"
: > "$HEADROOM_LOG"
PATH="$BIN:$ROOT/dot_local/bin:$PATH" \
HERDR_STUB_LOG="$LOG" \
HEADROOM_STUB_LOG="$HEADROOM_LOG" \
HERDR_ENV=1 \
HERDR_WORKSPACE_ID=wCaller \
HERDR_TAB_ID=wCaller:tCaller \
HERDR_PANE_ID=wCaller:pCaller \
zsh -fc "source '$HELPER'; hr-proxy-pi --help"
[ ! -s "$LOG" ]
grep -Fxq 'headroom proxy --help' "$HEADROOM_LOG"

cat > "$NO_HERDR_BIN/tmux" <<'SH'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$TMUX_STUB_LOG"
exit 98
SH
chmod +x "$NO_HERDR_BIN/tmux"

cat > "$NO_HERDR_BIN/headroom" <<'SH'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$HEADROOM_STUB_LOG"
exit 99
SH
chmod +x "$NO_HERDR_BIN/headroom"

MISSING_CLI_STDERR="$TMPDIR/missing-cli.stderr"
TMUX_LOG="$TMPDIR/tmux.log"
: > "$HEADROOM_LOG"
: > "$TMUX_LOG"
set +e
PATH="$NO_HERDR_BIN:$ROOT/dot_local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
HEADROOM_STUB_LOG="$HEADROOM_LOG" \
TMUX_STUB_LOG="$TMUX_LOG" \
HERDR_ENV=1 \
TMUX=/tmp/tmux-stub \
zsh -fc "source '$HELPER'; hr-proxy-pi --dispatch-check" \
  >/dev/null 2>"$MISSING_CLI_STDERR"
status=$?
set -e
[ "$status" -eq 1 ]
grep -Fxq 'hr-proxy-pi is inside Herdr but the herdr CLI is unavailable.' "$MISSING_CLI_STDERR"
[ "$(wc -l < "$MISSING_CLI_STDERR" | tr -d ' ')" -eq 1 ]
[ ! -s "$TMUX_LOG" ]
[ ! -s "$HEADROOM_LOG" ]

echo "Headroom Herdr launcher ok"
