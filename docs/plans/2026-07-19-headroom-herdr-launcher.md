# Headroom Herdr Launcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `hr-proxy-pi` create, reuse, focus, or rebuild a four-pane Headroom workspace when invoked inside Herdr while preserving existing tmux and foreground behavior elsewhere.

**Architecture:** Add a dedicated `executable_headroom-herdr` launcher beside the existing tmux launcher. Keep environment dispatch in `hr-proxy-pi`, prefer `HERDR_ENV=1`, and make the launcher own health checks, Herdr JSON parsing, workspace lifecycle, pane topology, command submission, and partial-setup cleanup.

**Tech Stack:** zsh, Bash test harnesses, Python 3 JSON parsing, chezmoi templates, Herdr CLI.

## Global Constraints

- Herdr orchestration applies only to `hr-proxy-pi`; `hr-proxy-claude` behavior must not change.
- `-h`, `--help`, and `help` must not create or modify a Herdr workspace.
- Prefer Herdr when both `HERDR_ENV=1` and `TMUX` are present.
- Reserve the exact Herdr workspace label `headroom`.
- Never construct Herdr IDs; parse every workspace and pane ID from CLI JSON.
- Healthy services plus an existing `headroom` workspace focus and reuse it.
- Unhealthy services plus matching workspaces close them before creating one replacement.
- Healthy services without a managed workspace do not start duplicate listeners.
- A failed setup closes only the workspace created by that invocation.
- Leave `dot_local/bin/executable_headroom-tmux` unchanged.
- Add no package dependency; use the existing zsh, Python 3, curl, and Herdr commands.

---

## File structure

- Create `dot_local/bin/executable_headroom-herdr`: Herdr health checks, JSON parsing, workspace lifecycle, pane layout, pane commands, and failure cleanup.
- Create `tests/chezmoi/test-headroom-herdr-launcher.sh`: deterministic stub-driven launcher and dispatch coverage.
- Modify `dot_config/headroom/functions.zsh.tmpl`: Herdr-first dispatch in `hr-proxy-pi` only.
- Modify `.chezmoiignore`: keep the new executable managed on non-Linux hosts where `.local/bin/*` is otherwise ignored.
- Modify `tests/chezmoi/test-headroom-layout.sh`: assert the launcher is present, managed, and discoverable.
- Modify `docs/agentic-tooling.md`: document Herdr workspace behavior and troubleshooting.

---

### Task 1: Implement the Herdr workspace launcher

**Files:**
- Create: `tests/chezmoi/test-headroom-herdr-launcher.sh`
- Create: `dot_local/bin/executable_headroom-herdr`

**Interfaces:**
- Consumes: `HERDR_ENV`, `HERDR_WORKSPACE_ID`, `HERDR_TAB_ID`, `HERDR_PANE_ID`, `HEADROOM_PORT`, `HEADROOM_CODEX_PROXY_PORT`, `HEADROOM_CODEX_SHIM_PORT`, `HEADROOM_*_PANE_COLOR`, the caller cwd, and proxy arguments.
- Produces: executable command `executable_headroom-herdr [proxy-args...]`; reserved workspace label `headroom`; pane labels `proxy`, `stats`, `codex-proxy`, and `codex-shim`.

- [ ] **Step 1: Write the failing launcher test**

Create `tests/chezmoi/test-headroom-herdr-launcher.sh` with a temporary `herdr` stub that emits non-sequential IDs and records every command:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LAUNCHER="$ROOT/dot_local/bin/executable_headroom-herdr"
TMPDIR="${TMPDIR:-/tmp}/headroom-herdr-launcher-test-$$"
BIN="$TMPDIR/bin"
LOG="$TMPDIR/herdr.log"
mkdir -p "$BIN"
trap 'rm -rf "$TMPDIR"' EXIT

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
    if scenario in {"healthy-existing", "stale-existing"}:
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
    result = {"type": "workspace_list", "workspaces": workspaces}
elif args[:2] == ["workspace", "create"]:
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
assert len(run_lines) == 4, lines
assert any(line.startswith("pane run wCreatedZ:pProxyA ") and "hr-proxy-claude --foreground" in line and "https://openrouter.ai/api/v1" in line and "--label" in line and "two words" in line for line in run_lines), lines
assert any(line.startswith("pane run wCreatedZ:pStats7 ") and "hr-watch-stats" in line for line in run_lines), lines
assert any(line.startswith("pane run wCreatedZ:pCodex2 ") and "hr-proxy-codex" in line for line in run_lines), lines
assert any(line.startswith("pane run wCreatedZ:pShimX ") and "hr-codex-shim" in line for line in run_lines), lines
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

: > "$LOG"
set +e
HERDR_SCENARIO=new HERDR_HEALTHY=0 HERDR_FAIL_SPLIT=2 run_launcher >/dev/null 2>&1
status=$?
set -e
[ "$status" -ne 0 ]
grep -Fxq 'workspace close wCreatedZ' "$LOG"

echo "Headroom Herdr launcher ok"
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
env -u HEADROOM_PROXY_PANE_COLOR -u HEADROOM_STATS_PANE_COLOR -u HEADROOM_SHIM_PANE_COLOR \
  bash tests/chezmoi/test-headroom-herdr-launcher.sh
```

Expected: exit status `1` because `dot_local/bin/executable_headroom-herdr` does not exist.

- [ ] **Step 3: Implement the launcher**

Create `dot_local/bin/executable_headroom-herdr`:

```zsh
#!/usr/bin/env zsh
set -eu

if [[ "${HERDR_ENV:-}" != 1 ]]; then
    print -u2 'headroom-herdr must run inside a Herdr-managed pane.'
    exit 1
fi

for variable in HERDR_WORKSPACE_ID HERDR_TAB_ID HERDR_PANE_ID; do
    if [[ -z "${(P)variable:-}" ]]; then
        print -u2 "headroom-herdr requires ${variable}."
        exit 1
    fi
done

if ! command -v herdr >/dev/null 2>&1; then
    print -u2 'headroom-herdr requires the herdr CLI.'
    exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
    print -u2 'headroom-herdr requires python3 for Herdr JSON parsing.'
    exit 1
fi

headroom_alias="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/aliases.d/headroom.zsh"
workspace_label='headroom'
created_workspace_id=''

headroom_color_escape() {
    local hex="${1#\#}"
    if [[ "$hex" != [[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]] ]]; then
        return 0
    fi
    printf '\033[38;2;%d;%d;%dm' \
        $((16#${hex[1,2]})) \
        $((16#${hex[3,4]})) \
        $((16#${hex[5,6]}))
}

json_workspace_ids() {
    python3 -c '
import json, sys
for workspace in json.load(sys.stdin)["result"]["workspaces"]:
    if workspace.get("label") == "headroom":
        value = workspace.get("workspace_id")
        if value:
            print(value)
'
}

json_created_workspace_id() {
    python3 -c '
import json, sys
value = json.load(sys.stdin)["result"]["workspace"].get("workspace_id")
if not value:
    raise SystemExit("missing created workspace ID")
print(value)
'
}

json_initial_pane_id() {
    python3 -c '
import json, sys
panes = json.load(sys.stdin)["result"]["panes"]
if len(panes) != 1 or not panes[0].get("pane_id"):
    raise SystemExit("expected one initial pane")
print(panes[0]["pane_id"])
'
}

json_split_pane_id() {
    python3 -c '
import json, sys
value = json.load(sys.stdin)["result"]["pane"].get("pane_id")
if not value:
    raise SystemExit("missing split pane ID")
print(value)
'
}

cleanup_created_workspace() {
    local status=$?
    if [[ -n "$created_workspace_id" ]]; then
        herdr workspace close "$created_workspace_id" >/dev/null 2>&1 || true
    fi
    return $status
}
trap cleanup_created_workspace EXIT INT TERM

proxy_url="http://127.0.0.1:${HEADROOM_PORT:-8787}"
codex_proxy_url="http://127.0.0.1:${HEADROOM_CODEX_PROXY_PORT:-8789}"
codex_shim_url="http://127.0.0.1:${HEADROOM_CODEX_SHIM_PORT:-8788}"
services_healthy=0
if command -v curl >/dev/null 2>&1 \
    && curl -fsS "$proxy_url/health" >/dev/null 2>&1 \
    && curl -fsS "$codex_proxy_url/health" >/dev/null 2>&1 \
    && curl -fsS "$codex_shim_url/health" >/dev/null 2>&1; then
    services_healthy=1
fi

workspace_json="$(herdr workspace list)"
workspace_ids=("${(@f)$(printf '%s' "$workspace_json" | json_workspace_ids)}")
if [[ ${#workspace_ids[@]} -eq 1 && -z "$workspace_ids[1]" ]]; then
    workspace_ids=()
fi

if (( services_healthy )); then
    if (( ${#workspace_ids[@]} )); then
        herdr workspace focus "$workspace_ids[1]" >/dev/null
        printf 'Headroom workspace already active: %s\n' "$workspace_ids[1]"
    else
        printf 'Headroom services are healthy but no managed Herdr workspace exists; leaving them unchanged.\n'
    fi
    trap - EXIT INT TERM
    exit 0
fi

for workspace_id in $workspace_ids; do
    printf 'Removing stale Headroom Herdr workspace: %s\n' "$workspace_id" >&2
    herdr workspace close "$workspace_id" >/dev/null
done

create_json="$(herdr workspace create --cwd "$PWD" --label "$workspace_label" --focus)"
created_workspace_id="$(printf '%s' "$create_json" | json_created_workspace_id)"
panes_json="$(herdr pane list --workspace "$created_workspace_id")"
proxy_pane_id="$(printf '%s' "$panes_json" | json_initial_pane_id)"

herdr pane rename "$proxy_pane_id" proxy >/dev/null
stats_json="$(herdr pane split "$proxy_pane_id" --direction right --no-focus)"
stats_pane_id="$(printf '%s' "$stats_json" | json_split_pane_id)"
herdr pane rename "$stats_pane_id" stats >/dev/null
codex_proxy_json="$(herdr pane split "$stats_pane_id" --direction down --no-focus)"
codex_proxy_pane_id="$(printf '%s' "$codex_proxy_json" | json_split_pane_id)"
herdr pane rename "$codex_proxy_pane_id" codex-proxy >/dev/null
shim_json="$(herdr pane split "$codex_proxy_pane_id" --direction down --no-focus)"
shim_pane_id="$(printf '%s' "$shim_json" | json_split_pane_id)"
herdr pane rename "$shim_pane_id" codex-shim >/dev/null

proxy_args="${(j: :)${(q)@}}"
proxy_color="$(headroom_color_escape "${HEADROOM_PROXY_PANE_COLOR:-}")"
stats_color="$(headroom_color_escape "${HEADROOM_STATS_PANE_COLOR:-}")"
shim_color="$(headroom_color_escape "${HEADROOM_SHIM_PANE_COLOR:-}")"
proxy_cmd="printf ${(q)proxy_color}; source ${(q)headroom_alias}; hr-proxy-claude --foreground --openai-api-url https://openrouter.ai/api/v1 ${proxy_args}; exec zsh -l"
stats_cmd="printf ${(q)stats_color}; source ${(q)headroom_alias}; hr-watch-stats; exec zsh -l"
codex_proxy_cmd="printf ${(q)shim_color}; source ${(q)headroom_alias}; hr-proxy-codex; exec zsh -l"
shim_cmd="printf ${(q)shim_color}; source ${(q)headroom_alias}; hr-codex-shim; exec zsh -l"

herdr pane run "$proxy_pane_id" "zsh -lc ${(q)proxy_cmd}" >/dev/null
herdr pane run "$stats_pane_id" "zsh -lc ${(q)stats_cmd}" >/dev/null
herdr pane run "$codex_proxy_pane_id" "zsh -lc ${(q)codex_proxy_cmd}" >/dev/null
herdr pane run "$shim_pane_id" "zsh -lc ${(q)shim_cmd}" >/dev/null

created_workspace_id=''
trap - EXIT INT TERM
printf 'Headroom Herdr workspace ready.\n'
```

Make it executable:

```bash
chmod +x dot_local/bin/executable_headroom-herdr
```

- [ ] **Step 4: Run the launcher test to verify it passes**

Run:

```bash
env -u HEADROOM_PROXY_PANE_COLOR -u HEADROOM_STATS_PANE_COLOR -u HEADROOM_SHIM_PANE_COLOR \
  bash tests/chezmoi/test-headroom-herdr-launcher.sh
```

Expected: exit status `0` and final line `Headroom Herdr launcher ok`.

- [ ] **Step 5: Run a syntax check**

Run:

```bash
zsh -n dot_local/bin/executable_headroom-herdr
bash -n tests/chezmoi/test-headroom-herdr-launcher.sh
```

Expected: both exit `0` with no output.

- [ ] **Step 6: Commit the launcher slice**

```bash
git add dot_local/bin/executable_headroom-herdr tests/chezmoi/test-headroom-herdr-launcher.sh
git commit -m "feat(headroom): add Herdr workspace launcher"
```

---

### Task 2: Add Herdr-first `hr-proxy-pi` dispatch and chezmoi management

**Files:**
- Modify: `tests/chezmoi/test-headroom-herdr-launcher.sh`
- Modify: `dot_config/headroom/functions.zsh.tmpl:173-175`
- Modify: `.chezmoiignore:49-54`
- Modify: `tests/chezmoi/test-headroom-layout.sh:5-18,48-57`

**Interfaces:**
- Consumes: `executable_headroom-herdr` from Task 1 and the existing `hr-run-headroom-command` helper.
- Produces: `hr-proxy-pi` dispatch contract: help first, then Herdr, then unchanged `hr-proxy-claude` behavior.

- [ ] **Step 1: Extend the test with failing dispatch assertions**

Append setup stubs and dispatch cases to `tests/chezmoi/test-headroom-herdr-launcher.sh` before its final success message:

```bash
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
```

Also move the existing `echo "Headroom Herdr launcher ok"` to remain the last line.

- [ ] **Step 2: Run the dispatch test to verify it fails**

Run:

```bash
env -u HEADROOM_PROXY_PANE_COLOR -u HEADROOM_STATS_PANE_COLOR -u HEADROOM_SHIM_PANE_COLOR \
  bash tests/chezmoi/test-headroom-herdr-launcher.sh
```

Expected: non-zero exit because `hr-proxy-pi` still enters the tmux path when both environment markers are present.

- [ ] **Step 3: Add Herdr-first dispatch to `hr-proxy-pi`**

Replace the current `hr-proxy-pi` body in `dot_config/headroom/functions.zsh.tmpl` with:

```zsh
hr-proxy-pi() {
    case "${1:-}" in
        -h|--help|help)
            hr-proxy-claude --help
            return $?
            ;;
    esac

    if [ "${HERDR_ENV:-}" = 1 ]; then
        if ! command -v herdr >/dev/null 2>&1; then
            printf 'hr-proxy-pi is inside Herdr but the herdr CLI is unavailable.\n' >&2
            return 1
        fi
        hr-run-headroom-command headroom-herdr executable_headroom-herdr "$@"
        return $?
    fi

    hr-proxy-claude --openai-api-url https://openrouter.ai/api/v1 "$@"
}
```

- [ ] **Step 4: Make the executable managed and discoverable**

Add the Herdr launcher exception beside the tmux launcher in `.chezmoiignore`:

```text
!.local/bin/headroom-herdr
!.local/bin/headroom-tmux
```

Update `tests/chezmoi/test-headroom-layout.sh` so the file variables and required-file loop include:

```bash
HERDR_LAUNCHER="$ROOT/dot_local/bin/executable_headroom-herdr"
TMUX_LAUNCHER="$ROOT/dot_local/bin/executable_headroom-tmux"

for path in "$ENV_FILE" "$FUNCTIONS_FILE" "$CODEX_SHIM" "$HERDR_LAUNCHER" "$TMUX_LAUNCHER"; do
```

Add the managed-path assertion:

```bash
grep -qx '.local/bin/headroom-herdr' <<<"$managed"
grep -qx '.local/bin/headroom-tmux' <<<"$managed"
```

Add the executable discovery assertion:

```bash
command -v executable_headroom-herdr >/dev/null
command -v executable_headroom-tmux >/dev/null
```

- [ ] **Step 5: Run focused tests**

Run:

```bash
env -u HEADROOM_PROXY_PANE_COLOR -u HEADROOM_STATS_PANE_COLOR -u HEADROOM_SHIM_PANE_COLOR \
  bash tests/chezmoi/test-headroom-herdr-launcher.sh
env -u HEADROOM_PROXY_PANE_COLOR -u HEADROOM_STATS_PANE_COLOR -u HEADROOM_SHIM_PANE_COLOR \
  bash tests/chezmoi/test-headroom-layout.sh
env -u HEADROOM_PROXY_PANE_COLOR -u HEADROOM_STATS_PANE_COLOR -u HEADROOM_SHIM_PANE_COLOR \
  bash tests/chezmoi/test-headroom-tmux-launcher.sh
```

Expected: all exit `0`; the Herdr test ends with `Headroom Herdr launcher ok`, and the tmux test retains its existing successful output.

- [ ] **Step 6: Commit the dispatch slice**

```bash
git add .chezmoiignore dot_config/headroom/functions.zsh.tmpl tests/chezmoi/test-headroom-layout.sh tests/chezmoi/test-headroom-herdr-launcher.sh
git commit -m "feat(headroom): dispatch Pi launcher through Herdr"
```

---

### Task 3: Document and verify the completed behavior

**Files:**
- Modify: `docs/agentic-tooling.md:3-53`

**Interfaces:**
- Consumes: the completed launcher and dispatch behavior from Tasks 1 and 2.
- Produces: user-facing operating and troubleshooting instructions for tmux, Herdr, and foreground shells.

- [ ] **Step 1: Update Headroom command and troubleshooting documentation**

In `docs/agentic-tooling.md`, add this subsection after the routing diagram:

```markdown
### multiplexer layout

`hr-proxy-pi` detects its terminal environment:

- inside HerdR, it creates or reuses a dedicated `headroom` workspace;
- otherwise, inside tmux, it uses the existing `headroom` window launcher;
- outside either multiplexer, it keeps the foreground fallback.

The HerdR workspace contains four panes: the primary proxy on the left, with stats, the Codex proxy, and the Codex shim stacked on the right. HerdR takes precedence if both `HERDR_ENV` and `TMUX` are present.

Re-running `hr-proxy-pi` focuses a healthy `headroom` workspace. If any service is unhealthy, it removes matching stale workspaces and creates one clean replacement. If all services are healthy but were started outside the managed workspace, the command leaves them running and does not create duplicate listeners.
```

Replace the tmux-only stale-pane troubleshooting bullet with:

```markdown
- if managed panes are stale or ports are unhealthy, re-run `hr-proxy-pi`; it rebuilds the dedicated HerdR workspace or tmux window for the detected environment.
```

- [ ] **Step 2: Run documentation and shell syntax checks**

Run:

```bash
bash -n tests/chezmoi/test-headroom-herdr-launcher.sh
bash -n tests/chezmoi/test-headroom-layout.sh
bash -n tests/chezmoi/test-headroom-tmux-launcher.sh
zsh -n dot_local/bin/executable_headroom-herdr
zsh -n dot_config/headroom/functions.zsh.tmpl
```

Expected: all commands exit `0` with no syntax errors.

- [ ] **Step 3: Run all Headroom-focused tests**

Run:

```bash
for test_file in tests/chezmoi/test-headroom*.sh tests/chezmoi/test-hr-pix*.sh; do
  env -u HEADROOM_PROXY_PANE_COLOR \
      -u HEADROOM_STATS_PANE_COLOR \
      -u HEADROOM_SHIM_PANE_COLOR \
      bash "$test_file"
done
```

Expected: every test exits `0`.

- [ ] **Step 4: Run repository static analysis for changed files**

Run:

```bash
fallow audit --changed-since main
```

Expected: exit status `0` with no blocking findings.

- [ ] **Step 5: Inspect the final diff**

Run:

```bash
git diff --check main...HEAD
git diff --stat main...HEAD
git diff main...HEAD -- \
  .chezmoiignore \
  dot_config/headroom/functions.zsh.tmpl \
  dot_local/bin/executable_headroom-herdr \
  tests/chezmoi/test-headroom-layout.sh \
  tests/chezmoi/test-headroom-herdr-launcher.sh \
  docs/agentic-tooling.md
```

Expected: no whitespace errors; only the approved Herdr launcher, dispatch, tests, management rule, and documentation changes appear.

- [ ] **Step 6: Commit documentation**

```bash
git add docs/agentic-tooling.md
git commit -m "docs: explain Headroom Herdr workspace"
```

- [ ] **Step 7: Record final evidence**

Run:

```bash
git status --short --branch
git log --oneline --decorate main..HEAD
```

Expected: a clean worktree on `feat/headroom-herdr` with the design, plan, launcher, dispatch, and documentation commits listed.
