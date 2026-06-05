# Pi Theme System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate Pi TUI and powerline-footer colors from the dotfiles theme registry for every theme, and stop ghostty-sync from overriding Pi's active theme.

**Architecture:** Chezmoi remains the source of truth. Static chezmoi templates render Pi theme files from `.chezmoidata/themes.yml`; a small run-on-change script patches existing Pi settings without owning unrelated settings. A small local `pi-powerline-footer-local` patch makes the previous-prompt footer use the generated powerline theme instead of a hard-coded ANSI gray.

**Tech Stack:** chezmoi templates, YAML theme data, JSON Pi theme files, Python settings patch script, TypeScript local Pi extension, Node/npm tests.

---

## File structure

### Dotfiles worktree: `/Users/brendan/.local/share/chezmoi.feat-pi-theme-system`

- Create: `dot_pi/agent/themes/chezmoi.json.tmpl` — renders the stable Pi theme named `chezmoi` from the active `.theme` palette.
- Create: `dot_pi/agent/extensions/powerline-footer/theme.json.tmpl` — renders powerline-footer color overrides from the active `.theme` palette.
- Create: `.chezmoiscripts/run_onchange_after_configure-pi-settings.py.tmpl` — patches `~/.pi/agent/settings.json` to set `theme: "chezmoi"` and disable the startup extension from `pi-ghostty-theme-sync` without deleting unrelated settings.
- Modify: `docs/themes.md` — documents Pi as a theme-system target and explains that ghostty-sync is no longer the Pi source of truth.

### Pi config repo: `/Users/brendan/.pi`

- Modify: `agent/packages/pi-powerline-footer-local/types.ts` — adds a `lastPrompt` semantic color.
- Modify: `agent/packages/pi-powerline-footer-local/theme.ts` — adds a default `lastPrompt` color.
- Modify: `agent/packages/pi-powerline-footer-local/theme.example.json` — documents the new `lastPrompt` override key.
- Modify: `agent/packages/pi-powerline-footer-local/index.ts` — passes the Pi theme to `renderLastPromptLines()` and renders the previous-prompt footer with the new semantic color.
- Modify or add: `agent/packages/pi-powerline-footer-local/tests/theme.test.ts` — covers the new theme key.

---

### Task 1: Add the generated Pi TUI theme template

**Files:**
- Create: `/Users/brendan/.local/share/chezmoi.feat-pi-theme-system/dot_pi/agent/themes/chezmoi.json.tmpl`

- [ ] **Step 1: Write the template**

Create `dot_pi/agent/themes/chezmoi.json.tmpl` with this content:

```json
{{- $p := (index .themes .theme).palette -}}
{
  "$schema": "https://raw.githubusercontent.com/earendil-works/pi/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json",
  "name": "chezmoi",
  "vars": {
    "activeTheme": "{{ .theme }}",
    "bg": "{{ $p.bg }}",
    "fg": "{{ $p.fg }}",
    "surface": "{{ $p.surface }}",
    "surfaceAlt": "{{ $p.surface_alt }}",
    "border": "{{ $p.border }}",
    "comment": "{{ $p.comment }}",
    "muted": "{{ $p.muted }}",
    "primary": "{{ $p.primary }}",
    "primaryAlt": "{{ $p.primary_alt }}",
    "accentSubtle": "{{ $p.accent }}",
    "secondary": "{{ $p.secondary }}",
    "successTone": "{{ $p.success }}",
    "warningTone": "{{ $p.warn }}",
    "errorTone": "{{ $p.error }}",
    "infoTone": "{{ $p.info }}",
    "infoAlt": "{{ $p.info_alt }}",
    "orangeTone": "{{ $p.orange }}"
  },
  "colors": {
    "accent": "primary",
    "border": "border",
    "borderAccent": "comment",
    "borderMuted": "surfaceAlt",
    "success": "successTone",
    "error": "errorTone",
    "warning": "warningTone",
    "muted": "comment",
    "dim": "border",
    "text": "",
    "thinkingText": "comment",
    "selectedBg": "surface",
    "userMessageBg": "surface",
    "userMessageText": "",
    "customMessageBg": "surface",
    "customMessageText": "",
    "customMessageLabel": "primary",
    "toolPendingBg": "surface",
    "toolSuccessBg": "surfaceAlt",
    "toolErrorBg": "surfaceAlt",
    "toolTitle": "comment",
    "toolOutput": "comment",
    "mdHeading": "warningTone",
    "mdLink": "primary",
    "mdLinkUrl": "comment",
    "mdCode": "primaryAlt",
    "mdCodeBlock": "successTone",
    "mdCodeBlockBorder": "border",
    "mdQuote": "comment",
    "mdQuoteBorder": "border",
    "mdHr": "border",
    "mdListBullet": "primary",
    "toolDiffAdded": "successTone",
    "toolDiffRemoved": "errorTone",
    "toolDiffContext": "comment",
    "syntaxComment": "comment",
    "syntaxKeyword": "primary",
    "syntaxFunction": "infoTone",
    "syntaxVariable": "primaryAlt",
    "syntaxString": "successTone",
    "syntaxNumber": "warningTone",
    "syntaxType": "infoAlt",
    "syntaxOperator": "fg",
    "syntaxPunctuation": "comment",
    "thinkingOff": "surfaceAlt",
    "thinkingMinimal": "border",
    "thinkingLow": "comment",
    "thinkingMedium": "primaryAlt",
    "thinkingHigh": "primary",
    "thinkingXhigh": "secondary",
    "bashMode": "successTone"
  },
  "export": {
    "pageBg": "{{ $p.bg }}",
    "cardBg": "{{ $p.surface }}",
    "infoBg": "{{ $p.surface_alt }}"
  }
}
```

- [ ] **Step 2: Render and parse the current theme**

Run:

```bash
cd /Users/brendan/.local/share/chezmoi.feat-pi-theme-system
chezmoi execute-template --file dot_pi/agent/themes/chezmoi.json.tmpl | python3 -m json.tool >/tmp/chezmoi-pi-theme.json
python3 - <<'PY'
import json
from pathlib import Path
p = Path('/tmp/chezmoi-pi-theme.json')
data = json.loads(p.read_text())
required = [
  'accent','border','borderAccent','borderMuted','success','error','warning','muted','dim','text','thinkingText',
  'selectedBg','userMessageBg','userMessageText','customMessageBg','customMessageText','customMessageLabel',
  'toolPendingBg','toolSuccessBg','toolErrorBg','toolTitle','toolOutput','mdHeading','mdLink','mdLinkUrl','mdCode',
  'mdCodeBlock','mdCodeBlockBorder','mdQuote','mdQuoteBorder','mdHr','mdListBullet','toolDiffAdded','toolDiffRemoved',
  'toolDiffContext','syntaxComment','syntaxKeyword','syntaxFunction','syntaxVariable','syntaxString','syntaxNumber',
  'syntaxType','syntaxOperator','syntaxPunctuation','thinkingOff','thinkingMinimal','thinkingLow','thinkingMedium',
  'thinkingHigh','thinkingXhigh','bashMode'
]
missing = [key for key in required if key not in data['colors']]
assert data['name'] == 'chezmoi'
assert not missing, missing
print('ok: chezmoi Pi theme has all required colors')
PY
```

Expected: `ok: chezmoi Pi theme has all required colors`.

- [ ] **Step 3: Commit Task 1**

Run:

```bash
cd /Users/brendan/.local/share/chezmoi.feat-pi-theme-system
git add dot_pi/agent/themes/chezmoi.json.tmpl
git commit -m "feat: add generated pi theme"
```

---

### Task 2: Add the generated powerline-footer theme template

**Files:**
- Create: `/Users/brendan/.local/share/chezmoi.feat-pi-theme-system/dot_pi/agent/extensions/powerline-footer/theme.json.tmpl`

- [ ] **Step 1: Write the template**

Create `dot_pi/agent/extensions/powerline-footer/theme.json.tmpl` with this content:

```json
{{- $p := (index .themes .theme).palette -}}
{
  "colors": {
    "model": "{{ $p.comment }}",
    "shellMode": "{{ $p.success }}",
    "path": "{{ $p.primary }}",
    "gitDirty": "{{ $p.warn }}",
    "gitClean": "{{ $p.success }}",
    "thinking": "{{ $p.border }}",
    "thinkingMinimal": "{{ $p.border }}",
    "thinkingLow": "{{ $p.comment }}",
    "thinkingMedium": "{{ $p.primary_alt }}",
    "context": "{{ $p.comment }}",
    "contextWarn": "{{ $p.warn }}",
    "contextError": "{{ $p.error }}",
    "cost": "text",
    "tokens": "{{ $p.comment }}",
    "separator": "{{ $p.surface_alt }}",
    "border": "{{ $p.border }}",
    "lastPrompt": "{{ $p.surface_alt }}"
  },
  "icons": {
    "auto": "↯",
    "warning": ""
  }
}
```

- [ ] **Step 2: Render and parse the current theme**

Run:

```bash
cd /Users/brendan/.local/share/chezmoi.feat-pi-theme-system
chezmoi execute-template --file dot_pi/agent/extensions/powerline-footer/theme.json.tmpl | python3 -m json.tool >/tmp/chezmoi-powerline-theme.json
python3 - <<'PY'
import json
from pathlib import Path
data = json.loads(Path('/tmp/chezmoi-powerline-theme.json').read_text())
for key in ['separator', 'border', 'lastPrompt']:
    assert key in data['colors'], key
assert data['colors']['separator'] != data['colors']['border']
print('ok: powerline theme contains separator, border, and lastPrompt')
PY
```

Expected: `ok: powerline theme contains separator, border, and lastPrompt`.

- [ ] **Step 3: Commit Task 2**

Run:

```bash
cd /Users/brendan/.local/share/chezmoi.feat-pi-theme-system
git add dot_pi/agent/extensions/powerline-footer/theme.json.tmpl
git commit -m "feat: add generated powerline theme"
```

---

### Task 3: Patch Pi settings without owning the whole settings file

**Files:**
- Create: `/Users/brendan/.local/share/chezmoi.feat-pi-theme-system/.chezmoiscripts/run_onchange_after_configure-pi-settings.py.tmpl`

- [ ] **Step 1: Write the settings patch script**

Create `.chezmoiscripts/run_onchange_after_configure-pi-settings.py.tmpl` with this content:

```python
#!/usr/bin/env python3
"""Keep Pi pointed at the chezmoi-generated theme."""

import json
import os
from pathlib import Path

PACKAGE = "npm:@ogulcancelik/pi-ghostty-theme-sync"


def agent_dir() -> Path:
    override = os.environ.get("PI_AGENT_DIR")
    if override:
        return Path(override).expanduser()
    return Path.home() / ".pi" / "agent"


def disable_ghostty_sync(packages):
    changed = False
    result = []
    for package in packages:
        if package == PACKAGE:
            result.append({"source": PACKAGE, "extensions": []})
            changed = True
            continue
        if isinstance(package, dict) and package.get("source") == PACKAGE:
            updated = dict(package)
            if updated.get("extensions") != []:
                updated["extensions"] = []
                changed = True
            result.append(updated)
            continue
        result.append(package)
    return result, changed


def main() -> None:
    settings_path = agent_dir() / "settings.json"
    settings_path.parent.mkdir(parents=True, exist_ok=True)

    if settings_path.exists():
        data = json.loads(settings_path.read_text())
        if not isinstance(data, dict):
            raise SystemExit(f"{settings_path} must contain a JSON object")
    else:
        data = {}

    data["theme"] = "chezmoi"
    packages = data.get("packages", [])
    if not isinstance(packages, list):
        raise SystemExit(f"{settings_path}: packages must be a list when present")
    data["packages"], _ = disable_ghostty_sync(packages)

    settings_path.write_text(json.dumps(data, indent=2) + "\n")
    print(f"configured Pi theme in {settings_path}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Test the script against a temporary Pi agent dir**

Run:

```bash
cd /Users/brendan/.local/share/chezmoi.feat-pi-theme-system
TMP_PI_AGENT=$(mktemp -d)
export TMP_PI_AGENT
cat >"$TMP_PI_AGENT/settings.json" <<'JSON'
{
  "theme": "ghostty-sync-old",
  "defaultModel": "gpt-5.5",
  "packages": [
    "npm:context-mode",
    "npm:@ogulcancelik/pi-ghostty-theme-sync",
    { "source": "npm:pi-lens", "extensions": [] }
  ]
}
JSON
chezmoi execute-template --file .chezmoiscripts/run_onchange_after_configure-pi-settings.py.tmpl > /tmp/configure-pi-settings.py
PI_AGENT_DIR="$TMP_PI_AGENT" python3 /tmp/configure-pi-settings.py
python3 - <<'PY'
import json, pathlib, os
settings = json.loads(pathlib.Path(os.environ['TMP_PI_AGENT'], 'settings.json').read_text())
assert settings['theme'] == 'chezmoi'
assert settings['defaultModel'] == 'gpt-5.5'
assert {'source': 'npm:@ogulcancelik/pi-ghostty-theme-sync', 'extensions': []} in settings['packages']
print('ok: settings patched without dropping unrelated keys')
PY
rm -rf "$TMP_PI_AGENT" /tmp/configure-pi-settings.py
```

Expected: `ok: settings patched without dropping unrelated keys`.

- [ ] **Step 3: Commit Task 3**

Run:

```bash
cd /Users/brendan/.local/share/chezmoi.feat-pi-theme-system
git add .chezmoiscripts/run_onchange_after_configure-pi-settings.py.tmpl
git commit -m "feat: configure pi theme settings"
```

---

### Task 4: Teach powerline-footer to theme the previous-prompt footer

**Files:**
- Modify: `/Users/brendan/.pi/agent/packages/pi-powerline-footer-local/types.ts`
- Modify: `/Users/brendan/.pi/agent/packages/pi-powerline-footer-local/theme.ts`
- Modify: `/Users/brendan/.pi/agent/packages/pi-powerline-footer-local/theme.example.json`
- Modify: `/Users/brendan/.pi/agent/packages/pi-powerline-footer-local/index.ts`
- Modify or add: `/Users/brendan/.pi/agent/packages/pi-powerline-footer-local/tests/theme.test.ts`

- [ ] **Step 1: Create or switch to a Pi config feature branch**

Run:

```bash
cd /Users/brendan/.pi
git status --short --branch
git switch -c feat/powerline-last-prompt-theme
```

Expected: branch is `feat/powerline-last-prompt-theme`. If the branch already exists, run `git switch feat/powerline-last-prompt-theme` instead.

- [ ] **Step 2: Extend the semantic color type**

In `agent/packages/pi-powerline-footer-local/types.ts`, change the end of `SemanticColor` from:

```ts
  | "tokens"
  | "separator"
  | "border";
```

to:

```ts
  | "tokens"
  | "separator"
  | "border"
  | "lastPrompt";
```

- [ ] **Step 3: Add the default color**

In `agent/packages/pi-powerline-footer-local/theme.ts`, add `lastPrompt` to `DEFAULT_COLORS` immediately after `border`:

```ts
  separator: "dim",
  border: "borderMuted",
  lastPrompt: "dim",
};
```

- [ ] **Step 4: Document the example override**

In `agent/packages/pi-powerline-footer-local/theme.example.json`, change the final color entries from:

```json
    "separator": "dim",
    "border": "borderMuted"
```

to:

```json
    "separator": "dim",
    "border": "borderMuted",
    "lastPrompt": "dim"
```

- [ ] **Step 5: Render last prompt through the theme resolver**

In `agent/packages/pi-powerline-footer-local/index.ts`, change the import from:

```ts
import { getDefaultColors, setThemeConfigPath } from "./theme.ts";
```

to:

```ts
import { fg as themeFg, getDefaultColors, setThemeConfigPath } from "./theme.ts";
```

Then replace `renderLastPromptLines` with:

```ts
  function renderLastPromptLines(width: number, theme: Theme): string[] {
    if (bashModeActive || !showLastPrompt || !lastUserPrompt) return [];

    const prefix = ` ${themeFg(theme, "lastPrompt", "↳")} `;
    const availableWidth = width - visibleWidth(prefix);
    if (availableWidth < 10) return [];

    let promptText = lastUserPrompt.replace(/\s+/g, " ").trim();
    if (!promptText) return [];

    promptText = truncateToWidth(promptText, availableWidth, "…");

    const styledPrompt = themeFg(theme, "lastPrompt", promptText);
    const line = `${prefix}${styledPrompt}`;
    return [truncateToWidth(line, width, "…")];
  }
```

Update the fixed-editor compositor call from:

```ts
          lastPromptLines: renderLastPromptLines(width),
```

to:

```ts
          lastPromptLines: renderLastPromptLines(width, theme),
```

Update the widget registration from:

```ts
    ctx.ui.setWidget("powerline-last-prompt", () => ({
      dispose() {},
      invalidate() {},
      render(width: number): string[] {
        return renderLastPromptLines(width);
      },
    }), { placement: "belowEditor" });
```

to:

```ts
    ctx.ui.setWidget("powerline-last-prompt", (_tui: any, theme: Theme) => ({
      dispose() {},
      invalidate() {},
      render(width: number): string[] {
        return renderLastPromptLines(width, theme);
      },
    }), { placement: "belowEditor" });
```

- [ ] **Step 6: Add or update a theme test**

In `agent/packages/pi-powerline-footer-local/tests/theme.test.ts`, add this assertion to the existing default-color test, or create an equivalent test if the file structure differs:

```ts
import { describe, expect, it } from "vitest";
import { getDefaultColors, resolveColor } from "../theme.ts";

describe("powerline theme", () => {
  it("includes a configurable lastPrompt semantic color", () => {
    const defaults = getDefaultColors();
    expect(defaults.lastPrompt).toBe("dim");
    expect(resolveColor("lastPrompt")).toBe("dim");
  });
});
```

If `theme.test.ts` already imports from `../theme.ts`, merge the new `it(...)` block instead of duplicating imports.

- [ ] **Step 7: Run package tests**

Run:

```bash
cd /Users/brendan/.pi/agent/packages/pi-powerline-footer-local
npm test -- --runInBand 2>/dev/null || npm test
```

Expected: the package test suite passes. If the test runner does not support `--runInBand`, the fallback `npm test` should run.

- [ ] **Step 8: Commit Task 4 in the Pi config repo**

Run:

```bash
cd /Users/brendan/.pi
git add agent/packages/pi-powerline-footer-local/types.ts \
        agent/packages/pi-powerline-footer-local/theme.ts \
        agent/packages/pi-powerline-footer-local/theme.example.json \
        agent/packages/pi-powerline-footer-local/index.ts \
        agent/packages/pi-powerline-footer-local/tests/theme.test.ts
git commit -m "feat: theme powerline last prompt"
```

---

### Task 5: Update dotfiles theme documentation

**Files:**
- Modify: `/Users/brendan/.local/share/chezmoi.feat-pi-theme-system/docs/themes.md`

- [ ] **Step 1: Update the target list**

Change the first paragraph from:

```markdown
a single `theme` key in `.chezmoidata/defaults.yml` drives colors across ghostty, tmux, nvim, btop, bat, starship, glow, zed, espanso, and yabai borders.
```

to:

```markdown
a single `theme` key in `.chezmoidata/defaults.yml` drives colors across ghostty, pi, tmux, nvim, btop, bat, starship, glow, zed, espanso, and yabai borders.
```

- [ ] **Step 2: Add a Pi section after the restart list**

Add this section after the list of apps that need manual restart:

```markdown
## pi

pi uses a chezmoi-generated theme named `chezmoi` at `~/.pi/agent/themes/chezmoi.json` plus a powerline footer override at `~/.pi/agent/extensions/powerline-footer/theme.json`.

`pi-ghostty-theme-sync` is not the source of truth for pi colors. The package may remain installed, but its startup extension is disabled so it cannot replace the active pi theme with a `ghostty-sync-*` theme.

After switching themes, restart or reload pi if the running session does not hot-reload the generated theme files.
```

- [ ] **Step 3: Mention Pi in the storage table**

Add these rows to the `where it's stored` table:

```markdown
| `dot_pi/agent/themes/chezmoi.json.tmpl` | pi TUI theme generated from the active palette |
| `dot_pi/agent/extensions/powerline-footer/theme.json.tmpl` | pi powerline/status chrome generated from the active palette |
```

- [ ] **Step 4: Commit Task 5**

Run:

```bash
cd /Users/brendan/.local/share/chezmoi.feat-pi-theme-system
git add docs/themes.md
git commit -m "docs: document pi theme generation"
```

---

### Task 6: End-to-end validation and apply

**Files:**
- Validate generated outputs in the dotfiles worktree.
- Apply generated outputs to `$HOME` only after template validation passes.

- [ ] **Step 1: Validate templates for every theme key**

Run:

```bash
cd /Users/brendan/.local/share/chezmoi.feat-pi-theme-system
python3 - <<'PY'
from pathlib import Path
import json
import subprocess
import yaml

root = Path.cwd()
themes = yaml.safe_load((root / '.chezmoidata/themes.yml').read_text())['themes']
files = [
    'dot_pi/agent/themes/chezmoi.json.tmpl',
    'dot_pi/agent/extensions/powerline-footer/theme.json.tmpl',
]
for theme in themes:
    override = json.dumps({'theme': theme})
    for file in files:
        rendered = subprocess.check_output([
            'chezmoi', 'execute-template', '--override-data', override, '--file', file
        ], text=True)
        json.loads(rendered)
print(f'ok: rendered {len(themes)} themes across {len(files)} templates')
PY
```

Expected: `ok: rendered 5 themes across 2 templates` with the current theme registry.

- [ ] **Step 2: Dry-run chezmoi apply for the target files**

Run:

```bash
cd /Users/brendan/.local/share/chezmoi.feat-pi-theme-system
chezmoi apply --dry-run --verbose ~/.pi/agent/themes/chezmoi.json ~/.pi/agent/extensions/powerline-footer/theme.json
```

Expected: dry-run shows only the two generated theme files changing or being created.

- [ ] **Step 3: Apply Pi theme files and settings patch**

Run:

```bash
cd /Users/brendan/.local/share/chezmoi.feat-pi-theme-system
chezmoi apply ~/.pi/agent/themes/chezmoi.json ~/.pi/agent/extensions/powerline-footer/theme.json
chezmoi apply --include scripts --force
```

Expected: `~/.pi/agent/themes/chezmoi.json` and `~/.pi/agent/extensions/powerline-footer/theme.json` exist, and the settings script prints `configured Pi theme in .../settings.json`.

- [ ] **Step 4: Verify applied Pi settings**

Run:

```bash
python3 - <<'PY'
import json
from pathlib import Path
settings = json.loads(Path.home().joinpath('.pi/agent/settings.json').read_text())
assert settings['theme'] == 'chezmoi'
for package in settings.get('packages', []):
    if isinstance(package, dict) and package.get('source') == 'npm:@ogulcancelik/pi-ghostty-theme-sync':
        assert package.get('extensions') == []
        break
else:
    raise AssertionError('ghostty-sync package object with disabled extensions not found')
print('ok: pi settings use chezmoi theme and disable ghostty-sync extension')
PY
```

Expected: `ok: pi settings use chezmoi theme and disable ghostty-sync extension`.

- [ ] **Step 5: Run documentation/config validation**

Run:

```bash
if [ -f /Users/brendan/.pi/agent/scripts/validate-config-docs.py ]; then
  cd /Users/brendan/.pi/agent
  python3 scripts/validate-config-docs.py
else
  echo 'skip: /Users/brendan/.pi/agent/scripts/validate-config-docs.py not present'
fi
```

Expected: either the validator passes, or the skip message appears because this install does not have the validator script at that path.

- [ ] **Step 6: Commit Task 6 if validation required source changes**

If validation required source changes, commit them in the relevant repo. If no files changed, do not create an empty commit.

Run:

```bash
cd /Users/brendan/.local/share/chezmoi.feat-pi-theme-system
git status --short
cd /Users/brendan/.pi
git status --short
```

Expected: both repos are clean except for intentional uncommitted changes that the user explicitly wants to keep out of git.
