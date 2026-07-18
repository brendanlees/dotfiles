# HerdR Tmux-Compatible Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a macOS/Linux HerdR configuration that preserves core tmux muscle memory and follows the active chezmoi theme.

**Architecture:** A single chezmoi TOML template maps native HerdR actions directly and uses four documented custom CLI commands for tmux-style pane resizing. The existing `theme` command remains the source-of-truth workflow: chezmoi renders the active palette, then the script asks the default running HerdR server to reload its config.

**Tech Stack:** chezmoi Go templates, TOML, Bash, Python 3 `tomllib`, HerdR CLI/configuration.

## Global Constraints

- Manage the HerdR config on macOS and Linux only; Windows must ignore `.config/herdr`.
- Keep `ctrl+b` as the prefix.
- `prefix+h/j/k/l` must resize panes by `0.05`, not focus panes.
- Do not reproduce TPM plugins, `vim-tmux-navigator`, sesh, resurrection, URL helpers, or tab-reorder helpers.
- Do not add a HerdR plugin, socket client, package dependency, or `apps.herdr` theme registry key.
- Theme colors must come directly from `(index .themes .theme).palette`.
- Theme reload errors must warn without aborting other application reloads.
- The initial live reload targets only the default HerdR session.

---

### Task 1: Add the rendered HerdR configuration

**Files:**
- Create: `dot_config/herdr/config.toml.tmpl`
- Create: `tests/chezmoi/test-herdr-config.sh`
- Modify: `.chezmoiignore`

**Interfaces:**
- Consumes: `.themes`, `.theme`, and each selected theme's `palette` object from chezmoi data.
- Produces: `~/.config/herdr/config.toml` on macOS/Linux with native key actions plus four `[[keys.command]]` resize bindings.

- [ ] **Step 1: Write the failing template test**

Create `tests/chezmoi/test-herdr-config.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
template="$repo_root/dot_config/herdr/config.toml.tmpl"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

if [[ ! -f "$template" ]]; then
  echo "missing HerdR config template: $template" >&2
  exit 1
fi

rendered="$tmpdir/config.toml"
data_file="$tmpdir/data.json"
chezmoi data --source "$repo_root" --format json >"$data_file"
chezmoi execute-template \
  --source "$repo_root" \
  --override-data '{"theme":"guts"}' \
  <"$template" >"$rendered"

python3 - "$data_file" "$rendered" <<'PY'
import json
import sys
import tomllib
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text())
doc = tomllib.loads(Path(sys.argv[2]).read_text())
palette = data["themes"]["guts"]["palette"]

assert doc["terminal"] == {
    "default_shell": "zsh",
    "shell_mode": "auto",
    "new_cwd": "follow",
}

keys = doc["keys"]
assert keys["prefix"] == "ctrl+b"
assert keys["detach"] == "prefix+d"
assert keys["reload_config"] == "prefix+r"
assert keys["new_tab"] == "prefix+c"
assert keys["rename_tab"] == "prefix+comma"
assert keys["previous_tab"] == ["prefix+p", "ctrl+shift+h"]
assert keys["next_tab"] == ["prefix+n", "ctrl+shift+l"]
assert keys["switch_tab"] == "prefix+1..9"
assert keys["close_tab"] == "prefix+ampersand"
assert keys["copy_mode"] == "prefix+["
assert keys["split_vertical"] == "prefix+percent"
assert keys["split_horizontal"] == "prefix+double_quote"
assert keys["close_pane"] == "prefix+x"
assert keys["zoom"] == ["prefix+z", "ctrl+f"]
assert keys["resize_mode"] == ""
for field in (
    "focus_pane_left",
    "focus_pane_down",
    "focus_pane_up",
    "focus_pane_right",
):
    assert keys[field] == ""

commands = keys["command"]
assert len(commands) == 4
for command, direction, key in zip(
    commands,
    ("left", "down", "up", "right"),
    ("prefix+h", "prefix+j", "prefix+k", "prefix+l"),
    strict=True,
):
    assert command["key"] == key
    assert command["type"] == "shell"
    assert f"--direction {direction}" in command["command"]
    assert "--amount 0.05" in command["command"]
    assert '"$HERDR_BIN_PATH"' in command["command"]
    assert '"$HERDR_ACTIVE_PANE_ID"' in command["command"]

assert doc["ui"]["mouse_capture"] is True
assert doc["ui"]["prompt_new_tab_name"] is False
assert doc["ui"]["pane_borders"] is True
assert doc["ui"]["pane_gaps"] is False
assert doc["ui"]["accent"] == palette["accent"]
assert doc["ui"]["sound"]["enabled"] is False
assert doc["advanced"]["scrollback_limit_bytes"] == 100_000_000

assert doc["theme"]["name"] == "terminal"
assert doc["theme"]["auto_switch"] is False
assert doc["theme"]["custom"] == {
    "panel_bg": palette["bg"],
    "surface0": palette["surface"],
    "surface1": palette["surface_alt"],
    "surface_dim": palette["tool_neutral_bg"],
    "overlay0": palette["border"],
    "overlay1": palette["comment"],
    "text": palette["fg"],
    "subtext0": palette["muted"],
    "accent": palette["accent"],
    "mauve": palette["secondary"],
    "green": palette["success"],
    "yellow": palette["warn"],
    "red": palette["error"],
    "blue": palette["primary"],
    "teal": palette["info"],
    "peach": palette["orange"],
}
PY

windows_ignore="$tmpdir/windows-ignore"
darwin_ignore="$tmpdir/darwin-ignore"
chezmoi execute-template \
  --source "$repo_root" \
  --override-data '{"chezmoi":{"os":"windows"}}' \
  <"$repo_root/.chezmoiignore" >"$windows_ignore"
chezmoi execute-template \
  --source "$repo_root" \
  --override-data '{"chezmoi":{"os":"darwin"}}' \
  <"$repo_root/.chezmoiignore" >"$darwin_ignore"
grep -Fxq '.config/herdr' "$windows_ignore"
if grep -Fxq '.config/herdr' "$darwin_ignore"; then
  echo "HerdR config must remain managed on macOS" >&2
  exit 1
fi

echo "HerdR config template ok"
```

- [ ] **Step 2: Run the test and verify it fails for the missing template**

Run:

```bash
bash tests/chezmoi/test-herdr-config.sh
```

Expected: exit status `1` and `missing HerdR config template:`.

- [ ] **Step 3: Add the Windows ignore rule**

Add this line inside the existing `{{- if eq .chezmoi.os "windows" }}` block that already ignores `.config/tmux`:

```text
.config/herdr
```

- [ ] **Step 4: Add the minimal HerdR template**

Create `dot_config/herdr/config.toml.tmpl`:

```toml
{{- $p := (index .themes .theme).palette -}}
onboarding = false

[terminal]
default_shell = "zsh"
shell_mode = "auto"
new_cwd = "follow"

[keys]
prefix = "ctrl+b"
detach = "prefix+d"
reload_config = "prefix+r"
new_tab = "prefix+c"
rename_tab = "prefix+comma"
previous_tab = ["prefix+p", "ctrl+shift+h"]
next_tab = ["prefix+n", "ctrl+shift+l"]
switch_tab = "prefix+1..9"
close_tab = "prefix+ampersand"
copy_mode = "prefix+["
focus_pane_left = ""
focus_pane_down = ""
focus_pane_up = ""
focus_pane_right = ""
split_vertical = "prefix+percent"
split_horizontal = "prefix+double_quote"
close_pane = "prefix+x"
zoom = ["prefix+z", "ctrl+f"]
resize_mode = ""

[[keys.command]]
key = "prefix+h"
type = "shell"
command = 'exec "$HERDR_BIN_PATH" pane resize --direction left --amount 0.05 --pane "$HERDR_ACTIVE_PANE_ID"'
description = "resize pane left"

[[keys.command]]
key = "prefix+j"
type = "shell"
command = 'exec "$HERDR_BIN_PATH" pane resize --direction down --amount 0.05 --pane "$HERDR_ACTIVE_PANE_ID"'
description = "resize pane down"

[[keys.command]]
key = "prefix+k"
type = "shell"
command = 'exec "$HERDR_BIN_PATH" pane resize --direction up --amount 0.05 --pane "$HERDR_ACTIVE_PANE_ID"'
description = "resize pane up"

[[keys.command]]
key = "prefix+l"
type = "shell"
command = 'exec "$HERDR_BIN_PATH" pane resize --direction right --amount 0.05 --pane "$HERDR_ACTIVE_PANE_ID"'
description = "resize pane right"

[ui]
mouse_capture = true
prompt_new_tab_name = false
pane_borders = true
pane_gaps = false
accent = "{{ $p.accent }}"

[ui.sound]
enabled = false

[advanced]
scrollback_limit_bytes = 100_000_000

[theme]
name = "terminal"
auto_switch = false

[theme.custom]
panel_bg = "{{ $p.bg }}"
surface0 = "{{ $p.surface }}"
surface1 = "{{ $p.surface_alt }}"
surface_dim = "{{ $p.tool_neutral_bg }}"
overlay0 = "{{ $p.border }}"
overlay1 = "{{ $p.comment }}"
text = "{{ $p.fg }}"
subtext0 = "{{ $p.muted }}"
accent = "{{ $p.accent }}"
mauve = "{{ $p.secondary }}"
green = "{{ $p.success }}"
yellow = "{{ $p.warn }}"
red = "{{ $p.error }}"
blue = "{{ $p.primary }}"
teal = "{{ $p.info }}"
peach = "{{ $p.orange }}"
```

- [ ] **Step 5: Run the focused test and existing theme test**

Run:

```bash
bash tests/chezmoi/test-herdr-config.sh
bash tests/chezmoi/test-pi-theme-template.sh
```

Expected: both exit `0`, ending with `HerdR config template ok` and `Pi theme template and writers ok (8 themes)`.

- [ ] **Step 6: Commit the configuration slice**

```bash
git add .chezmoiignore dot_config/herdr/config.toml.tmpl tests/chezmoi/test-herdr-config.sh
git commit -m "feat(herdr): add tmux-compatible config"
```

---

### Task 2: Integrate HerdR with live theme switching

**Files:**
- Modify: `tests/chezmoi/test-herdr-config.sh`
- Modify: `dot_local/bin/executable_theme`
- Modify: `docs/themes.md`

**Interfaces:**
- Consumes: the managed `~/.config/herdr/config.toml` written by chezmoi and the default HerdR server socket selected by `herdr server reload-config`.
- Produces: a guarded, non-fatal live reload after palette changes and user-facing documentation of HerdR's theme behavior.

- [ ] **Step 1: Extend the test with failing reload assertions**

Insert before the final success message in `tests/chezmoi/test-herdr-config.sh`:

```bash
theme_switcher="$repo_root/dot_local/bin/executable_theme"
grep -Fq 'command -v herdr >/dev/null 2>&1' "$theme_switcher"
grep -Fq 'pgrep -xq herdr' "$theme_switcher"
grep -Fq 'herdr server reload-config' "$theme_switcher"
grep -Fq 'warn: herdr reload-config failed' "$theme_switcher"
```

- [ ] **Step 2: Run the test and verify the missing integration fails**

Run:

```bash
bash tests/chezmoi/test-herdr-config.sh
```

Expected: non-zero exit at the first missing `grep` assertion.

- [ ] **Step 3: Add guarded HerdR reload behavior**

Insert after the tmux reload block and before the Ghostty reload block in `dot_local/bin/executable_theme`:

```bash
# herdr — reload the default running server after chezmoi renders config.toml.
# Named sessions use separate sockets and are intentionally out of scope for
# the initial HerdR evaluation config.
if command -v herdr >/dev/null 2>&1 && pgrep -xq herdr 2>/dev/null; then
  echo ":: herdr reload-config"
  herdr server reload-config >/dev/null 2>&1 \
    || echo "warn: herdr reload-config failed" >&2
fi
```

- [ ] **Step 4: Document HerdR in the theme guide**

In the opening sentence of `docs/themes.md`, add `herdr` to the list of driven applications.

Add a `## herdr` section after `## pi`:

```markdown
## herdr

herdr uses a chezmoi-generated config at `~/.config/herdr/config.toml`. The template maps the active semantic palette directly onto herdr's custom theme tokens, with the host terminal theme as the fallback.

`theme` reloads the default running herdr server after `chezmoi apply`. Named herdr sessions use separate sockets and are not reloaded automatically in the initial evaluation setup.
```

Add this row to the `where it's stored` table:

```markdown
| `dot_config/herdr/config.toml.tmpl` | tmux-compatible herdr keys and generated custom palette |
```

- [ ] **Step 5: Run tests and static checks**

Run:

```bash
bash tests/chezmoi/test-herdr-config.sh
bash tests/chezmoi/test-pi-theme-template.sh
shellcheck dot_local/bin/executable_theme tests/chezmoi/test-herdr-config.sh
git diff --check
```

Expected: all commands exit `0`; focused tests print their success messages; `shellcheck` and `git diff --check` print no diagnostics.

- [ ] **Step 6: Commit the theme integration slice**

```bash
git add dot_local/bin/executable_theme docs/themes.md tests/chezmoi/test-herdr-config.sh
git commit -m "feat(theme): reload HerdR after theme changes"
```

---

### Task 3: Final verification and review preparation

**Files:**
- Verify only; no planned source changes.

**Interfaces:**
- Consumes: the complete branch from Tasks 1–2.
- Produces: evidence that the rendered config is syntactically valid, palette-complete, platform-scoped, and documented.

- [ ] **Step 1: Run the complete focused verification set**

```bash
bash tests/chezmoi/test-herdr-config.sh
bash tests/chezmoi/test-pi-theme-template.sh
shellcheck dot_local/bin/executable_theme tests/chezmoi/test-herdr-config.sh
git diff --check main...HEAD
git status --short --branch
```

Expected:

- Both shell tests exit `0`.
- Shellcheck and diff checks produce no diagnostics.
- Git status shows the feature branch with no uncommitted files.

- [ ] **Step 2: Review the branch diff against the approved spec**

```bash
git diff --stat main...HEAD
git diff main...HEAD -- \
  .chezmoiignore \
  dot_config/herdr/config.toml.tmpl \
  dot_local/bin/executable_theme \
  docs/themes.md \
  tests/chezmoi/test-herdr-config.sh
```

Expected: only the approved HerdR config, OS scoping, theme reload, theme documentation, and focused test changes are present.

- [ ] **Step 3: Optionally smoke-check with an installed HerdR binary**

```bash
if command -v herdr >/dev/null 2>&1; then
  herdr --version
  herdr status >/dev/null 2>&1 || true
else
  echo "herdr not installed; repository validation complete without runtime smoke check"
fi
```

Expected: the installed binary prints its version, or the explicit skip message is printed. This step must not start, stop, or mutate a running HerdR session.
