# Remove sesh Agent Session Listing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove every agent-session listing path from sesh on Unix and Windows while preserving tmux agent navigation, state hooks, and bell/status behavior.

**Architecture:** Make sesh pickers platform-neutral with respect to agents: both use only native sesh listing, preview, and connection behavior. Retain the independent `agent-state.sh` and `agent-next.sh` tmux integration, and strengthen regression assertions that the preserved tmux binding and bell settings remain present.

**Tech Stack:** Bash, PowerShell, fzf, sesh, tmux, chezmoi templates.

## Global Constraints

- No sesh picker may reference agent listing, agent selection dispatch, or agent-aware preview wrappers.
- `agent-state.sh`, `agent-next.sh`, tmux `prefix+A`, and tmux bell/status settings must remain unchanged.
- Normal sesh filters, preview, connect, and kill behavior must remain unchanged across Unix and Windows.

---

### Task 1: Remove sesh agent-list integration and lock preservation behavior

**Files:**
- Delete: `dot_config/sesh/scripts/executable_list-agent-sessions.sh.tmpl`
- Delete: `dot_config/sesh/scripts/executable_preview-with-agent-state.sh.tmpl`
- Modify: `dot_config/sesh/scripts/executable_picker.sh.tmpl:24-47`
- Modify: `tests/chezmoi/test-agent-tmux-state-scripts.sh:84-115`
- Verify unchanged: `dot_config/sesh/scripts/executable_picker.ps1.tmpl`
- Verify unchanged: `dot_config/sesh/scripts/executable_agent-state.sh.tmpl`
- Verify unchanged: `dot_config/sesh/scripts/executable_agent-next.sh.tmpl`
- Verify unchanged: `dot_config/tmux/tmux.conf.tmpl`

**Interfaces:**
- Consumes: `sesh list --icons`, `sesh preview {}`, `sesh connect "$selected"`, and tmux’s existing `agent-next.sh` binding.
- Produces: Unix and Windows sesh pickers with no agent-list integration; preserved independent tmux agent navigation and bell behavior.

- [ ] **Step 1: Change regression assertions so the current implementation fails**

Replace the wrapper syntax loop with:

```bash
bash -n "$repo_root/dot_config/sesh/scripts/executable_agent-next.sh.tmpl"
[[ ! -e "$repo_root/dot_config/sesh/scripts/executable_list-agent-sessions.sh.tmpl" ]]
[[ ! -e "$repo_root/dot_config/sesh/scripts/executable_preview-with-agent-state.sh.tmpl" ]]
```

Delete the fake `sesh` setup and `combined_preview` assertions that execute `executable_preview-with-agent-state.sh.tmpl`.

Replace the picker assertions with:

```bash
picker="$repo_root/dot_config/sesh/scripts/executable_picker.sh.tmpl"
windows_picker="$repo_root/dot_config/sesh/scripts/executable_picker.ps1.tmpl"
tmux_conf="$repo_root/dot_config/tmux/tmux.conf.tmpl"

for sesh_picker in "$picker" "$windows_picker"; do
  if grep -Eq 'list-agent-sessions|preview-with-agent-state|agent-next|agent:%|ctrl-e:change-prompt|\^e agents' "$sesh_picker"; then
    exit 1
  fi
done

grep -Fq -- '--preview "sesh preview {}"' "$picker"
grep -q "bind-key A run-shell '~/.config/sesh/scripts/agent-next.sh'" "$tmux_conf"
grep -q '^setw -g monitor-bell on$' "$tmux_conf"
grep -q '^set -g bell-action any$' "$tmux_conf"
grep -q '^set -g visual-bell on$' "$tmux_conf"
grep -q '^set -g window-status-bell-style' "$tmux_conf"
```

- [ ] **Step 2: Run the focused test and verify it fails for the existing Unix picker**

Run:

```bash
bash tests/chezmoi/test-agent-tmux-state-scripts.sh
```

Expected: non-zero exit because `executable_picker.sh.tmpl` still contains agent-specific paths and does not yet use direct `sesh preview {}`.

- [ ] **Step 3: Remove the agent list and agent-aware preview wrappers**

Run:

```bash
rm dot_config/sesh/scripts/executable_list-agent-sessions.sh.tmpl \
   dot_config/sesh/scripts/executable_preview-with-agent-state.sh.tmpl
```

- [ ] **Step 4: Simplify the Unix picker**

Change the fzf header to:

```bash
    --header '  ^a all ^t tmux ^g configs ^x zoxide ^d tmux kill ^f find ' \
```

Delete the Ctrl-E binding. Replace the preview command with:

```bash
    --preview "sesh preview {}"
```

Replace the selection dispatch with:

```bash
case "$selected" in
  "")
    exit 0
    ;;
  *)
    sesh connect "$selected"
    ;;
esac
```

- [ ] **Step 5: Run focused syntax and regression verification**

Run:

```bash
bash -n dot_config/sesh/scripts/executable_picker.sh.tmpl
bash -n dot_config/sesh/scripts/executable_agent-state.sh.tmpl
bash -n dot_config/sesh/scripts/executable_agent-next.sh.tmpl
bash tests/chezmoi/test-agent-tmux-state-scripts.sh
```

Expected: all commands exit 0.

- [ ] **Step 6: Verify all traces are gone and preserved tmux files are unchanged**

Run:

```bash
! git grep -n -E 'list-agent-sessions|preview-with-agent-state|ctrl-e:change-prompt|\^e agents' -- dot_config/sesh
git diff --quiet -- dot_config/sesh/scripts/executable_picker.ps1.tmpl \
  dot_config/sesh/scripts/executable_agent-state.sh.tmpl \
  dot_config/sesh/scripts/executable_agent-next.sh.tmpl \
  dot_config/tmux/tmux.conf.tmpl
git diff --check
```

Expected: both negative searches succeed, the preserved-file diff is empty, and `git diff --check` exits 0.

- [ ] **Step 7: Run changed-file static validation**

Run:

```bash
shellcheck dot_config/sesh/scripts/executable_picker.sh.tmpl \
  dot_config/sesh/scripts/executable_agent-state.sh.tmpl \
  dot_config/sesh/scripts/executable_agent-next.sh.tmpl \
  tests/chezmoi/test-agent-tmux-state-scripts.sh
fallow audit --changed-since main
```

Expected: both commands exit 0. If `fallow` does not support shell/template files, record that result and rely on shellcheck plus the focused regression test.

- [ ] **Step 8: Commit the implementation**

Run:

```bash
git add dot_config/sesh/scripts tests/chezmoi/test-agent-tmux-state-scripts.sh
git commit -m "refactor(sesh): remove agent session listing"
```

Expected: one atomic commit containing only the wrapper deletions, Unix picker simplification, and regression-test updates.
