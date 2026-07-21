# Herdr–Worktrunk Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install and configure `devashish2203/herdr-worktrunk` as the Herdr-facing Worktrunk workflow while retaining tmux hooks as successful no-ops outside tmux.

**Architecture:** Extend the existing chezmoi-owned Herdr plugin reconciliation with a pinned plugin and plugin-owned `config.toml`. Bind the plugin's actions in Herdr; keep Worktrunk authoritative and make its existing tmux hook guards explicit rather than adding Herdr hooks.

**Tech Stack:** chezmoi templates, YAML, TOML, POSIX shell/Bash, Python `tomllib`, Herdr plugin API v1, Worktrunk ≥0.60.

## Global Constraints

- Pin `devashish2203/herdr-worktrunk` to reviewed commit `e9131c0b576fd68635194c758c9691dbfb778b61`.
- Configure `open_mode = "workspace"`.
- Worktrunk remains the sole owner of Git worktree creation, switching, and removal.
- Retain tmux behavior; outside tmux both Worktrunk hooks must do nothing and return success.
- Do not install `@yassimba/pi-herdr-worktree`, `mattarau/wt-herdr`, or add Herdr-specific Worktrunk hooks.
- The absent `dot_config/nvim/after/plugin/herdr_nav.lua` is a pre-existing baseline issue and remains out of scope.

---

### Task 1: Declarative plugin installation and workspace-mode configuration

**Files:**
- Modify: `.chezmoidata/herdr.yml`
- Modify: `.chezmoiscripts/run_onchange_after_install-herdr-plugins.sh.tmpl`
- Create: `tests/chezmoi/test-herdr-worktrunk.sh`

**Interfaces:**
- Consumes: `.herdr.plugins[]` entries containing `id`, `source`, `ref`, and optional `config` data.
- Produces: installed Herdr plugin `worktrunk` and `$HERDR_PLUGIN_CONFIG_DIR/config.toml` containing `open_mode = "workspace"`.

- [ ] **Step 1: Write the focused failing reconciliation test**

Create `tests/chezmoi/test-herdr-worktrunk.sh`. Render the reconciler into a temporary directory and use a fake `herdr` executable that logs calls and returns a temporary path for `plugin config-dir worktrunk`:

```bash
#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

rendered="$tmpdir/reconcile.sh"
chezmoi execute-template --source "$repo_root" \
  <"$repo_root/.chezmoiscripts/run_onchange_after_install-herdr-plugins.sh.tmpl" >"$rendered"
chmod +x "$rendered"
mkdir -p "$tmpdir/bin" "$tmpdir/home" "$tmpdir/state" "$tmpdir/plugin-config"
cat >"$tmpdir/bin/herdr" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >>"$HERDR_TEST_LOG"
if [ "$*" = "plugin config-dir worktrunk" ]; then
  printf '%s\n' "$HERDR_TEST_CONFIG_DIR"
fi
SH
chmod +x "$tmpdir/bin/herdr"
HERDR_TEST_LOG="$tmpdir/herdr.log" \
HERDR_TEST_CONFIG_DIR="$tmpdir/plugin-config" \
HOME="$tmpdir/home" XDG_STATE_HOME="$tmpdir/state" \
PATH="$tmpdir/bin:/usr/bin:/bin" "$rendered"

ref=e9131c0b576fd68635194c758c9691dbfb778b61
grep -Fxq "plugin install devashish2203/herdr-worktrunk --ref $ref --yes" "$tmpdir/herdr.log"
grep -Fxq 'plugin config-dir worktrunk' "$tmpdir/herdr.log"
grep -Fxq 'open_mode = "workspace"' "$tmpdir/plugin-config/config.toml"
echo "Herdr Worktrunk reconciliation ok"
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```bash
bash tests/chezmoi/test-herdr-worktrunk.sh
```

Expected: FAIL because the plugin install call and managed config do not exist.

- [ ] **Step 3: Add the pinned desired-state entry**

Append to `.chezmoidata/herdr.yml`:

```yaml
    - id: worktrunk
      source: devashish2203/herdr-worktrunk
      ref: e9131c0b576fd68635194c758c9691dbfb778b61
      config:
        open_mode: workspace
```

- [ ] **Step 4: Render plugin-owned configuration after installation**

Keep the existing `id|source|ref` desired-state and ledger format unchanged. After the installation loop, render a separate template block only for entries with `config.open_mode`:

```sh
config_dir=$(herdr plugin config-dir "worktrunk")
mkdir -p "$config_dir"
printf 'open_mode = "%s"\n' "workspace" >"$config_dir/config.toml"
```

Generate the plugin ID and mode from `.herdr.plugins` rather than hard-coding the values in the template source. This preserves existing ledger compatibility and leaves manually installed plugins untouched.

- [ ] **Step 5: Run the focused test**

Run:

```bash
bash tests/chezmoi/test-herdr-worktrunk.sh
```

Expected: `Herdr Worktrunk reconciliation ok`.

- [ ] **Step 6: Commit the plugin reconciliation**

```bash
git add .chezmoidata/herdr.yml \
  .chezmoiscripts/run_onchange_after_install-herdr-plugins.sh.tmpl \
  tests/chezmoi/test-herdr-worktrunk.sh
git commit -m "feat(herdr): install Worktrunk plugin"
```

---

### Task 2: Herdr action bindings

**Files:**
- Modify: `dot_config/herdr/config.toml.tmpl`
- Modify: `tests/chezmoi/test-herdr-config.sh`

**Interfaces:**
- Consumes: plugin actions `worktrunk.open`, `worktrunk.open-current`, and `worktrunk.remove`.
- Produces: three tmux-style Herdr keybindings.

- [ ] **Step 1: Extend the rendered-config assertions**

In `tests/chezmoi/test-herdr-config.sh`, change `assert len(commands) == 8` to `11`, retain navigation as `commands[4:8]`, and assert:

```python
assert commands[8:] == [
    {
        "key": "prefix+shift+g",
        "type": "plugin_action",
        "command": "worktrunk.open",
        "description": "worktree switch/create from default branch",
    },
    {
        "key": "prefix+shift+c",
        "type": "plugin_action",
        "command": "worktrunk.open-current",
        "description": "worktree switch/create from current branch",
    },
    {
        "key": "prefix+shift+d",
        "type": "plugin_action",
        "command": "worktrunk.remove",
        "description": "worktree remove",
    },
]
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```bash
bash tests/chezmoi/test-herdr-config.sh
```

Expected: FAIL because only eight commands are rendered.

- [ ] **Step 3: Add the three plugin-action commands**

Append three `[[keys.command]]` tables to `dot_config/herdr/config.toml.tmpl` matching the exact keys, commands, and descriptions asserted above.

- [ ] **Step 4: Run the test and verify it passes**

Run:

```bash
bash tests/chezmoi/test-herdr-config.sh
```

Expected: `HerdR config template ok`.

- [ ] **Step 5: Commit the bindings**

```bash
git add dot_config/herdr/config.toml.tmpl tests/chezmoi/test-herdr-config.sh
git commit -m "feat(herdr): bind Worktrunk actions"
```

---

### Task 3: Preserve tmux hooks with successful non-tmux guards

**Files:**
- Modify: `dot_config/worktrunk/config.toml`
- Create: `tests/chezmoi/test-worktrunk-herdr-compat.sh`

**Interfaces:**
- Consumes: `TMUX` and `TMUX_PANE` environment variables supplied by tmux.
- Produces: unchanged tmux operations when present and exit status zero when absent.

- [ ] **Step 1: Write the failing hook behavior test**

Create a test that parses both TOML hook commands with Python, runs them with `TMUX` and `TMUX_PANE` unset, and verifies the tmux commands remain present:

```bash
#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
config="$repo_root/dot_config/worktrunk/config.toml"
python3 - "$config" <<'PY'
import os, subprocess, sys, tomllib
from pathlib import Path
config = tomllib.loads(Path(sys.argv[1]).read_text())
commands = [config["post-switch"]["tmux-rename"], config["post-start"]["tmux-split"]]
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
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```bash
bash tests/chezmoi/test-worktrunk-herdr-compat.sh
```

Expected: FAIL with return code `1` from at least one absent-variable guard.

- [ ] **Step 3: Replace `&&` guards with explicit conditionals**

Use these command shapes in `dot_config/worktrunk/config.toml`:

```toml
[post-switch]
tmux-rename = 'if [ -n "$TMUX" ]; then tmux rename-window -t "$TMUX_PANE" {{ branch | sanitize }}; fi'

[post-start]
tmux-split = '''
if [ -n "$TMUX_PANE" ]; then
  PANE_COUNT=$(tmux list-panes -t "$TMUX_PANE" -F x | wc -l | tr -d ' ')
  [ "$PANE_COUNT" -eq 2 ]
fi
'''
```

- [ ] **Step 4: Run the compatibility test**

Run:

```bash
bash tests/chezmoi/test-worktrunk-herdr-compat.sh
```

Expected: `Worktrunk tmux guards ok`.

- [ ] **Step 5: Commit the compatibility change**

```bash
git add dot_config/worktrunk/config.toml tests/chezmoi/test-worktrunk-herdr-compat.sh
git commit -m "fix(worktrunk): no-op tmux hooks outside tmux"
```

---

### Task 4: Document and verify the integrated workflow

**Files:**
- Modify: `docs/private/herdr-plugin-management.md`

**Interfaces:**
- Consumes: the installed plugin, managed workspace-mode configuration, Herdr bindings, and retained tmux hooks.
- Produces: durable operator and security-review documentation.

- [ ] **Step 1: Document the reviewed plugin**

Add a `Current plugin: worktrunk` section covering:

```text
Source: devashish2203/herdr-worktrunk
Plugin ID: worktrunk
Pinned commit: e9131c0b576fd68635194c758c9691dbfb778b61
Manifest version reviewed: 0.1.0
Requirements: Herdr >=0.7.0, Worktrunk >=0.60.0, Bash, fzf, jq
Actions: open, open-current, remove
Panes: picker-default, picker-current, remover
Build commands/events/link handlers: none
Managed config: open_mode = "workspace"
```

Explain that its Bash entrypoints invoke `wt`, `git`, `fzf`, `jq`, and Herdr CLI operations; Worktrunk remains authoritative; and tmux hooks remain intentionally active only in tmux.

- [ ] **Step 2: Run focused verification**

Run:

```bash
bash tests/chezmoi/test-herdr-worktrunk.sh
bash tests/chezmoi/test-herdr-config.sh
bash tests/chezmoi/test-worktrunk-herdr-compat.sh
```

Expected: all three print their success messages.

Run the known baseline test separately:

```bash
bash tests/chezmoi/test-herdr-plugins.sh
```

Expected: the pre-existing failure `missing Neovim Herdr navigation bridge`; confirm no new failure precedes it.

- [ ] **Step 3: Perform repository validation**

Run:

```bash
git diff --check main...HEAD
chezmoi diff --source "$PWD"
fallow audit --changed-since main
```

Expected: no whitespace errors; chezmoi shows only intended Worktrunk/Herdr changes; Fallow reports no new actionable finding.

- [ ] **Step 4: Commit documentation**

```bash
git add docs/private/herdr-plugin-management.md
git commit -m "docs(herdr): document Worktrunk plugin"
```

- [ ] **Step 5: Review final history and diff**

Run:

```bash
git status --short
git log --oneline main..HEAD
git diff --stat main...HEAD
```

Expected: clean worktree, four implementation commits plus the design/plan commits, and changes limited to the files named in this plan.
