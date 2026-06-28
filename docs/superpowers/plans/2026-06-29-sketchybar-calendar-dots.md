# SketchyBar Calendar Today-Dots Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Itsycal-style today-event dots between the calendar pill's date and time, with a neutral grey fallback dot when no mapped calendars have events today.

**Architecture:** Split the current calendar pill into a bracketed group: `calendar` shows icon + date, dot items show event-bucket state, and `calendar_time` shows time. A cheap clock plugin updates text; a separate Swift/EventKit plugin refreshes dots every 5 minutes and on wake.

**Tech Stack:** Bash, SketchyBar shell config, Swift/EventKit via `swift -`, chezmoi dotfiles, existing bash tests.

## Global Constraints

- Worktree: `/Users/brendan/.local/share/chezmoi.feat-sketchybar-calendar-dots` on branch `feat/sketchybar-calendar-dots`.
- Today-only horizon: local midnight ≤ event start < tomorrow midnight.
- Dots are per bucket, not per event: family/pink, work/orange, personal/green.
- Neutral grey dot is shown only when all three colored buckets are empty or Swift/EventKit query fails.
- Click triggers ctrl+option+c for Itsycal widget; `open -a Itsycal` is fallback after keystroke attempt.
- No new external dependency.
- TDD required: failing tests before production shell changes.
- Preserve right-items order: `calendar`, `battery`, `tailscale`, `spotify`.

---

## File Structure

- Modify `dot_config/sketchybar/items/calendar.sh` — bracketed calendar pill, dots, time item, click script.
- Modify `dot_config/sketchybar/plugins/executable_calendar.sh` — split date/time update.
- Create `dot_config/sketchybar/plugins/executable_calendar_dots.sh` — Swift/EventKit query + bucketed dot drawing.
- Create `tests/chezmoi/test-sketchybar-calendar-dots.sh` — plugin behavior matrix with stubbed `date`, `swift`, `sketchybar`.
- Create `tests/chezmoi/test-sketchybar-calendar-sourcing.sh` — item/bracket/click wiring.
- Update `tests/chezmoi/test-sketchybar-right-anchor-polish.sh` — bracketed calendar expectations.

---

### Task 1: Plugin tests first

**Files:**
- Create: `tests/chezmoi/test-sketchybar-calendar-dots.sh`
- Test target: `dot_config/sketchybar/plugins/executable_calendar.sh`
- Test target: `dot_config/sketchybar/plugins/executable_calendar_dots.sh`

**Interfaces:**
- `executable_calendar.sh` must call `sketchybar --set calendar label=<dd/mm> --set calendar_time icon=<HH:MM AM>`.
- `executable_calendar_dots.sh` must consume Swift/EventKit calendar-name lines and set `cal_dot_fam`, `cal_dot_work`, `cal_dot_per`, `cal_dot_neutral` drawing states.

- [ ] **Step 1: Write failing test.** Create a bash test with stub `date`, `swift`, and `sketchybar`. Cases: clock split; no mapped events; family-only; work-only; personal-only; mixed all-three; unmapped-only; Swift/EventKit error. Assert grey neutral is on only when no colored bucket is on or query fails.
- [ ] **Step 2: Run RED.** `tests/chezmoi/test-sketchybar-calendar-dots.sh` should fail because the dots plugin is absent and the clock plugin still writes one label.
- [ ] **Step 3: Implement minimal plugins.** Split `executable_calendar.sh`; create `executable_calendar_dots.sh` with the Swift/EventKit today query and exact buckets from the spec.
- [ ] **Step 4: Run GREEN.** `tests/chezmoi/test-sketchybar-calendar-dots.sh` should print `ALL CASES PASSED`.

---

### Task 2: Item/bracket tests first

**Files:**
- Create: `tests/chezmoi/test-sketchybar-calendar-sourcing.sh`
- Modify target: `dot_config/sketchybar/items/calendar.sh`

**Interfaces:**
- `items/calendar.sh` must create `calendar`, `cal_dot_fam`, `cal_dot_work`, `cal_dot_per`, `cal_dot_neutral`, `calendar_time`, and `calendar_group`.
- Every visible element in the group must carry the same ctrl+option+c click script with `open -a Itsycal` fallback.

- [ ] **Step 1: Write failing sourcing test.** Stub `sketchybar`, source `items/calendar.sh`, assert all item names, bracket, dot glyph `●`, pink/orange/green/grey colors, update frequencies 15 and 300, scripts, and click script.
- [ ] **Step 2: Run RED.** `tests/chezmoi/test-sketchybar-calendar-sourcing.sh` should fail because only the old single calendar item exists.
- [ ] **Step 3: Implement item group.** Replace the single-item calendar definition with date item + four dot items + time item + bracket.
- [ ] **Step 4: Run GREEN.** Calendar sourcing test should print `SOURCING OK`.

---

### Task 3: Adjust existing right-anchor test

**Files:**
- Modify: `tests/chezmoi/test-sketchybar-right-anchor-polish.sh`

**Interfaces:**
- The existing right-anchor test must still assert source order and calendar icon, but now the calendar item's own background is off and the bracket owns the pill background/border.

- [ ] **Step 1: Run existing test to see failure.** `tests/chezmoi/test-sketchybar-right-anchor-polish.sh` should fail on old individual-background expectations after Task 2.
- [ ] **Step 2: Update expectations.** Assert `--add bracket calendar_group`, `background.border_color=0xff00ffff`, `background.drawing=on` for bracket log, and `background.drawing=off` for item log.
- [ ] **Step 3: Run GREEN.** Existing right-anchor test should pass.

---

### Task 4: Full verification and dogfood

**Files:**
- Verify changed shell scripts/tests/docs.

**Interfaces:**
- Repo source is verified; live deploy uses either `chezmoi apply` or direct-copy only the SketchyBar files if the known zsh aliases prompt blocks apply.

- [ ] **Step 1: Focused tests.** Run `tests/chezmoi/test-sketchybar-calendar-dots.sh`, `tests/chezmoi/test-sketchybar-calendar-sourcing.sh`, `tests/chezmoi/test-sketchybar-right-anchor-polish.sh`, `tests/chezmoi/test-sketchybar-tailscale-sourcing.sh`.
- [ ] **Step 2: Shellcheck.** Run `shellcheck -e SC1091` on changed scripts/tests.
- [ ] **Step 3: Dry-run chezmoi.** Run `CHEZMOI_ROLE=ephemeral,headless chezmoi apply --source "$PWD" --config=/tmp/chezmoi-calendar-dots.toml --dry-run --verbose --exclude=externals`.
- [ ] **Step 4: Diff hygiene.** Run `git diff --check` and `git status --short`.
- [ ] **Step 5: Optional dogfood.** Copy `items/calendar.sh`, `plugins/calendar.sh`, `plugins/calendar_dots.sh` into `~/.config/sketchybar`, chmod plugins, `sketchybar --reload`, query all calendar items.

---

## Self-Review

- Spec coverage: bracketed split, today-only Swift/EventKit query, bucket colors, grey fallback, ctrl+option+c click, graceful query failure, tests, and dogfood are covered.
- Placeholder scan: no TBD/TODO/fill-in-later tasks remain.
- Interface consistency: names are consistent: `calendar`, `calendar_time`, `cal_dot_fam`, `cal_dot_work`, `cal_dot_per`, `cal_dot_neutral`, `calendar_group`.
