# Terminal Theme Registry Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 28 requested dark terminal themes to the global chezmoi theme registry with complete semantic palettes, valid application mappings, and automated coverage.

**Architecture:** Ghostty's bundled theme files are the source of truth for terminal names and colors. A focused registry test locks the requested key-to-Ghostty-name mapping and complete schema, while the existing Pi theme test renders every registry palette through its downstream template.

**Tech Stack:** YAML, Bash, Python 3 standard library, chezmoi CLI, Ghostty bundled themes

## Global Constraints

- Add exactly the 28 themes approved in `docs/superpowers/specs/2026-11-13-terminal-theme-expansion-design.md`.
- Use lowercase kebab-case registry keys.
- Every entry must define all 19 current palette keys and all 9 current app keys.
- `apps.ghostty` must exactly match a bundled Ghostty theme name.
- Unsupported app themes must use a closest existing, known-good fallback.
- Every new theme must set `apps.nvim_background` to `dark`.
- Do not add generators, application packages, or unrelated configuration.

---

### Task 1: Add registry contract coverage

**Files:**
- Create: `tests/chezmoi/test-theme-registry.sh`

**Interfaces:**
- Consumes: `chezmoi data --source <repo> --format json`
- Produces: a portable executable test that validates requested registry keys, exact Ghostty names, schema completeness, hex colors, and optional local Ghostty file existence

- [ ] **Step 1: Write the failing registry test**

Create `tests/chezmoi/test-theme-registry.sh` with executable mode and this structure:

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

chezmoi data --source "$repo_root" --format json >"$tmpdir/data.json"

python3 - "$tmpdir/data.json" "${GHOSTTY_THEME_DIR:-}" <<'PY'
import json
import re
import sys
from pathlib import Path

expected = {
    "black-metal": "Black Metal",
    "black-metal-bathory": "Black Metal (Bathory)",
    "black-metal-burzum": "Black Metal (Burzum)",
    "black-metal-dark-funeral": "Black Metal (Dark Funeral)",
    "black-metal-gorgoroth": "Black Metal (Gorgoroth)",
    "black-metal-immortal": "Black Metal (Immortal)",
    "black-metal-khold": "Black Metal (Khold)",
    "black-metal-marduk": "Black Metal (Marduk)",
    "black-metal-mayhem": "Black Metal (Mayhem)",
    "black-metal-nile": "Black Metal (Nile)",
    "black-metal-venom": "Black Metal (Venom)",
    "batman": "Batman",
    "darkmatrix": "Darkmatrix",
    "embers-dark": "Embers Dark",
    "fahrenheit": "Fahrenheit",
    "flatland": "Flatland",
    "japanesque": "Japanesque",
    "kanso-ink": "Kanso Ink",
    "kanso-zen": "Kanso Zen",
    "miasma": "Miasma",
    "mona-lisa": "Mona Lisa",
    "nvim-dark": "Nvim Dark",
    "sleepy-hollow": "Sleepy Hollow",
    "synthwave": "Synthwave",
    "synthwave-alpha": "Synthwave Alpha",
    "synthwave-everything": "Synthwave Everything",
    "twilight": "Twilight",
    "wryan": "Wryan",
}
required_palette = {
    "bg", "surface", "surface_alt", "border", "comment", "muted", "fg",
    "accent", "primary", "primary_alt", "secondary", "success", "warn",
    "error", "info", "info_alt", "orange", "tool_neutral_bg",
    "tool_error_bg",
}
required_apps = {
    "ghostty", "btop", "bat", "glow", "starship", "tmux_ukiyo",
    "zed", "nvim", "nvim_background",
}
hex_color = re.compile(r"^#[0-9a-fA-F]{6}$")
data = json.loads(Path(sys.argv[1]).read_text())
themes = data["themes"]

missing = sorted(set(expected) - set(themes))
if missing:
    raise SystemExit(f"missing requested themes: {', '.join(missing)}")

for key, ghostty_name in expected.items():
    theme = themes[key]
    if set(theme) != {"palette", "apps"}:
        raise SystemExit(f"{key}: expected only palette and apps blocks")
    if set(theme["palette"]) != required_palette:
        raise SystemExit(f"{key}: palette schema mismatch")
    if set(theme["apps"]) != required_apps:
        raise SystemExit(f"{key}: apps schema mismatch")
    for color_key, color in theme["palette"].items():
        if not isinstance(color, str) or not hex_color.fullmatch(color):
            raise SystemExit(f"{key}: invalid {color_key}: {color!r}")
    if theme["apps"]["ghostty"] != ghostty_name:
        raise SystemExit(f"{key}: Ghostty mapping mismatch")
    if theme["apps"]["nvim_background"] != "dark":
        raise SystemExit(f"{key}: nvim_background must be dark")
    if theme["palette"]["tool_neutral_bg"].lower() == theme["palette"]["tool_error_bg"].lower():
        raise SystemExit(f"{key}: tool surfaces must differ")

root = Path(sys.argv[2]) if sys.argv[2] else None
if root:
    if not root.is_dir():
        raise SystemExit(f"Ghostty theme directory not found: {root}")
    absent = sorted(name for name in expected.values() if not (root / name).is_file())
    if absent:
        raise SystemExit(f"missing bundled Ghostty themes: {', '.join(absent)}")

print(f"theme registry ok ({len(expected)} requested themes)")
PY
```

Then make it executable:

```bash
chmod +x tests/chezmoi/test-theme-registry.sh
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
tests/chezmoi/test-theme-registry.sh
```

Expected: FAIL with `missing requested themes:` followed by the 28 new keys.

- [ ] **Step 3: Commit the failing contract test**

```bash
git add tests/chezmoi/test-theme-registry.sh
git commit -m "test(theme): cover expanded registry"
```

---

### Task 2: Add source-anchored theme entries

**Files:**
- Modify: `.chezmoidata/themes.yml`

**Interfaces:**
- Consumes: `/Applications/Ghostty.app/Contents/Resources/ghostty/themes/<exact name>` for each mapping locked by Task 1
- Produces: 28 complete entries under `.themes`, consumed by all existing color and app-name templates

- [ ] **Step 1: Extract and normalize authoritative source colors**

For every exact Ghostty name in Task 1, read `palette = N=#RRGGBB`, `background`, `foreground`, and `cursor-color`. Preserve the source hex values. Build each semantic palette using this fixed baseline mapping, then adjust only subdued structural colors when needed for contrast:

```text
bg              = background
surface         = background blended 8% toward foreground
surface_alt     = background blended 16% toward foreground
border          = ANSI bright black (index 8)
comment         = ANSI bright black (index 8)
muted           = ANSI white (index 7)
fg              = foreground
accent          = cursor-color
primary         = ANSI bright blue (index 12)
primary_alt     = ANSI blue (index 4)
secondary       = ANSI bright magenta (index 13)
success         = ANSI bright green (index 10)
warn            = ANSI bright yellow (index 11)
error           = ANSI bright red (index 9)
info            = ANSI bright cyan (index 14)
info_alt        = ANSI cyan (index 6)
orange          = ANSI yellow (index 3)
tool_neutral_bg = background blended 5% toward foreground
tool_error_bg   = background blended 8% toward ANSI bright red
```

Blend each RGB channel with `round(background * (1 - ratio) + target * ratio)` and emit six-digit hex. If `border` or `comment` has insufficient visual separation from `bg`, use `surface_alt` for `border` and the source ANSI white for `comment`. Keep `tool_neutral_bg` and `tool_error_bg` distinct; increase the error blend to 12% only if 8% rounds to the neutral value.

- [ ] **Step 2: Add the 28 complete YAML entries**

Append entries in these groups: Black Metal family, standalone themes through Japanesque, Kanso family, standalone themes through Sleepy Hollow, Synthwave family, then Twilight and Wryan. Use the exact registry and Ghostty names from Task 1.

Use these known-good fallback profiles for the remaining app keys:

| Theme family | btop | bat | glow | starship | tmux_ukiyo | zed | nvim |
|---|---|---|---|---|---|---|---|
| Black Metal, Batman, Embers Dark, Miasma, Mona Lisa, Twilight | `monokai` | `Monokai Extended` | `auto` | `monokai` | `gruvbox/dark` | `Monokai Pro` | `monokai-pro` |
| Darkmatrix, Kanso Ink, Kanso Zen | `kanagawa` | `kanagawa` | `auto` | `kanagawa-wave` | `kanagawa/dragon` | `Kanagawa Dragon` | `kanagawa-dragon` |
| Fahrenheit, Flatland, Japanesque, Sleepy Hollow, Synthwave family, Wryan | `tokyonight_night` | `tokyonight_night` | `auto` | `tokyo-night` | `tokyonight/night` | `Tokyo Night` | `tokyonight-night` |
| Nvim Dark | `tokyonight_night` | `tokyonight_night` | `auto` | `tokyo-night` | `tokyonight/night` | `Tokyo Night` | `default` |

Set `nvim_background: "dark"` in every entry.

- [ ] **Step 3: Run the registry test**

Run:

```bash
tests/chezmoi/test-theme-registry.sh
```

Expected: PASS with `theme registry ok (28 requested themes)`.

- [ ] **Step 4: Verify exact local Ghostty availability**

Run:

```bash
GHOSTTY_THEME_DIR=/Applications/Ghostty.app/Contents/Resources/ghostty/themes \
  tests/chezmoi/test-theme-registry.sh
```

Expected: PASS with no missing bundled theme names.

- [ ] **Step 5: Run downstream Pi rendering coverage**

Run:

```bash
tests/chezmoi/test-pi-theme-template.sh
```

Expected: PASS with `Pi theme template and writers ok (36 themes)`.

- [ ] **Step 6: Commit the registry expansion**

```bash
git add .chezmoidata/themes.yml
git commit -m "feat(theme): add dark terminal palettes"
```

---

### Task 3: Verify representative application templates

**Files:**
- Verify: `.chezmoidata/themes.yml`
- Verify: `dot_config/ghostty/config.tmpl`
- Verify: `dot_config/bat/config.tmpl`
- Verify: `dot_config/btop/btop.conf.tmpl`
- Verify: `dot_config/starship/private_starship.toml.tmpl`
- Verify: `dot_config/tmux/tmux.conf.tmpl`
- Verify: `dot_config/zed/private_settings.json.tmpl`

**Interfaces:**
- Consumes: registry entries added in Task 2
- Produces: evidence that application templates resolve exact and fallback mappings without unresolved values

- [ ] **Step 1: Render representative themes through chezmoi**

Render one theme from each mapping family:

```bash
for theme in black-metal darkmatrix synthwave-everything nvim-dark; do
  out=$(mktemp -d)
  chezmoi execute-template \
    --source . \
    --override-data "{\"theme\":\"$theme\"}" \
    <dot_config/ghostty/config.tmpl >"$out/ghostty"
  chezmoi execute-template \
    --source . \
    --override-data "{\"theme\":\"$theme\"}" \
    <dot_config/bat/config.tmpl >"$out/bat"
  chezmoi execute-template \
    --source . \
    --override-data "{\"theme\":\"$theme\"}" \
    <dot_config/btop/btop.conf.tmpl >"$out/btop"
  if grep -R -E '<no value>|{{|}}' "$out"; then
    echo "$theme: unresolved template output" >&2
    exit 1
  fi
  rm -rf "$out"
done
```

Expected: exit 0 and no output.

- [ ] **Step 2: Run both focused tests together**

```bash
tests/chezmoi/test-theme-registry.sh && tests/chezmoi/test-pi-theme-template.sh
```

Expected: both PASS, reporting 28 requested themes and 36 total themes.

- [ ] **Step 3: Confirm the worktree contains only intended changes**

```bash
git status --short
git diff --check HEAD~2..HEAD
git log --oneline --max-count=4
```

Expected: clean status, no whitespace errors, and focused test and feature commits following the design commit.
