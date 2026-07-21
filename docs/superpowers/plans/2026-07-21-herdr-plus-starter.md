# Herdr Plus Starter Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Declaratively install `cloudmanic/herdr-plus`, bind its Projects picker to Herdr `prefix+K`, and seed role-aware starter projects from the explicit sesh sessions.

**Architecture:** Extend the existing Herdr plugin data/reconciler rather than adding another installer. Manage one Herdr Plus project TOML per explicit session under the plugin-owned config tree, with `.chezmoiignore` gating role-specific files; sesh remains independent and unchanged.

**Tech Stack:** chezmoi YAML/TOML/Go templates, POSIX shell/Bash tests, Python 3 `tomllib`, Herdr plugin actions.

## Global Constraints

- Keep sesh and tmux configuration unchanged.
- Pin `cloudmanic/herdr-plus` to commit `f32b0825f12543c1d03e54fb10d1741c40d66cdc` (manifest version `0.1.16`, Herdr minimum `0.7.0`).
- Seed explicit sessions only; do not implement wildcard discovery, zoxide integration, Quick Actions, worktree layouts, or multi-pane layouts.
- Manage starter files under `~/.config/herdr/plugins/config/cloudmanic.herdr-plus/projects/` without making the directory exact or deleting user-created files.
- Preserve existing sesh paths and startup commands.
- Work in `/Users/brendan/.local/share/chezmoi.feat-herdr-plus-starter` on branch `feat/herdr-plus-starter`.
- The pre-existing plugin test has one stale Neovim bridge assertion removed by commit `3cf3a11`; correct that assertion as part of Task 1.

---

## File Structure

**Modified files**

- `.chezmoidata/herdr.yml` — desired Herdr plugin IDs, sources, and pinned refs.
- `.chezmoiignore` — excludes personal/work/homelab starter project files when their role is inactive.
- `dot_config/herdr/config.toml.tmpl` — Herdr key binding for the Projects plugin action.
- `tests/chezmoi/test-herdr-plugins.sh` — plugin reconciliation and state-ledger coverage.
- `tests/chezmoi/test-herdr-config.sh` — parsed Herdr key command coverage and role-ignore assertions.

**Created files**

- `dot_config/herdr/plugins/config/cloudmanic.herdr-plus/projects/base-dotfiles.toml.tmpl`
- `dot_config/herdr/plugins/config/cloudmanic.herdr-plus/projects/base-nvim-config.toml.tmpl`
- `dot_config/herdr/plugins/config/cloudmanic.herdr-plus/projects/base-tmux-config.toml.tmpl`
- `dot_config/herdr/plugins/config/cloudmanic.herdr-plus/projects/personal-hass-config.toml.tmpl`
- `dot_config/herdr/plugins/config/cloudmanic.herdr-plus/projects/personal-homelab.toml.tmpl`
- `dot_config/herdr/plugins/config/cloudmanic.herdr-plus/projects/personal-pi-config.toml.tmpl`
- `dot_config/herdr/plugins/config/cloudmanic.herdr-plus/projects/personal-claude-config.toml.tmpl`
- `dot_config/herdr/plugins/config/cloudmanic.herdr-plus/projects/personal-hermes-config.toml.tmpl`
- `dot_config/herdr/plugins/config/cloudmanic.herdr-plus/projects/personal-hermes-folder.toml.tmpl`
- `dot_config/herdr/plugins/config/cloudmanic.herdr-plus/projects/work-steady-servers.toml.tmpl`
- `dot_config/herdr/plugins/config/cloudmanic.herdr-plus/projects/homelab-home.toml.tmpl`
- `dot_config/herdr/plugins/config/cloudmanic.herdr-plus/projects/homelab-docker.toml.tmpl`
- `dot_config/herdr/plugins/config/cloudmanic.herdr-plus/projects/homelab-opt.toml.tmpl`
- `tests/chezmoi/test-herdr-plus-projects.sh` — rendering, TOML schema, values, and role-gating coverage.

---

### Task 1: Add Herdr Plus to plugin reconciliation

**Files:**
- Modify: `.chezmoidata/herdr.yml`
- Modify: `tests/chezmoi/test-herdr-plugins.sh`

**Interfaces:**
- Consumes: Existing `.herdr.plugins[]` records with `id`, `source`, and `ref`.
- Produces: Desired record `cloudmanic.herdr-plus|cloudmanic/herdr-plus|f32b0825f12543c1d03e54fb10d1741c40d66cdc` for the unchanged reconciler.

- [ ] **Step 1: Update the plugin test first**

Remove the obsolete `nvim_bridge` variable, file existence assertion, and final three `grep` assertions. Add the Herdr Plus expectations after the existing navigation-plugin assertions:

```bash
nav_ref='53e318c772c4d3b7fbd904ac43bcf3e5b5d8b244'
plus_ref='f32b0825f12543c1d03e54fb10d1741c40d66cdc'
grep -Fxq "plugin install paulbkim-dev/vim-herdr-navigation --ref $nav_ref --yes" "$tmpdir/herdr.log"
grep -Fxq "plugin install cloudmanic/herdr-plus --ref $plus_ref --yes" "$tmpdir/herdr.log"
grep -Fxq 'plugin uninstall old-plugin' "$tmpdir/herdr.log"
grep -Fxq "vim-herdr-navigation|paulbkim-dev/vim-herdr-navigation|$nav_ref" \
  "$tmpdir/state/chezmoi/herdr-plugins.txt"
grep -Fxq "cloudmanic.herdr-plus|cloudmanic/herdr-plus|$plus_ref" \
  "$tmpdir/state/chezmoi/herdr-plugins.txt"
```

Keep the stale-plugin absence check and final success message.

- [ ] **Step 2: Run the test and verify the new plugin expectation fails**

Run:

```bash
cd /Users/brendan/.local/share/chezmoi.feat-herdr-plus-starter
bash tests/chezmoi/test-herdr-plugins.sh
```

Expected: FAIL because `herdr.log` does not contain the `cloudmanic/herdr-plus` install command.

- [ ] **Step 3: Add the pinned plugin record**

Change `.chezmoidata/herdr.yml` to:

```yaml
herdr:
  plugins:
    - id: vim-herdr-navigation
      source: paulbkim-dev/vim-herdr-navigation
      ref: 53e318c772c4d3b7fbd904ac43bcf3e5b5d8b244
    - id: cloudmanic.herdr-plus
      source: cloudmanic/herdr-plus
      ref: f32b0825f12543c1d03e54fb10d1741c40d66cdc
```

- [ ] **Step 4: Run the plugin test**

Run:

```bash
bash tests/chezmoi/test-herdr-plugins.sh
```

Expected: `Herdr plugin reconciliation ok` and exit 0.

- [ ] **Step 5: Commit the plugin change**

```bash
git add .chezmoidata/herdr.yml tests/chezmoi/test-herdr-plugins.sh
git commit -m "feat(herdr): install herdr-plus declaratively"
```

---

### Task 2: Bind the Herdr Plus Projects picker

**Files:**
- Modify: `dot_config/herdr/config.toml.tmpl`
- Modify: `tests/chezmoi/test-herdr-config.sh`

**Interfaces:**
- Consumes: Herdr Plus action ID `cloudmanic.herdr-plus.projects`.
- Produces: One Herdr `keys.command` record on `prefix+K`.

- [ ] **Step 1: Add a failing parsed-config assertion**

In `tests/chezmoi/test-herdr-config.sh`, change `assert len(commands) == 8` to `assert len(commands) == 9`, keep navigation commands limited to `commands[4:8]`, and add:

```python
assert commands[8] == {
    "key": "prefix+K",
    "type": "plugin_action",
    "command": "cloudmanic.herdr-plus.projects",
    "description": "herdr-plus: projects",
}
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```bash
bash tests/chezmoi/test-herdr-config.sh
```

Expected: FAIL at `assert len(commands) == 9` because the rendered config has eight commands.

- [ ] **Step 3: Add the Projects key binding**

After the four `vim-herdr-navigation` command blocks in `dot_config/herdr/config.toml.tmpl`, add:

```toml
[[keys.command]]
key = "prefix+K"
type = "plugin_action"
command = "cloudmanic.herdr-plus.projects"
description = "herdr-plus: projects"
```

- [ ] **Step 4: Run the config test**

Run:

```bash
bash tests/chezmoi/test-herdr-config.sh
```

Expected: `HerdR config template ok` and exit 0.

- [ ] **Step 5: Commit the binding**

```bash
git add dot_config/herdr/config.toml.tmpl tests/chezmoi/test-herdr-config.sh
git commit -m "feat(herdr): bind herdr-plus projects"
```

---

### Task 3: Add base starter projects

**Files:**
- Create: three `base-*.toml.tmpl` files listed in File Structure.
- Create: `tests/chezmoi/test-herdr-plus-projects.sh`

**Interfaces:**
- Consumes: chezmoi data `.chezmoi_dir`; Herdr Plus project fields `name`, `working_dir`, and `[[tabs]]` with optional `command`.
- Produces: Three unconditional project TOML files under the plugin config tree.

- [ ] **Step 1: Write the base-project rendering test**

Create `tests/chezmoi/test-herdr-plus-projects.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
projects="$repo_root/dot_config/herdr/plugins/config/cloudmanic.herdr-plus/projects"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

render_project() {
  local source=$1 output=$2 override=${3:-'{"chezmoi_dir":".local/share/chezmoi","code_dir":"Code"}'}
  chezmoi execute-template --source "$repo_root" --override-data "$override" \
    <"$projects/$source" >"$output"
}

for file in base-dotfiles base-nvim-config base-tmux-config; do
  [[ -f "$projects/$file.toml.tmpl" ]] || {
    echo "missing Herdr Plus project: $file" >&2
    exit 1
  }
  render_project "$file.toml.tmpl" "$tmpdir/$file.toml"
done

python3 - "$tmpdir" <<'PY'
import sys
import tomllib
from pathlib import Path

root = Path(sys.argv[1])
def load(name):
    return tomllib.loads((root / f"{name}.toml").read_text())

assert load("base-dotfiles") == {
    "name": "dotfiles",
    "working_dir": "~/.local/share/chezmoi",
    "tabs": [{"name": "shell"}],
}
assert load("base-nvim-config") == {
    "name": "nvim-config",
    "working_dir": "~/.config/nvim",
    "tabs": [{"name": "shell"}],
}
assert load("base-tmux-config") == {
    "name": "tmux-config",
    "working_dir": "~/.local/share/chezmoi/dot_config/tmux",
    "tabs": [{"name": "editor", "command": "nvim tmux.conf.tmpl"}],
}
PY

echo "Herdr Plus projects ok"
```

- [ ] **Step 2: Run the test and verify missing files fail**

Run:

```bash
bash tests/chezmoi/test-herdr-plus-projects.sh
```

Expected: FAIL with `missing Herdr Plus project: base-dotfiles`.

- [ ] **Step 3: Create the base templates**

`base-dotfiles.toml.tmpl`:

```toml
name = "dotfiles"
working_dir = "~/{{ .chezmoi_dir }}"

[[tabs]]
name = "shell"
```

`base-nvim-config.toml.tmpl`:

```toml
name = "nvim-config"
working_dir = "~/.config/nvim"

[[tabs]]
name = "shell"
```

`base-tmux-config.toml.tmpl`:

```toml
name = "tmux-config"
working_dir = "~/{{ .chezmoi_dir }}/dot_config/tmux"

[[tabs]]
name = "editor"
command = "nvim tmux.conf.tmpl"
```

- [ ] **Step 4: Run the base-project test**

Run:

```bash
bash tests/chezmoi/test-herdr-plus-projects.sh
```

Expected: `Herdr Plus projects ok` and exit 0.

- [ ] **Step 5: Commit base projects**

```bash
git add dot_config/herdr/plugins/config/cloudmanic.herdr-plus/projects/base-*.toml.tmpl \
  tests/chezmoi/test-herdr-plus-projects.sh
git commit -m "feat(herdr): seed base herdr-plus projects"
```

---

### Task 4: Add role-aware starter projects

**Files:**
- Create: six `personal-*.toml.tmpl`, one `work-*.toml.tmpl`, and three `homelab-*.toml.tmpl` files listed in File Structure.
- Modify: `.chezmoiignore`
- Modify: `tests/chezmoi/test-herdr-plus-projects.sh`

**Interfaces:**
- Consumes: `.personal`, `.work`, `.homelab`, `.code_dir`, `.chezmoi.os`, and chezmoi `stat`.
- Produces: Role-gated Herdr Plus project targets matching explicit sesh session paths and commands.

- [ ] **Step 1: Extend the test with role-project assertions**

Before the final success message in `test-herdr-plus-projects.sh`, render all role templates with `code_dir` set to `Code`, parse them with `tomllib`, and assert these exact records:

```python
expected = {
    "personal-hass-config": ("hass-config", "~/Code/_homelab/home-assistant-config/", "claude --agent homelab:hass-config --dangerously-allow-permissions"),
    "personal-homelab": ("homelab", "~/Code/_homelab/ansible-playbooks/homelab", "ansible-playbook update-servers.yml"),
    "personal-pi-config": ("pi-config", "~/.pi", "pi"),
    "personal-claude-config": ("claude-config", "~/.claude", "claude"),
    "personal-hermes-config": ("hermes-config", "~/Code/_homelab/local-stdy01-docker", None),
    "personal-hermes-folder": ("hermes-folder", "~/Documents/Sync/hermes-agent/", None),
    "work-steady-servers": ("steady-servers", "~/Code/_work/ansible-playbooks/steady-servers", "tailscale switch steadydigital.co && tailscale up && ansible-playbook update-servers.yml && tailscale down"),
    "homelab-home": ("home", "~", None),
    "homelab-opt": ("opt", "/opt", None),
}
```

For each record, assert `name`, `working_dir`, one tab, and command presence/absence. Render `homelab-docker.toml.tmpl` normally and assert its `working_dir` is one of `{"/opt/docker", "~/docker/compose"}` because it deliberately depends on the rendering host's `/opt/docker/compose` existence.

Also render `.chezmoiignore` three times with explicit role booleans and assert:

```bash
# no roles: all three patterns present
.config/herdr/plugins/config/cloudmanic.herdr-plus/projects/personal-*.toml
.config/herdr/plugins/config/cloudmanic.herdr-plus/projects/work-*.toml
.config/herdr/plugins/config/cloudmanic.herdr-plus/projects/homelab-*.toml

# all roles true: none of those patterns present
```

- [ ] **Step 2: Run the test and verify it fails on missing role projects**

Run:

```bash
bash tests/chezmoi/test-herdr-plus-projects.sh
```

Expected: FAIL naming the first missing `personal-*.toml.tmpl` file.

- [ ] **Step 3: Create personal project templates**

Create six TOML files with top-level `name` and `working_dir` fields followed by one `[[tabs]]` table. Include the tab's `command` field only where the table below supplies a command. Use these exact values:

| File | name | working_dir | tab | command |
|---|---|---|---|---|
| `personal-hass-config.toml.tmpl` | `hass-config` | `~/{{ .code_dir }}/_homelab/home-assistant-config/` | `agent` | `claude --agent homelab:hass-config --dangerously-allow-permissions` |
| `personal-homelab.toml.tmpl` | `homelab` | `~/{{ .code_dir }}/_homelab/ansible-playbooks/homelab` | `ansible` | `ansible-playbook update-servers.yml` |
| `personal-pi-config.toml.tmpl` | `pi-config` | `~/.pi` | `agent` | `pi` |
| `personal-claude-config.toml.tmpl` | `claude-config` | `~/.claude` | `agent` | `claude` |
| `personal-hermes-config.toml.tmpl` | `hermes-config` | `~/{{ .code_dir }}/_homelab/local-stdy01-docker` | `shell` | omit |
| `personal-hermes-folder.toml.tmpl` | `hermes-folder` | `~/Documents/Sync/hermes-agent/` | `shell` | omit |

- [ ] **Step 4: Create work and homelab project templates**

Use the same shape and these values:

| File | name | working_dir | tab | command |
|---|---|---|---|---|
| `work-steady-servers.toml.tmpl` | `steady-servers` | `~/{{ .code_dir }}/_work/ansible-playbooks/steady-servers` | `ansible` | `tailscale switch steadydigital.co && tailscale up && ansible-playbook update-servers.yml && tailscale down` |
| `homelab-home.toml.tmpl` | `home` | `~` | `shell` | omit |
| `homelab-opt.toml.tmpl` | `opt` | `/opt` | `shell` | omit |

Create `homelab-docker.toml.tmpl` with the sesh path condition:

```toml
name = "docker"
{{ if stat "/opt/docker/compose" -}}
working_dir = "/opt/docker"
{{ else -}}
working_dir = "~/docker/compose"
{{ end }}

[[tabs]]
name = "shell"
```

- [ ] **Step 5: Gate role-specific targets in `.chezmoiignore`**

Immediately after the existing sesh role exclusions, add:

```text
{{- if not .personal }}
.config/herdr/plugins/config/cloudmanic.herdr-plus/projects/personal-*.toml
{{- end }}
{{- if not .work }}
.config/herdr/plugins/config/cloudmanic.herdr-plus/projects/work-*.toml
{{- end }}
{{- if not .homelab }}
.config/herdr/plugins/config/cloudmanic.herdr-plus/projects/homelab-*.toml
{{- end }}
```

- [ ] **Step 6: Run project and existing role tests**

Run:

```bash
bash tests/chezmoi/test-herdr-plus-projects.sh
bash tests/chezmoi/test-bitwarden-role-gating.sh
```

Expected: `Herdr Plus projects ok`; the existing role-gating test also exits 0.

- [ ] **Step 7: Commit role-aware projects**

```bash
git add .chezmoiignore \
  dot_config/herdr/plugins/config/cloudmanic.herdr-plus/projects/personal-*.toml.tmpl \
  dot_config/herdr/plugins/config/cloudmanic.herdr-plus/projects/work-*.toml.tmpl \
  dot_config/herdr/plugins/config/cloudmanic.herdr-plus/projects/homelab-*.toml.tmpl \
  tests/chezmoi/test-herdr-plus-projects.sh
git commit -m "feat(herdr): add role-aware herdr-plus projects"
```

---

### Task 5: Verify the complete change

**Files:**
- Verify all files changed since `main`; modify only if a verification failure identifies a defect.

**Interfaces:**
- Consumes: Deliverables from Tasks 1–4.
- Produces: Evidence that templates render, tests pass, static checks pass, and sesh/tmux remain unchanged.

- [ ] **Step 1: Run all focused tests**

```bash
bash tests/chezmoi/test-herdr-plugins.sh
bash tests/chezmoi/test-herdr-config.sh
bash tests/chezmoi/test-herdr-plus-projects.sh
bash tests/chezmoi/test-bitwarden-role-gating.sh
```

Expected: all commands exit 0 and print their success messages.

- [ ] **Step 2: Run shell syntax checks**

```bash
bash -n tests/chezmoi/test-herdr-plugins.sh \
  tests/chezmoi/test-herdr-config.sh \
  tests/chezmoi/test-herdr-plus-projects.sh
```

Expected: exit 0 with no output.

- [ ] **Step 3: Run changed-file static analysis**

```bash
fallow audit --changed-since main
```

Expected: exit 0 with no blocking findings. Fix only findings introduced by this branch, rerun their focused test, and commit with a Conventional Commit if changes are needed.

- [ ] **Step 4: Inspect repository diff and scope**

```bash
git diff --check main...HEAD
git diff --stat main...HEAD
git diff --name-only main...HEAD -- dot_config/sesh dot_config/tmux
```

Expected: `git diff --check` exits 0; the final command prints nothing, proving sesh/tmux were unchanged.

- [ ] **Step 5: Confirm worktree status**

```bash
git status --short
git log --oneline --decorate main..HEAD
```

Expected: clean status and the design plus implementation commits listed.
