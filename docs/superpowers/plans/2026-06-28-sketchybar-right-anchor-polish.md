# SketchyBar Right Anchor Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make date/time the final right-side SketchyBar anchor, add a subtle braille separator to the date/time segment, and shelve the SoundSource item by commenting it out.

**Architecture:** Keep the existing SketchyBar source-file pattern. `executable_sketchybarrc` owns right-side item order and shelving. `items/calendar.sh` owns the visual separator attached to the date/time item. A focused shell test verifies order and item configuration.

**Tech Stack:** chezmoi source files, Bash, SketchyBar CLI, Python 3 for test assertions.

## Global Constraints

- Work in `/Users/brendan/.local/share/chezmoi.feat-sketchybar-right-anchor-polish` on branch `feat/sketchybar-right-anchor-polish`.
- Calendar/date must be sourced after battery so date/time is the final right-side anchor.
- SoundSource must be commented out in `executable_sketchybarrc`, not deleted from the source tree.
- Calendar uses subtle braille separator glyph `⣿` as its icon.
- Calendar separator icon color is `GREY`.
- Do not add paired dynamic separators for Spotify or battery in this slice.

---

## File Structure

- Create `tests/chezmoi/test-sketchybar-right-anchor-polish.sh`: focused regression test for right-side order, shelved SoundSource, and calendar separator setup.
- Modify `dot_config/sketchybar/executable_sketchybarrc`: comment out SoundSource and reorder battery before calendar.
- Modify `dot_config/sketchybar/items/calendar.sh`: enable a muted braille separator icon.

---

### Task 1: Add right-anchor regression test

**Files:**
- Create: `tests/chezmoi/test-sketchybar-right-anchor-polish.sh`

**Interfaces:**
- Consumes: `dot_config/sketchybar/executable_sketchybarrc` and `dot_config/sketchybar/items/calendar.sh`.
- Produces: executable test command `bash tests/chezmoi/test-sketchybar-right-anchor-polish.sh` that later tasks must make pass.

- [ ] **Step 1: Create the failing test file**

Create `tests/chezmoi/test-sketchybar-right-anchor-polish.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RC="$ROOT/dot_config/sketchybar/executable_sketchybarrc"
CALENDAR="$ROOT/dot_config/sketchybar/items/calendar.sh"
TMP="${TMPDIR:-/tmp}/sketchybar-right-anchor-polish-test-$$"
BIN="$TMP/bin"
LOG="$TMP/sketchybar.log"
mkdir -p "$BIN"
trap 'rm -rf "$TMP"' EXIT

python3 - "$RC" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text().splitlines()
source_lines = [line.strip() for line in text if 'source "$ITEM_DIR/' in line]

assert 'source "$ITEM_DIR/spotify.sh"' in source_lines, source_lines
assert '# source "$ITEM_DIR/app_soundsource.sh" # shelved for now' in source_lines, source_lines
assert 'source "$ITEM_DIR/app_soundsource.sh"' not in source_lines, source_lines
assert 'source "$ITEM_DIR/battery.sh"' in source_lines, source_lines
assert 'source "$ITEM_DIR/calendar.sh"' in source_lines, source_lines
assert source_lines.index('source "$ITEM_DIR/battery.sh"') < source_lines.index('source "$ITEM_DIR/calendar.sh"'), source_lines
assert source_lines[-1] == 'source "$ITEM_DIR/calendar.sh"', source_lines
PY

cat > "$BIN/sketchybar" <<'SH'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$SKETCHYBAR_STUB_LOG"
SH
chmod +x "$BIN/sketchybar"

PATH="$BIN:$PATH" \
  SKETCHYBAR_STUB_LOG="$LOG" \
  FONT="JetBrainsMono Nerd Font Mono" \
  GREY=0xff808080 \
  PLUGIN_DIR=/tmp/plugins \
  bash "$CALENDAR"

python3 - "$LOG" <<'PY'
from pathlib import Path
import sys

log = Path(sys.argv[1]).read_text()
assert '--add item calendar right' in log, log
assert 'icon=⣿' in log, log
assert 'icon.color=0xff808080' in log, log
assert 'icon.drawing=off' not in log, log
assert 'script=/tmp/plugins/calendar.sh' in log, log
PY
```

- [ ] **Step 2: Make the test executable**

Run:

```bash
chmod +x tests/chezmoi/test-sketchybar-right-anchor-polish.sh
```

Expected: command exits 0.

- [ ] **Step 3: Run the test and verify it fails against current code**

Run:

```bash
bash tests/chezmoi/test-sketchybar-right-anchor-polish.sh
```

Expected: FAIL because SoundSource is still sourced, calendar is not the final right-side source, or calendar still has `icon.drawing=off`.

- [ ] **Step 4: Commit the failing regression test**

Run:

```bash
git add tests/chezmoi/test-sketchybar-right-anchor-polish.sh
git commit -m "test: cover sketchybar right anchor order"
```

Expected: commit succeeds with only the new test staged.

---

### Task 2: Reorder right-side items and add calendar separator

**Files:**
- Modify: `dot_config/sketchybar/executable_sketchybarrc`
- Modify: `dot_config/sketchybar/items/calendar.sh`
- Test: `tests/chezmoi/test-sketchybar-right-anchor-polish.sh`

**Interfaces:**
- Consumes: existing right-side items `spotify.sh`, `battery.sh`, and `calendar.sh`.
- Produces: right-side order with SoundSource commented out and calendar/date last; calendar item with braille separator icon.

- [ ] **Step 1: Confirm the regression test currently fails**

Run:

```bash
bash tests/chezmoi/test-sketchybar-right-anchor-polish.sh
```

Expected: FAIL with an assertion showing the current source order or calendar icon setup.

- [ ] **Step 2: Update `executable_sketchybarrc` right-side order**

Change the right-side source block to exactly:

```bash
source "$ITEM_DIR/spotify.sh"
# source "$ITEM_DIR/app_soundsource.sh" # shelved for now
source "$ITEM_DIR/battery.sh"
source "$ITEM_DIR/calendar.sh"
```

- [ ] **Step 3: Replace `items/calendar.sh` with separator-enabled item setup**

Replace `dot_config/sketchybar/items/calendar.sh` with:

```bash
#!/bin/bash

sketchybar --add item calendar right \
  --set calendar \
    icon="⣿" \
    icon.font="$FONT:Regular:13.0" \
    icon.color="$GREY" \
    icon.padding_left=4 \
    icon.padding_right=6 \
    update_freq=30 \
    script="$PLUGIN_DIR/calendar.sh"
```

- [ ] **Step 4: Syntax-check touched files**

Run:

```bash
bash -n dot_config/sketchybar/executable_sketchybarrc
bash -n dot_config/sketchybar/items/calendar.sh
```

Expected: both commands exit 0.

- [ ] **Step 5: Run the regression test and verify it passes**

Run:

```bash
bash tests/chezmoi/test-sketchybar-right-anchor-polish.sh
```

Expected: PASS with no output.

- [ ] **Step 6: Commit the polish change**

Run:

```bash
git add dot_config/sketchybar/executable_sketchybarrc dot_config/sketchybar/items/calendar.sh
git commit -m "refactor: anchor sketchybar clock on right"
```

Expected: commit succeeds with only the bar config and calendar item staged.

---

### Task 3: Run final verification and report manual checks

**Files:**
- No source changes expected unless verification reveals a defect.

**Interfaces:**
- Consumes: all changes from Tasks 1–2.
- Produces: verified branch ready to merge or keep for review.

- [ ] **Step 1: Run the targeted right-anchor test**

Run:

```bash
bash tests/chezmoi/test-sketchybar-right-anchor-polish.sh
```

Expected: PASS with no output.

- [ ] **Step 2: Syntax-check touched shell files**

Run:

```bash
bash -n dot_config/sketchybar/executable_sketchybarrc
bash -n dot_config/sketchybar/items/calendar.sh
```

Expected: both commands exit 0.

- [ ] **Step 3: Run shellcheck on touched files and test**

Run:

```bash
shellcheck -e SC1091 \
  dot_config/sketchybar/executable_sketchybarrc \
  dot_config/sketchybar/items/calendar.sh \
  tests/chezmoi/test-sketchybar-right-anchor-polish.sh
```

Expected: command exits 0.

- [ ] **Step 4: Run the full chezmoi shell test suite**

Run:

```bash
for test in tests/chezmoi/*.sh; do
  echo "==> $test"
  bash "$test"
done
```

Expected: every test exits 0.

- [ ] **Step 5: Run CI-style chezmoi dry-run verification**

Run:

```bash
cfg=/tmp/chezmoi-sketchybar-right-anchor-ci-config.toml
CHEZMOI_ROLE=ephemeral,headless chezmoi init --source="$PWD" --config="$cfg" --apply=false
CHEZMOI_ROLE=ephemeral,headless chezmoi apply --source "$PWD" --config="$cfg" --dry-run --verbose --exclude=externals >/tmp/chezmoi-sketchybar-right-anchor-dry-run.log
```

Expected: both commands exit 0.

- [ ] **Step 6: Inspect final diff**

Run:

```bash
git diff --stat main...HEAD
git diff --check main...HEAD
git status --short --branch
```

Expected: stat lists only the planned docs, SketchyBar, and test files; `git diff --check` exits 0; working tree is clean.

- [ ] **Step 7: Report manual follow-up checks**

Report this checklist:

```text
Manual follow-up after applying config:
- Run `chezmoi apply` and `sketchybar --reload`.
- Confirm date/time is the far-right visual anchor.
- Confirm a subtle `⣿` separator appears immediately before date/time.
- Confirm SoundSource no longer appears in the bar.
- Confirm Spotify and battery still appear/hide according to their own state.
```
