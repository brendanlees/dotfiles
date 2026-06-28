# Agent Sesh State Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `sesh` aware of actionable Claude/Pi tmux panes by writing local pane state and using it for preview, filtering, and jump navigation.

**Architecture:** Claude and Pi completion hooks write one XDG-local state file per tmux pane. Chezmoi-managed sesh scripts read those files, validate that tmux panes still exist, and expose preview/list/jump UX without adding status bar noise. The existing `sesh` picker remains the main router; custom `agent:` rows are handled by a small branch in the picker.

**Tech Stack:** Bash 3-compatible shell scripts, tmux 3.6a formats, sesh 2.26.2 CLI, fzf reload bindings, chezmoi templates, external Claude/Pi harness repos from `.chezmoiexternal.toml.tmpl`.

## Global Constraints

- Work in `/Users/brendan/.local/share/chezmoi.feat-agent-sesh-state`, not the `main` checkout.
- Keep `sesh` as the session router and picker; do not replace it.
- Keep tmux `status-right` empty; do not add dashboards, sidebars, or permanent visual noise.
- Use `${XDG_STATE_HOME:-$HOME/.local/state}/agent-tmux/` for runtime state.
- MVP state is actionable completion only: `state=done`.
- Start with Claude and Pi emitters only.
- State is machine-local and must not be checked into chezmoi.
- Reader scripts must tolerate missing, malformed, and stale state records.
- Existing bell behavior from `docs/superpowers/specs/2026-06-26-agent-tmux-bell-state-design.md` must keep working.

---

## File Structure

### Current dotfiles repo

- Create `dot_config/sesh/scripts/executable_agent-state.sh.tmpl`
  - Single shared CLI for state read/write operations.
  - Subcommands: `write-done`, `list`, `preview`, `jump`, `target`.
  - Owns state directory lookup, env-file parsing, stale pane checks, and tmux navigation.
- Create `dot_config/sesh/scripts/executable_preview-with-agent-state.sh.tmpl`
  - Thin wrapper for fzf preview: calls `agent-state.sh preview "$@"`, then falls through to `sesh preview "$@"`.
- Create `dot_config/sesh/scripts/executable_list-agent-sessions.sh.tmpl`
  - Thin wrapper for fzf reload: calls `agent-state.sh list`.
- Create `dot_config/sesh/scripts/executable_agent-next.sh.tmpl`
  - Thin wrapper for tmux binding and picker custom rows: calls `agent-state.sh jump` or `agent-state.sh target`.
- Modify `dot_config/sesh/scripts/executable_picker.sh.tmpl`
  - Add `ctrl-e` binding.
  - Use `preview-with-agent-state.sh` for preview.
  - Branch selected `agent:%pane` rows to `agent-next.sh --target` instead of `sesh connect`.
- Modify `dot_config/tmux/tmux.conf.tmpl`
  - Add `bind-key A run-shell '~/.config/sesh/scripts/agent-next.sh'` near the existing sesh binding.
- Create `tests/chezmoi/test-agent-tmux-state-scripts.sh`
  - Tests rendered script syntax and core state behavior with a fake `tmux` binary and temp `AGENT_TMUX_STATE_DIR`.
- Create or update `docs/superpowers/plans/2026-06-28-agent-sesh-state.md`
  - This plan.

### External harness repos

These live outside this chezmoi repo but are referenced by `.chezmoiexternal.toml.tmpl`:

- Modify `~/.claude/hooks/tmux-agent-state.sh`
  - After ringing the existing bell, call `~/.config/sesh/scripts/agent-state.sh write-done --harness claude`.
  - Must remain no-op outside tmux and must not block Claude.
- Modify `~/.pi/agent/extensions/agent-tmux-state.ts`
  - When invoking the helper, pass `complete --harness pi`. Pi docs for `pi.exec` document `signal`/`timeout` but not child-process `env`, so use arguments instead of relying on undocumented env support.
  - Preserve `ctx.hasPendingMessages()` guard.

---

### Task 1: Add state CLI and focused shell tests

**Files:**
- Create: `dot_config/sesh/scripts/executable_agent-state.sh.tmpl`
- Create: `tests/chezmoi/test-agent-tmux-state-scripts.sh`

**Interfaces:**
- Produces executable `~/.config/sesh/scripts/agent-state.sh` with:
  - `agent-state.sh write-done --harness <name>`: writes current tmux pane state.
  - `agent-state.sh list`: prints fzf-selectable `agent:%pane ...` rows, oldest first.
  - `agent-state.sh preview <selection>`: prints agent metadata for an `agent:%pane` row or a normal sesh tmux-session row.
  - `agent-state.sh jump`: jumps to oldest valid `done` pane.
  - `agent-state.sh target <agent:%pane|%pane>`: jumps to a specific valid pane.
- Consumes tmux formats:
  - `#{pane_id}`
  - `#{session_id}`
  - `#{session_name}`
  - `#{window_id}`
  - `#{window_index}`
  - `#{window_name}`
  - `#{pane_current_path}`

- [ ] **Step 1: Create failing test for write/list/preview/target behavior**

Create `tests/chezmoi/test-agent-tmux-state-scripts.sh` with this content:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

script="$repo_root/dot_config/sesh/scripts/executable_agent-state.sh.tmpl"
state_dir="$tmpdir/state"
fake_bin="$tmpdir/bin"
mkdir -p "$fake_bin" "$state_dir"

cat > "$fake_bin/tmux" <<'TMUX'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${TMUX_LOG:?}"
case "$1" in
  display-message)
    if [[ "$*" == *'#{pane_id}'* ]]; then
      printf '%%12\t$1\tdotfiles\t@2\t3\tagent-window\t/tmp/project\n'
    fi
    ;;
  has-session)
    exit 0
    ;;
  list-panes)
    printf '%%12\n'
    ;;
  switch-client|select-window|select-pane|display-popup)
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
TMUX
chmod +x "$fake_bin/tmux"

export PATH="$fake_bin:$PATH"
export TMUX=/tmp/tmux-test
export TMUX_PANE=%12
export TMUX_LOG="$tmpdir/tmux.log"
export AGENT_TMUX_STATE_DIR="$state_dir"

bash -n "$script"

"$script" write-done --harness claude
record="$state_dir/pane-%12.env"
[[ -f "$record" ]]
grep -q "^HARNESS='claude'$" "$record"
grep -q "^STATE='done'$" "$record"
grep -q "^PANE_ID='%12'$" "$record"
grep -q "^SESSION_NAME='dotfiles'$" "$record"

list_output=$("$script" list)
[[ "$list_output" == agent:%12* ]]
[[ "$list_output" == *claude* ]]
[[ "$list_output" == *dotfiles* ]]

preview_output=$("$script" preview 'agent:%12 claude done dotfiles:3 agent-window /tmp/project')
[[ "$preview_output" == *'agent: claude'* ]]
[[ "$preview_output" == *'state: done'* ]]
[[ "$preview_output" == *'pane: %12'* ]]

"$script" target 'agent:%12 claude done dotfiles:3 agent-window /tmp/project'
grep -q 'switch-client -t $1' "$TMUX_LOG"
grep -q 'select-window -t @2' "$TMUX_LOG"
grep -q 'select-pane -t %12' "$TMUX_LOG"
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bash tests/chezmoi/test-agent-tmux-state-scripts.sh
```

Expected: FAIL because `dot_config/sesh/scripts/executable_agent-state.sh.tmpl` does not exist.

- [ ] **Step 3: Add minimal state CLI**

Create `dot_config/sesh/scripts/executable_agent-state.sh.tmpl`:

```bash
#!/usr/bin/env bash
set -euo pipefail

state_dir() {
  if [[ -n "${AGENT_TMUX_STATE_DIR:-}" ]]; then
    printf '%s\n' "$AGENT_TMUX_STATE_DIR"
  elif [[ -n "${XDG_STATE_HOME:-}" ]]; then
    printf '%s/agent-tmux\n' "$XDG_STATE_HOME"
  else
    printf '%s/.local/state/agent-tmux\n' "$HOME"
  fi
}

quote_value() {
  local value=${1:-}
  printf "'%s'" "${value//\'/\'\\\'\'}"
}

record_path_for_pane() {
  local pane=${1:?pane required}
  printf '%s/pane-%s.env\n' "$(state_dir)" "$pane"
}

write_assignment() {
  local key=${1:?key required}
  local value=${2:-}
  printf '%s=%s\n' "$key" "$(quote_value "$value")"
}

load_record() {
  local file=${1:?file required}
  [[ -f "$file" ]] || return 1
  if ! grep -Eq "^[A-Z_]+='([^']|'\\'')*'$" "$file"; then
    return 1
  fi
  # shellcheck disable=SC1090
  source "$file"
}

pane_exists() {
  local pane=${1:?pane required}
  command -v tmux >/dev/null 2>&1 || return 1
  tmux list-panes -a -F '#{pane_id}' 2>/dev/null | grep -Fxq "$pane"
}

write_done() {
  local harness=agent
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --harness)
        harness=${2:?--harness requires value}
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  [[ -n "${TMUX:-}" && -n "${TMUX_PANE:-}" ]] || exit 0
  command -v tmux >/dev/null 2>&1 || exit 0

  local line
  line=$(tmux display-message -p -t "$TMUX_PANE" '#{pane_id}\t#{session_id}\t#{session_name}\t#{window_id}\t#{window_index}\t#{window_name}\t#{pane_current_path}' 2>/dev/null || true)
  [[ -n "$line" ]] || exit 0

  local pane_id session_id session_name window_id window_index window_name pane_current_path
  IFS=$'\t' read -r pane_id session_id session_name window_id window_index window_name pane_current_path <<< "$line"
  [[ -n "$pane_id" ]] || exit 0

  local dir file tmp
  dir=$(state_dir)
  mkdir -p "$dir"
  file=$(record_path_for_pane "$pane_id")
  tmp="$file.$$"

  {
    write_assignment HARNESS "$harness"
    write_assignment STATE done
    write_assignment PANE_ID "$pane_id"
    write_assignment SESSION_ID "$session_id"
    write_assignment SESSION_NAME "$session_name"
    write_assignment WINDOW_ID "$window_id"
    write_assignment WINDOW_INDEX "$window_index"
    write_assignment WINDOW_NAME "$window_name"
    write_assignment PANE_CURRENT_PATH "$pane_current_path"
    write_assignment UPDATED_AT "$(date +%s)"
  } > "$tmp"
  mv "$tmp" "$file"
}

record_files() {
  local dir
  dir=$(state_dir)
  [[ -d "$dir" ]] || return 0
  find "$dir" -maxdepth 1 -type f -name 'pane-*.env' -print
}

valid_records() {
  local file
  while IFS= read -r file; do
    unset HARNESS STATE PANE_ID SESSION_ID SESSION_NAME WINDOW_ID WINDOW_INDEX WINDOW_NAME PANE_CURRENT_PATH UPDATED_AT
    if load_record "$file" && [[ "${STATE:-}" == done ]] && [[ -n "${PANE_ID:-}" ]] && pane_exists "$PANE_ID"; then
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "${UPDATED_AT:-0}" "${PANE_ID:-}" "${HARNESS:-agent}" "${SESSION_ID:-}" "${SESSION_NAME:-}" \
        "${WINDOW_ID:-}" "${WINDOW_INDEX:-}" "${WINDOW_NAME:-}" "${PANE_CURRENT_PATH:-}"
    else
      rm -f "$file" 2>/dev/null || true
    fi
  done < <(record_files)
}

list_records() {
  valid_records | sort -n | while IFS=$'\t' read -r updated pane harness session_id session_name window_id window_index window_name path; do
    printf 'agent:%s  🤖 %s  done  %s:%s  %s  %s\n' "$pane" "$harness" "$session_name" "$window_index" "$window_name" "$path"
  done
}

pane_from_selection() {
  local selection=${1:-}
  selection=${selection#agent:}
  printf '%s\n' "${selection%%[[:space:]]*}"
}

preview_selection() {
  local selection=${*:-}
  local pane file
  if [[ "$selection" == agent:%* ]]; then
    pane=$(pane_from_selection "$selection")
    file=$(record_path_for_pane "$pane")
    if load_record "$file"; then
      printf 'agent: %s\n' "${HARNESS:-agent}"
      printf 'state: %s\n' "${STATE:-unknown}"
      printf 'pane: %s\n' "${PANE_ID:-$pane}"
      printf 'session: %s\n' "${SESSION_NAME:-unknown}"
      printf 'window: %s:%s %s\n' "${WINDOW_INDEX:-?}" "${WINDOW_ID:-?}" "${WINDOW_NAME:-unknown}"
      printf 'path: %s\n' "${PANE_CURRENT_PATH:-unknown}"
      printf 'updated: %s\n' "${UPDATED_AT:-unknown}"
      printf '\n'
    fi
    return 0
  fi

  local stripped session_name
  stripped=$(printf '%s' "$selection" | sed -E 's/\x1B\[[0-9;]*[A-Za-z]//g')
  session_name=${stripped##* }
  valid_records | sort -n | awk -F '\t' -v session="$session_name" '$5 == session {print; found=1; exit} END {exit found ? 0 : 1}' | while IFS=$'\t' read -r updated pane harness session_id session window_id window_index window_name path; do
    printf 'agent: %s\nstate: done\npane: %s\nsession: %s\nwindow: %s:%s %s\npath: %s\nupdated: %s\n\n' \
      "$harness" "$pane" "$session" "$window_index" "$window_id" "$window_name" "$path" "$updated"
  done || true
}

jump_to_pane() {
  local pane=${1:?pane required}
  local file
  file=$(record_path_for_pane "$pane")
  load_record "$file" || return 1
  pane_exists "${PANE_ID:-}" || return 1
  tmux switch-client -t "${SESSION_ID:-${SESSION_NAME:-}}" >/dev/null 2>&1 || true
  tmux select-window -t "${WINDOW_ID:-}" >/dev/null 2>&1 || true
  tmux select-pane -t "${PANE_ID:-}" >/dev/null 2>&1 || true
}

jump_oldest() {
  local row pane
  row=$(valid_records | sort -n | head -n 1 || true)
  if [[ -z "$row" ]]; then
    tmux display-message 'No actionable agent panes' 2>/dev/null || true
    return 0
  fi
  IFS=$'\t' read -r _ pane _ <<< "$row"
  jump_to_pane "$pane"
}

case "${1:-}" in
  write-done)
    shift
    write_done "$@"
    ;;
  list)
    list_records
    ;;
  preview)
    shift
    preview_selection "$@"
    ;;
  jump)
    jump_oldest
    ;;
  target)
    shift
    jump_to_pane "$(pane_from_selection "${*:-}")"
    ;;
  *)
    printf 'usage: %s {write-done|list|preview|jump|target}\n' "$0" >&2
    exit 2
    ;;
esac
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
bash tests/chezmoi/test-agent-tmux-state-scripts.sh
```

Expected: PASS with no output.

- [ ] **Step 5: Commit Task 1**

Run:

```bash
git add dot_config/sesh/scripts/executable_agent-state.sh.tmpl tests/chezmoi/test-agent-tmux-state-scripts.sh
git commit -m "feat: add agent tmux state script"
```

---

### Task 2: Add preview/list/jump wrappers

**Files:**
- Create: `dot_config/sesh/scripts/executable_preview-with-agent-state.sh.tmpl`
- Create: `dot_config/sesh/scripts/executable_list-agent-sessions.sh.tmpl`
- Create: `dot_config/sesh/scripts/executable_agent-next.sh.tmpl`
- Modify: `tests/chezmoi/test-agent-tmux-state-scripts.sh`

**Interfaces:**
- Consumes: `agent-state.sh preview`, `agent-state.sh list`, `agent-state.sh jump`, `agent-state.sh target` from Task 1.
- Produces stable script names used by fzf and tmux config.

- [ ] **Step 1: Extend test for wrapper syntax and delegation**

Append this to `tests/chezmoi/test-agent-tmux-state-scripts.sh`:

```bash
for wrapper in \
  "$repo_root/dot_config/sesh/scripts/executable_preview-with-agent-state.sh.tmpl" \
  "$repo_root/dot_config/sesh/scripts/executable_list-agent-sessions.sh.tmpl" \
  "$repo_root/dot_config/sesh/scripts/executable_agent-next.sh.tmpl"; do
  bash -n "$wrapper"
done

cat > "$fake_bin/sesh" <<'SESH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1" == preview ]]; then
  printf 'sesh preview: %s\n' "${2:-}"
fi
SESH
chmod +x "$fake_bin/sesh"

preview_wrapper="$repo_root/dot_config/sesh/scripts/executable_preview-with-agent-state.sh.tmpl"
combined_preview=$("$preview_wrapper" 'agent:%12 claude done dotfiles:3 agent-window /tmp/project')
[[ "$combined_preview" == *'agent: claude'* ]]
[[ "$combined_preview" == *'sesh preview: agent:%12 claude done dotfiles:3 agent-window /tmp/project'* ]]
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bash tests/chezmoi/test-agent-tmux-state-scripts.sh
```

Expected: FAIL because wrapper scripts do not exist.

- [ ] **Step 3: Create wrappers**

Create `dot_config/sesh/scripts/executable_preview-with-agent-state.sh.tmpl`:

```bash
#!/usr/bin/env bash
set -euo pipefail

agent_state="$HOME/.config/sesh/scripts/agent-state.sh"
if [[ -x "$agent_state" ]]; then
  "$agent_state" preview "$@" || true
fi

exec sesh preview "$@"
```

Create `dot_config/sesh/scripts/executable_list-agent-sessions.sh.tmpl`:

```bash
#!/usr/bin/env bash
set -euo pipefail

exec "$HOME/.config/sesh/scripts/agent-state.sh" list
```

Create `dot_config/sesh/scripts/executable_agent-next.sh.tmpl`:

```bash
#!/usr/bin/env bash
set -euo pipefail

agent_state="$HOME/.config/sesh/scripts/agent-state.sh"

case "${1:-}" in
  --target)
    shift
    exec "$agent_state" target "$@"
    ;;
  *)
    exec "$agent_state" jump
    ;;
esac
```

- [ ] **Step 4: Run test to verify it passes**

Run:

```bash
bash tests/chezmoi/test-agent-tmux-state-scripts.sh
```

Expected: PASS with no output.

- [ ] **Step 5: Commit Task 2**

Run:

```bash
git add dot_config/sesh/scripts/executable_preview-with-agent-state.sh.tmpl \
  dot_config/sesh/scripts/executable_list-agent-sessions.sh.tmpl \
  dot_config/sesh/scripts/executable_agent-next.sh.tmpl \
  tests/chezmoi/test-agent-tmux-state-scripts.sh
git commit -m "feat: add agent sesh wrapper scripts"
```

---

### Task 3: Wire picker and tmux binding

**Files:**
- Modify: `dot_config/sesh/scripts/executable_picker.sh.tmpl`
- Modify: `dot_config/tmux/tmux.conf.tmpl`
- Modify: `tests/chezmoi/test-agent-tmux-state-scripts.sh`

**Interfaces:**
- Consumes wrapper scripts from Task 2.
- Produces:
  - Picker `ctrl-e` agents-only mode.
  - Picker custom-row dispatch for `agent:%pane` selections.
  - tmux `prefix A` jump binding.

- [ ] **Step 1: Add static wiring assertions to test**

Append this to `tests/chezmoi/test-agent-tmux-state-scripts.sh`:

```bash
picker="$repo_root/dot_config/sesh/scripts/executable_picker.sh.tmpl"
tmux_conf="$repo_root/dot_config/tmux/tmux.conf.tmpl"

grep -q "ctrl-e:change-prompt" "$picker"
grep -q "list-agent-sessions.sh" "$picker"
grep -q "preview-with-agent-state.sh" "$picker"
grep -q "agent-next.sh --target" "$picker"
grep -q "bind-key A run-shell '~/.config/sesh/scripts/agent-next.sh'" "$tmux_conf"
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bash tests/chezmoi/test-agent-tmux-state-scripts.sh
```

Expected: FAIL because picker and tmux config are not wired yet.

- [ ] **Step 3: Modify picker script**

Replace the bottom selection block in `dot_config/sesh/scripts/executable_picker.sh.tmpl` with:

```bash
selected="$({
  sesh list --icons "$@" | fzf "${TMUX_FLAGS[@]}" \
    --no-sort --ansi --border-label ' sesh ' --prompt '󰚌  ' \
    --header '  ^a all ^t tmux ^g configs ^x zoxide ^e agents ^d tmux kill ^f find ' \
    --bind 'tab:down,btab:up' \
    --bind 'ctrl-a:change-prompt(⚡)+reload(sesh list --icons)' \
    --bind 'ctrl-t:change-prompt(🪟  )+reload(sesh list -t --icons)' \
    --bind 'ctrl-g:change-prompt(⚙️  )+reload(sesh list -c --icons)' \
    --bind 'ctrl-x:change-prompt(📁  )+reload(sesh list -z --icons)' \
    --bind 'ctrl-e:change-prompt(🤖  )+reload(~/.config/sesh/scripts/list-agent-sessions.sh)' \
    --bind 'ctrl-f:change-prompt(🔎  )+reload(fd -H -d 2 -t d -E .Trash . ~)' \
    --bind 'ctrl-d:execute(tmux kill-session -t {2..})+change-prompt(⚡  )+reload(sesh list --icons)' \
    --preview-window 'right:55%' \
    --preview '~/.config/sesh/scripts/preview-with-agent-state.sh {}'
})"

case "$selected" in
  agent:%*)
    ~/.config/sesh/scripts/agent-next.sh --target "$selected"
    ;;
  "")
    exit 0
    ;;
  *)
    sesh connect "$selected"
    ;;
esac
```

Keep the existing shebang, PATH setup, FZF opts setup, and `TMUX_FLAGS` logic above this block unchanged.

- [ ] **Step 4: Add tmux jump binding**

In `dot_config/tmux/tmux.conf.tmpl`, immediately after:

```tmux
bind-key "K" run-shell "~/.config/sesh/scripts/picker.sh --tmux"
```

add:

```tmux
bind-key A run-shell '~/.config/sesh/scripts/agent-next.sh'
```

- [ ] **Step 5: Run tests and render checks**

Run:

```bash
bash tests/chezmoi/test-agent-tmux-state-scripts.sh
chezmoi execute-template --source . --file dot_config/tmux/tmux.conf.tmpl >/tmp/agent-sesh-tmux.conf
chezmoi execute-template --source . --file dot_config/sesh/scripts/executable_picker.sh.tmpl >/tmp/agent-sesh-picker.sh
bash -n /tmp/agent-sesh-picker.sh
```

Expected: all commands PASS; rendered picker has valid Bash syntax.

- [ ] **Step 6: Commit Task 3**

Run:

```bash
git add dot_config/sesh/scripts/executable_picker.sh.tmpl dot_config/tmux/tmux.conf.tmpl tests/chezmoi/test-agent-tmux-state-scripts.sh
git commit -m "feat: wire agent state into sesh picker"
```

---

### Task 4: Wire Claude and Pi emitters in external harness repos

**Files:**
- Modify external: `/Users/brendan/.claude/hooks/tmux-agent-state.sh`
- Modify external: `/Users/brendan/.pi/agent/extensions/agent-tmux-state.ts`

**Interfaces:**
- Consumes rendered `~/.config/sesh/scripts/agent-state.sh write-done --harness <name>` from the dotfiles repo.
- Preserves existing bell helper behavior.

- [ ] **Step 1: Verify external repos are clean**

Run:

```bash
git -C ~/.claude status --short
git -C ~/.pi status --short
```

Expected: either both clean, or report existing changes before proceeding.

- [ ] **Step 2: Modify Claude helper**

In `/Users/brendan/.claude/hooks/tmux-agent-state.sh`, after the successful bell call path or just before final exit, add a non-blocking state write:

```bash
write_agent_state() {
  local writer="$HOME/.config/sesh/scripts/agent-state.sh"
  if [[ -x "$writer" ]]; then
    "$writer" write-done --harness "${AGENT_TMUX_HARNESS:-claude}" >/dev/null 2>&1 || true
  fi
}

write_agent_state
```

Do not remove the existing BEL emission. Do not make Claude fail if state writing fails.

- [ ] **Step 3: Syntax-check Claude helper**

Run:

```bash
bash -n ~/.claude/hooks/tmux-agent-state.sh
```

Expected: PASS with no output.

- [ ] **Step 4: Modify Pi extension**

In `/Users/brendan/.pi/agent/extensions/agent-tmux-state.ts`, change the helper invocation from:

```ts
const result = await pi.exec(script, ["complete"], { timeout: 1_000 });
```

to:

```ts
const result = await pi.exec(script, ["complete", "--harness", "pi"], { timeout: 1_000 });
```

Keep the existing `try`/`catch` so helper failures are ignored exactly like the existing bell helper path.

- [ ] **Step 5: Type/syntax-check Pi extension where possible**

Run:

```bash
node --check ~/.pi/agent/extensions/agent-tmux-state.ts 2>/dev/null || true
```

Expected: TypeScript may not be accepted by `node --check`; if it is not, at least inspect the changed block and run any local Pi extension test command available in `~/.pi/agent/package.json`.

- [ ] **Step 6: Commit external repo changes separately**

Run:

```bash
git -C ~/.claude add hooks/tmux-agent-state.sh
git -C ~/.claude commit -m "feat: write tmux agent pane state"

git -C ~/.pi add agent/extensions/agent-tmux-state.ts
git -C ~/.pi commit -m "feat: mark pi tmux agent state"
```

If either external repo has unrelated existing changes, do not commit them; report and ask before proceeding.

---

### Task 5: End-to-end verification and final docs/status

**Files:**
- Modify if needed: `docs/superpowers/specs/2026-06-28-agent-sesh-state-design.md`
- Modify if needed: `docs/superpowers/plans/2026-06-28-agent-sesh-state.md`

**Interfaces:**
- Consumes all tasks above.
- Produces final verified branch state ready for review.

- [ ] **Step 1: Run focused tests**

Run:

```bash
bash tests/chezmoi/test-agent-tmux-state-scripts.sh
```

Expected: PASS with no output.

- [ ] **Step 2: Run render and syntax checks**

Run:

```bash
chezmoi execute-template --source . --file dot_config/tmux/tmux.conf.tmpl >/tmp/agent-sesh-tmux.conf
chezmoi execute-template --source . --file dot_config/sesh/scripts/executable_picker.sh.tmpl >/tmp/agent-sesh-picker.sh
bash -n /tmp/agent-sesh-picker.sh
for script in dot_config/sesh/scripts/executable_agent-state.sh.tmpl dot_config/sesh/scripts/executable_preview-with-agent-state.sh.tmpl dot_config/sesh/scripts/executable_list-agent-sessions.sh.tmpl dot_config/sesh/scripts/executable_agent-next.sh.tmpl; do
  bash -n "$script"
done
```

Expected: all commands PASS.

- [ ] **Step 3: Run changed-file audit if available**

Run:

```bash
if command -v fallow >/dev/null 2>&1; then
  fallow audit --changed-since main
else
  echo 'fallow not installed; skipped'
fi
```

Expected: no blocking findings, or report findings and fix them.

- [ ] **Step 4: Inspect diffs**

Run:

```bash
git diff --stat main...HEAD
git diff main...HEAD -- dot_config/sesh/scripts dot_config/tmux/tmux.conf.tmpl tests/chezmoi docs/superpowers
```

Expected: changes are limited to the planned files.

- [ ] **Step 5: Commit any final plan/spec status updates**

If the implementation required plan/spec clarification, commit it:

```bash
git add docs/superpowers/specs/2026-06-28-agent-sesh-state-design.md docs/superpowers/plans/2026-06-28-agent-sesh-state.md
git commit -m "docs: update agent sesh state notes"
```

Skip this commit if there are no doc changes after Task 3.
