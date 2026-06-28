# SketchyBar calendar today-dots — design

Date: 2026-06-29
Status: Approved (pre-implementation)
Branch: feat/sketchybar-calendar-dots

## Goal

Extend the existing calendar pill on the right side of the SketchyBar so that,
between the date and the time, it shows colored dots indicating which calendar
buckets have at least one event today:

- pink   → "family" bucket (The Couple Calendar)
- orange → "work" bucket (brendan@steadydigital.co, Operations)
- green  → "personal" bucket (mail@brendans.cloud, Calendar, Kalacoma)

When today has no events in any bucket, a single neutral grey dot is shown for
visual consistency (so the dot region never collapses). Clicking any element in
the pill triggers the Itsycal widget via the global hotkey ctrl+option+c. The
event source is EventKit via a bounded Swift script (built-in, reliable, zero extra deps on this host, reads mapped calendars directly; Itsycal itself is not scriptable).

Existing behavior preserved: the pill's text is split as `dd/mm` (calendar item
label) + dots + `HH:MM AM` (separate item icon), all wrapped in one shared
`bracket` so it still reads as a single pill.

## Scope

In scope:

- A sketchybar `bracket` (`calendar_group`) wrapping the existing calendar item
  plus 3 new color-bucket dot items plus 1 new date-time item — one shared pill.
- Today-only EventKit event query (one bucketed plugin).
- 4 dot items: `cal_dot_fam` (pink), `cal_dot_work` (orange), `cal_dot_per`
  (green), `cal_dot_neutral` (grey, shown only when all three colored buckets
  are empty).
- Split the current single calendar item into `calendar` (date label) and
  `calendar_time` (time icon) items so dots sit between them.
- Click action = ctrl+option+c (Itsycal global widget hotkey) via osascript
  System Events keystroke, with `open -a Itsycal` as fallback.
- Tests (stubbed swift + sketchybar): per-bucket dot toggling, the grey
  fallback, date/time label setting, graceful all-dots-off on Calendar error.
- Sourcing test asserting all 5 items + the bracket exist and are sourced.

Out of scope:

- A scrolling hover popup list of upcoming events (YAGNI for this slice; the
  click opens Itsycal's GUI for the full month).
- Events beyond today (the "today only" horizon is explicit).
- Per-event dots (the buckets are "category dots": one dot per color bucket, max
  three colored + one grey fallback, never more).
- Editing/creating calendar events from the bar.
- Carrying event summary or time-of-day text — the pill shows only dots + the
  existing date/time text.

## Source of truth

`EventKit`, run through a bounded `swift -` subprocess by the dots plugin (low frequency). The query filters events whose start is within the local "today" window (midnight ≤ start < tomorrow). Verified against the host (macOS 2026-06-29):
recurring and all-day events present withtoday's date, so a strict today filter
catches them. Each event's owning calendar *name* is the bucket key.

A live run on the host returned, for Mon 2026-06-29:
- The Couple Calendar (2) → pink ✓
- Todoist - #work (1) → ignored by preference
- (no personal/green events today)

## Architecture / components

Mirrors the existing `spaces.sh` left-side pattern: a `sketchybar --add bracket`
groups several items into one pill whose background is drawn by the bracket.

### Items (created in `items/calendar.sh` / replace the current single item)

All grouped by the `calendar_group` bracket; all share the same
`click_script` (the Itsycal hotkey).

- `calendar` (existing, kept): `icon=$ICON_CALENDAR` (cyan glyph),
  `label="dd/mm"` updated by the date/time plugin. `background.drawing=off`
  (the bracket draws the pill). Default icon.color `$CALENDAR_COLOR`, label.color
  `$WHITE`. icon.font `$FONT:Regular:14.0`, label.font `$FONT:Regular:13.0`.
- `cal_dot_fam`   — `icon="●"` (U+25CF), icon.color = pink, single char,
  `label.drawing=off`, `background.drawing=off`, default `drawing=off`.
- `cal_dot_work`  — same, icon.color = `$ORANGE`.
- `cal_dot_per`   — same, icon.color = `$GREEN`.
- `cal_dot_neutral` — same, icon.color = `$GREY`, default `drawing=on`
  (shown initially until the dots plugin runs and decides).
- `calendar_time` — `icon="HH:MM AM"` (label off), updated by the date/time
  plugin; same click_script.

### Bracket: `calendar_group`

```bash
sketchybar --add bracket calendar_group \
    '/calendar$/' '/cal_dot_.*/' '/calendar_time$/' \
  --set calendar_group \
    background.drawing=on \
    background.color="$PILL_BG" \
    background.border_color="$CALENDAR_COLOR" \
    background.border_width=1 \
    background.corner_radius=9 \
    background.height=26 \
    background.padding_left=4 \
    background.padding_right=4
```

SketchyBar bracket regex matching is used (the leading/trailing `$` anchor is
significant; verify exact regex syntax the running sketchybar accepts, fall back
to listing items explicitly if regex misbehaves). The bracket alone draws the
pill; individual items set `background.drawing=off`.

### Plugins

- **`plugins/executable_calendar.sh`** (cheap, `update_freq=15`, subscribed
  `system_woke`): set the date label and the time icon. Subscribed event drives
  both:
  ```bash
  sketchybar --set calendar       label="$(date '+%d/%m')" \
             --set calendar_time  icon="$(date '+%I:%M %p')"
  ```
  15s is enough for minute-precision clock display. No EventKit call here.

- **`plugins/executable_calendar_dots.sh`** (heavier, `update_freq=300`,
  subscribed `system_woke`): runs a bounded Swift/EventKit query that returns one `<calendar name>` line per today event. Shell buckets the names
  into fam/work/per; for each colored dot, `drawing=on` iff its bucket has ≥1
  event, else `drawing=off`. The grey `cal_dot_neutral` is `drawing=on` iff all
  three colored buckets are empty. Failure path (Swift/EventKit query non-zero / Calendar access not granted) → all colored dots off, neutral grey ON (so the pill
  stays visually consistent even during the one-time permission prompt),
  exit 0, no stderr noise.

### `executable_sketchybarrc`

Source `items/calendar.sh` (replaces the existing single calendar item def) in
the right-items section, in the documented position (calendar first → date stays
far-right). The item file owns the bracket, the dots, and the time item.

## Dot layout / overlap

Dots overlap slightly (Itsycal-style layered dots). Each dot item uses negative
`icon.padding_left` / `icon.padding_right` (e.g. `icon.padding_left=-3`,
`icon.padding_right=-3`) so consecutive dots sit closer than their glyph width.
Exact insets tuned during dogfood (`chezmoi apply && sketchybar --reload`) until
the 3-dot cluster reads as Itsycal's category dots. The neutral grey dot uses
the same insets so the slot width is identical empty-or-full.

The `calendar` item keeps `icon.padding_left=8 icon.padding_right=4`; the time
item keeps symmetric padding so the pill's left/right text never overlaps the
dot cluster.

## Colors

- pink — not in the theme palette; hardcoded literal in `items/calendar.sh`
  (e.g. `0xffE36BA0` — pastel-ish magenta; dogfood-tunable). Defined once as
  `DOT_PINK` and referenced by the `cal_dot_fam` item.
- orange — `$ORANGE` (existing palette export).
- green — `$GREEN` (existing palette export).
- grey — `$GREY` (existing palette export).
- pillar/border — `$PILL_BG` / `$CALENDAR_COLOR` (existing exports).

## Data flow

```
sketchybar timer (15s) / system_woke
        ↓
items/calendar.sh wired plugin = plugins/executable_calendar.sh
        ↓
date '+%d/%m'  →  --set calendar label=…
date '+%I:%M %p' → --set calendar_time icon=…

sketchybar timer (300s) / system_woke
        ↓
items/calendar.sh wired plugin = plugins/executable_calendar_dots.sh
        ↓
swift/EventKit: query mapped calendars for today's events, print owning calendar names
        ↓
shell buckets names into fam / work / per
        ↓
for each dot: --set <dot> drawing=on|off
        ↓
grey neutral: drawing=on iff fam & work & per all empty
```

## Permission risks (both graceful; degrade to grey)

1. **Calendar access** — the first dots-plugin run prompts the user to allow
   the Swift/EventKit process Calendar access (System Settings → Privacy & Security → Calendars). Until granted:
   the EventKit query returns an error or times out; the plugin catches it, leaves all colored dots
   off and the grey neutral on, and exits 0 silently. No bar breakage.

2. **Accessibility** — the first click prompts for Accessibility control (so
   sketchybar/osascript can send the ctrl+option+c keystroke via System Events).
   Until granted, the keystroke no-ops; the user can still invoke Itsycal via
   its own menu-bar icon. Fallback `open -a Itsycal` is kept as an *additional*
   safety (documented in the click_script) only if keystroke proves unreliable
   during dogfood — default is the keystroke (matches the user's request to
   trigger the Itsycal *widget*, which `open -a` does not).

## Testing

Two bash tests under `tests/chezmoi/`, following the existing harness style:

1. `test-sketchybar-calendar-dots.sh` — exercises the dots plugin matrix:
   - Stub `swift` to emit canned today-calendar-name lines per scenario:
     none / fam-only / work-only / per-only / all-three / mixed-buckets /
     Calendar-error (non-zero).
   - Stub `sketchybar` to capture `--set` calls.
   - Assert per scenario:
     - each colored dot's `drawing=on|off` matches its bucket's presence;
     - grey neutral `drawing=on` iff no colored bucket is on (else `off`);
     - Calendar-error scenario → all colored off, neutral on.
   - Assert the date/time plugin sets both `calendar` label and `calendar_time`
     icon in a single `--set` invocation pair.
2. `test-sketchybar-calendar-sourcing.sh` — asserts `executable_sketchybarrc`
   sources `items/calendar.sh` (right-items block, first position) and that
   `items/calendar.sh` creates all of: `calendar`, `cal_dot_fam`,
   `cal_dot_work`, `cal_dot_per`, `cal_dot_neutral`, `calendar_time`, and the
   `calendar_group` bracket; and that every dot uses `icon="●"`.

Standard verification alongside the tests:

```bash
shellcheck -e SC1091 \
  dot_config/sketchybar/items/calendar.sh \
  dot_config/sketchybar/plugins/executable_calendar.sh \
  dot_config/sketchybar/plugins/executable_calendar_dots.sh
CHEZMOI_ROLE=ephemeral,headless chezmoi init --source="$PWD" \
  --config=/tmp/chezmoi-ci.toml --apply=false
CHEZMOI_ROLE=ephemeral,headless chezmoi apply --source "$PWD" \
  --config=/tmp/chezmoi-ci.toml --dry-run --verbose --exclude=externals
git diff --check
```

## Risks / open questions

- **Bracket regex syntax**: sketchybar brackets match item names by NSRegular-
  Expression. `/calendar$/`, `/cal_dot_.*/`, `/calendar_time$/` should work
  but the leading/trailing anchors and alternation semantics need a live
  verify during implementation. Fallback: list the 5 item names explicitly
  (the bracket API accepts a list of names, not just regexes) — a more verbose
  but guaranteed-correct form.
- **Pink not in palette**: picked a default `0xffE36BA0`; dogfood-tunable, no
  semantic dependency on the palette (one literal in one file).
- **Keystroke vs open fallback**: ctrl+option+c keystroke to open Itsycal's
  *widget* (the user's request) requires Accessibility permission; `open -a
  Itsycal` opens the *app's calendar window*, not the widget. Default
  keystroke; fall back to `open` only if dogfooding shows keystroke is
  flaky. Recorded here so the implementation doesn't silently swap behaviors.
- **Calendar running**: not required; EventKit reads Calendar data directly.
- **Recurring/all-day events**: verified present withtoday's date on a strict
  today filter, so no special recurring-event handling is needed.

## Non-goals / future slices

- A hover/click popup listing upcoming events beyond today.
- Per-event granularity (one dot per event) — explicitly buckets only.
- Editing or creating calendar events.
- A scoped "next event" glance label — kept the existing date/time text only.
