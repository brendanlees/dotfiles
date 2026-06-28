# Sketchybar Shared Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Sketchybar colors follow the active chezmoi theme and reload automatically when `theme <name>` runs.

**Architecture:** Keep `.chezmoidata/themes.yml` and `.theme` as the only source of truth. Render `~/.config/sketchybar/colors.sh` from a chezmoi template, leaving `executable_sketchybarrc` unchanged because it already sources `$CONFIG_DIR/colors.sh`. Reload the running bar through Sketchybar's documented `sketchybar --reload` command after `chezmoi apply`.

**Tech Stack:** chezmoi templates, YAML theme data, Bash, Sketchybar CLI.

## Global Constraints

- Active theme state remains `.chezmoidata/defaults.yml` plus optional gitignored `.chezmoidata/local.yml` override.
- Palette values continue to come from `.chezmoidata/themes.yml`.
- Rendered Sketchybar target path remains `~/.config/sketchybar/colors.sh`.
- Sketchybar color values must use `0xAARRGGBB` format.
- Solid colors use alpha `0xff`; bar and popup background colors use alpha `0xcc`; transparent remains `0x00000000`.

---

## File Structure

- `dot_config/sketchybar/colors.sh.tmpl`: new source template responsible for rendering Sketchybar shell color exports from the active chezmoi palette.
- `dot_config/sketchybar/colors.sh`: remove; replaced by `.tmpl` source so the target file name remains `colors.sh`.
- `dot_local/bin/executable_theme`: modify the live reload section to reload Sketchybar after `chezmoi apply` when Sketchybar is running.
- `docs/themes.md`: modify the app list and switching notes so Sketchybar is documented as theme-driven and live-reloaded.

---

### Task 1: Render Sketchybar colors from the shared palette

**Files:**
- Create: `dot_config/sketchybar/colors.sh.tmpl`
- Delete: `dot_config/sketchybar/colors.sh`

**Interfaces:**
- Consumes: `.theme`, `.themes`, and palette keys in `.chezmoidata/themes.yml`.
- Produces: rendered target `~/.config/sketchybar/colors.sh` with the same exported variable names already consumed by `dot_config/sketchybar/executable_sketchybarrc`.

- [ ] **Step 1: Verify the new template does not exist yet**

Run:

```bash
test ! -e dot_config/sketchybar/colors.sh.tmpl
```

Expected: exit code `0` before implementation. If it exits non-zero, inspect the existing file before continuing.

- [ ] **Step 2: Replace the static source file with the template**

Run:

```bash
cat > dot_config/sketchybar/colors.sh.tmpl <<'TMPL'
#!/bin/bash
{{ $p := (index .themes .theme).palette }}
# Sketchybar color palette
# Active theme: {{ .theme }}
# Format: 0xAARRGGBB

export BLACK=0xff{{ trimPrefix "#" $p.bg | lower }}
export WHITE=0xff{{ trimPrefix "#" $p.fg | lower }}
export RED=0xff{{ trimPrefix "#" $p.error | lower }}
export GREEN=0xff{{ trimPrefix "#" $p.success | lower }}
export BLUE=0xff{{ trimPrefix "#" $p.primary | lower }}
export YELLOW=0xff{{ trimPrefix "#" $p.warn | lower }}
export ORANGE=0xff{{ trimPrefix "#" $p.orange | lower }}
export MAGENTA=0xff{{ trimPrefix "#" $p.secondary | lower }}
export CYAN=0xff{{ trimPrefix "#" $p.info | lower }}
export GREY=0xff{{ trimPrefix "#" $p.border | lower }}
export TRANSPARENT=0x00000000

# bar
export BAR_COLOR=0xcc{{ trimPrefix "#" $p.bg | lower }}
export BAR_BORDER_COLOR=0xff{{ trimPrefix "#" $p.surface | lower }}
export ICON_COLOR=$WHITE
export LABEL_COLOR=$WHITE
export POPUP_BACKGROUND_COLOR=0xcc{{ trimPrefix "#" $p.bg | lower }}
export POPUP_BORDER_COLOR=0xff{{ trimPrefix "#" $p.surface | lower }}
TMPL
rm dot_config/sketchybar/colors.sh
```

Expected: `dot_config/sketchybar/colors.sh.tmpl` exists and `dot_config/sketchybar/colors.sh` is removed from the source tree.

- [ ] **Step 3: Render and syntax-check the template**

Run:

```bash
chezmoi --source "$PWD" execute-template < dot_config/sketchybar/colors.sh.tmpl > /tmp/sketchybar-colors.sh
bash -n /tmp/sketchybar-colors.sh
grep -q '^# Active theme: ' /tmp/sketchybar-colors.sh
grep -Eq '^export BAR_COLOR=0xcc[0-9a-f]{6}$' /tmp/sketchybar-colors.sh
grep -Eq '^export WHITE=0xff[0-9a-f]{6}$' /tmp/sketchybar-colors.sh
```

Expected: all commands exit `0`.

- [ ] **Step 4: Commit Task 1**

Run:

```bash
git add dot_config/sketchybar/colors.sh.tmpl dot_config/sketchybar/colors.sh
git commit -m "feat: template sketchybar colors"
```

Expected: commit succeeds with one deleted file and one created template file.

---

### Task 2: Reload Sketchybar and document the theme integration

**Files:**
- Modify: `dot_local/bin/executable_theme`
- Modify: `docs/themes.md`

**Interfaces:**
- Consumes: rendered `~/.config/sketchybar/colors.sh` from Task 1.
- Produces: `theme <name>` live-reloads Sketchybar when the `sketchybar` process and CLI are available.

- [ ] **Step 1: Insert the Sketchybar reload block after the borders reload block**

Find this block in `dot_local/bin/executable_theme`:

```bash
# yabai borders — SIGUSR1 reload
if pgrep -xq borders 2>/dev/null; then
  echo ":: borders reload"
  pkill -USR1 borders 2>/dev/null || true
fi
```

Insert immediately after it:

```bash
# sketchybar — reload config so the rendered colors apply
if pgrep -xq sketchybar 2>/dev/null && command -v sketchybar >/dev/null 2>&1; then
  echo ":: sketchybar reload"
  sketchybar --reload >/dev/null 2>&1 || true
fi
```

Expected: Sketchybar reload happens after `chezmoi apply` and after borders reload, before nvim and espanso reloads.

- [ ] **Step 2: Update the themes documentation app list**

In `docs/themes.md`, change the first sentence from:

```markdown
a single `theme` key in `.chezmoidata/defaults.yml` drives colors across ghostty, pi, tmux, nvim, btop, bat, starship, glow, zed, espanso, and yabai borders.
```

to:

```markdown
a single `theme` key in `.chezmoidata/defaults.yml` drives colors across ghostty, pi, tmux, nvim, btop, bat, starship, glow, zed, espanso, Sketchybar, and yabai borders.
```

Expected: Sketchybar appears in the theme-driven app list.

- [ ] **Step 3: Update the switching behavior documentation**

In `docs/themes.md`, change this paragraph:

```markdown
the script writes the choice to `.chezmoidata/local.yml`, runs `chezmoi apply`, and live-reloads tmux, ghostty, borders, nvim (over its socket), and espanso.
```

to:

```markdown
the script writes the choice to `.chezmoidata/local.yml`, runs `chezmoi apply`, and live-reloads tmux, ghostty, borders, Sketchybar, nvim (over its socket), and espanso.
```

Expected: the live-reload list includes Sketchybar.

- [ ] **Step 4: Syntax-check the modified theme switcher**

Run:

```bash
bash -n dot_local/bin/executable_theme
```

Expected: exit code `0`.

- [ ] **Step 5: Verify the docs mention Sketchybar exactly where expected**

Run:

```bash
grep -n 'Sketchybar' docs/themes.md
```

Expected output includes one line in the opening app list and one line in the live-reload paragraph.

- [ ] **Step 6: Commit Task 2**

Run:

```bash
git add dot_local/bin/executable_theme docs/themes.md
git commit -m "feat: reload sketchybar on theme switch"
```

Expected: commit succeeds with the theme script and docs updated.

---

### Task 3: Final verification

**Files:**
- Verify: `dot_config/sketchybar/colors.sh.tmpl`
- Verify: `dot_local/bin/executable_theme`
- Verify: `docs/themes.md`

**Interfaces:**
- Consumes: Tasks 1 and 2.
- Produces: evidence that the Sketchybar theme integration renders, parses, and is documented.

- [ ] **Step 1: Render Sketchybar colors and shell-check syntax**

Run:

```bash
chezmoi --source "$PWD" execute-template < dot_config/sketchybar/colors.sh.tmpl > /tmp/sketchybar-colors.sh
bash -n /tmp/sketchybar-colors.sh
sed -n '1,24p' /tmp/sketchybar-colors.sh
```

Expected: rendered output starts with `#!/bin/bash`, includes `# Active theme:`, and all exported colors use `0xff`, `0xcc`, or `0x00000000` prefixes.

- [ ] **Step 2: Verify chezmoi sees the target rename correctly**

Run:

```bash
git status --short
chezmoi --source "$PWD" execute-template < dot_config/sketchybar/colors.sh.tmpl >/tmp/sketchybar-colors.sh
```

Expected: `git status --short` is clean after Task 2 commit; template render exits `0`.

- [ ] **Step 3: Run the project static-analysis check for changed files if available**

Run:

```bash
if command -v fallow >/dev/null 2>&1; then
  fallow audit --changed-since main
else
  echo "fallow not installed; skipped"
fi
```

Expected: either `fallow` reports no blocking findings, or the command prints `fallow not installed; skipped`.

- [ ] **Step 4: Record final status**

Run:

```bash
git log --oneline --max-count=4
git status --short --branch
```

Expected: recent commits include the spec commit plus Task 1 and Task 2 commits; branch is `feat/sketchybar-shared-theme`; status is clean.
