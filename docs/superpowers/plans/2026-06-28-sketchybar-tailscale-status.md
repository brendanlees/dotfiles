# SketchyBar Tailscale Status Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a right-side, signal-only Tailscale status SketchyBar item that is hidden when Tailscale is healthy and not routing through an exit node, and visible when stopped, unhealthy, needs-login, offline, or when an exit node is in use.

**Architecture:** Keep the existing item/plugin split. `items/tailscale.sh` wires a right-side item with `update_freq=30` and a `system_woke` subscription. `plugins/executable_tailscale.sh` runs `tailscale status --json`, parses it with `python3`, maps state to `(drawing, icon, color, label)`, and emits a single `sketchybar --set "$NAME" ...` call. `executable_sketchybarrc` sources the item between `battery.sh` and `spotify.sh` so right-item reverse-render keeps date far-right and Tailscale visually adjacent to battery.

**Tech Stack:** chezmoi source files, Bash, SketchyBar CLI, `tailscale status --json`, Python 3 for JSON parsing and TSV emission.

## Global Constraints

- Work in `/Users/brendan/.local/share/chezmoi.feat-sketchybar-tailscale-status` on branch `feat/sketchybar-tailscale-status`.
- Do not use `scutil --nc`; `tailscale status --json` is the sole source.
- Hide the item (drawing=off) in the boring state: `Running` + healthy (empty `Health`) + `Self.Online` + no exit node in use.
- Exit node in use takes precedence over health warnings when `BackendState == Running`.
- A peer with `ExitNode == true` is the in-use exit node; label uses that peer's `HostName` truncated before the first `.`.
- Colors come from `colors.sh` (`$GREY $BLUE $YELLOW $RED $LABEL_COLOR`); glyphs are Nerd Font chars defined locally in the plugin.
- `label.color` is `$LABEL_COLOR` (white) for all visible states; the icon carries the semantic color.
- Never spam the bar: `tailscale` missing, `tailscale status --json` non-zero, or unparseable JSON all hide the item and exit 0.
- Poll with `update_freq=30`; subscribe `system_woke`. No click action in this slice.

---

## File Structure

- Create `dot_config/sketchybar/items/tailscale.sh`: right-side SketchyBar item definition (wiring only).
- Create `dot_config/sketchybar/plugins/executable_tailscale.sh`: `tailscale status --json` → state matrix → `sketchybar --set`.
- Modify `dot_config/sketchybar/executable_sketchybarrc`: source `tailscale.sh` between `battery.sh` and `spotify.sh` in the right-items section.
- Create `tests/chezmoi/test-sketchybar-tailscale-status.sh`: focused regression test with stubbed `tailscale` and `sketchybar`.
- Create `tests/chezmoi/test-sketchybar-tailscale-sourcing.sh`: asserts rc sources `tailscale.sh` in the documented order.

---

### Task 1: Tailscale status plugin regression test (TDD red/green)

**Files:**
- Create: `tests/chezmoi/test-sketchybar-tailscale-status.sh`
- Create: `dot_config/sketchybar/plugins/executable_tailscale.sh`

**Interfaces:**
- Consumes: a `colors.sh` that exports `GREY BLUE YELLOW RED LABEL_COLOR` (the test stubs it), the `tailscale` binary (the test stubs it to emit canned JSON), and the `sketchybar` binary (the test stubs it to capture `--set` calls).
- Produces: executable plugin `dot_config/sketchybar/plugins/executable_tailscale.sh` that, given `CONFIG_DIR`, `PLUGIN_DIR`, and `NAME` env vars, calls `sketchybar --set "$NAME" ...` exactly once per invocation.

- [ ] **Step 1: Create the failing test file**

Create `tests/chezmoi/test-sketchybar-tailscale-status.sh` with this exact content:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="${TMPDIR:-/tmp}/sketchybar-tailscale-test-$$"
CONFIG="$TMP/config"
BIN="$TMP/bin"
mkdir -p "$CONFIG/plugins" "$BIN"
trap 'rm -rf "$TMP"' EXIT

cat > "$CONFIG/colors.sh" <<'SH'
#!/bin/bash
export GREY=0xff808080
export BLUE=0xff3b82f6
export YELLOW=0xffe3b341
export RED=0xffef4444
export LABEL_COLOR=0xffeeeeee
SH

cp "$ROOT/dot_config/sketchybar/plugins/executable_tailscale.sh" "$CONFIG/plugins/tailscale.sh" 2>/dev/null || : > "$CONFIG/plugins/tailscale.sh"
chmod +x "$CONFIG/plugins/tailscale.sh"

cat > "$BIN/sketchybar" <<'SH'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$SKETCHYBAR_STUB_LOG"
SH
chmod +x "$BIN/sketchybar"

cat > "$BIN/tailscale" <<'SH'
#!/usr/bin/env sh
case "$1 $2" in
  "status --json")
    printf '%s\n' "${TS_STATUS_JSON}"
    exit "${TS_STATUS_EXIT:-0}"
    ;;
esac
exit 0
SH
chmod +x "$BIN/tailscale"

run_case() {
  local scenario="$1"; local json="$2"; shift 2
  local log="$TMP/$scenario.log"
  : > "$log"
  SKETCHYBAR_STUB_LOG="$log" TS_STATUS_JSON="$json" \
    PATH="$BIN:$PATH" NAME=tailscale CONFIG_DIR="$CONFIG" PLUGIN_DIR="$CONFIG/plugins" \
    bash "$CONFIG/plugins/tailscale.sh"
  echo "--- $scenario ---"
  cat "$log"
}

fail() { echo "FAIL: $*" >&2; exit 1; }

assert_set() {
  local scenario="$1"; local field="$2"; local want="$3"
  local log="$TMP/$scenario.log"
  grep -q -- "--set tailscale $field=$want" "$log" || fail "$scenario: expected --set tailscale $field=$want in $(cat "$log")"
}

assert_hidden() {
  local scenario="$1"
  local log="$TMP/$scenario.log"
  grep -q -- "--set tailscale drawing=off" "$log" || fail "$scenario: expected drawing=off in $(cat "$log")"
  grep -q -- "--set tailscale label=" "$log" || fail "$scenario: expected label= cleared in $(cat "$log")"
}

NL=$'\n'

# Scenario: needs login (no node key)
J_NEEDS_LOGIN='{"BackendState":"NeedsLogin","HaveNodeKey":false,"Self":{"Online":false},"Health":[],"Peer":{}}'
# Scenario: stopped (has key)
J_STOPPED='{"BackendState":"Stopped","HaveNodeKey":true,"Self":{"Online":false},"Health":["Tailscale is stopped."],"Peer":{}}'
# Scenario: running healthy boring
J_RUNNING_OK='{"BackendState":"Running","HaveNodeKey":true,"Self":{"Online":true},"Health":[],"Peer":{}}'
# Scenario: running, exit node in use
J_RUNNING_EXIT='{"BackendState":"Running","HaveNodeKey":true,"Self":{"Online":true,"ExitNode":true},"Health":[],"Peer":{"abc":{"HostName":"vultr-syd01.example.ts.net","ExitNode":true,"Online":true}}}'
# Scenario: running, unhealthy (relay warn)
J_RUNNING_SICK='{"BackendState":"Running","HaveNodeKey":true,"Self":{"Online":true},"Health":["could not connect to the Sydney relay server"],"Peer":{}}'
# Scenario: running, offline
J_RUNNING_OFFLINE='{"BackendState":"Running","HaveNodeKey":true,"Self":{"Online":false},"Health":[],"Peer":{}}'
# Scenario: other backend state
J_OTHER_STATE='{"BackendState":"Starting","HaveNodeKey":true,"Self":{"Online":false},"Health":[],"Peer":{}}'

echo "# tailscale plugin state matrix"

run_case needs_login "$J_NEEDS_LOGIN"
assert_set needs_login "drawing" "on"
assert_set needs_login "label" "login"

run_case stopped "$J_STOPPED"
assert_set stopped "drawing" "on"
assert_set stopped "label" "off"

run_case running_healthy "$J_RUNNING_OK"
assert_hidden running_healthy

run_case running_exit "$J_RUNNING_EXIT"
assert_set running_exit "drawing" "on"
assert_set running_exit "label" "vultr-syd01"

run_case running_unhealthy "$J_RUNNING_SICK"
assert_set running_unhealthy "drawing" "on"
assert_set running_unhealthy "label" "could not connect t…"

run_case running_offline "$J_RUNNING_OFFLINE"
assert_set running_offline "drawing" "on"
assert_set running_offline "label" "offline"

run_case other_state "$J_OTHER_STATE"
assert_set other_state "drawing" "on"
assert_set other_state "label" "starting"

# Scenario: bad JSON
run_case bad_json 'not-json-at-all'
assert_hidden bad_json

# Scenario: tailscale exits non-zero
: > "$TMP/nz.log"
SKETCHYBAR_STUB_LOG="$TMP/nz.log" TS_STATUS_JSON='' TS_STATUS_EXIT=5 \
  PATH="$BIN:$PATH" NAME=tailscale CONFIG_DIR="$CONFIG" PLUGIN_DIR="$CONFIG/plugins" \
  bash "$CONFIG/plugins/tailscale.sh"
grep -q -- "--set tailscale drawing=off" "$TMP/nz.log" || fail "nonzero-status: expected drawing=off"
grep -q -- "--set tailscale drawing=on" "$TMP/nz.log" && fail "nonzero-status: must not set drawing=on"

# Scenario: tailscale missing from PATH
: > "$TMP/missing.log"
SKETCHYBAR_STUB_LOG="$TMP/missing.log" TS_STATUS_JSON='{}' \
  PATH="/usr/bin:/bin" NAME=tailscale CONFIG_DIR="$CONFIG" PLUGIN_DIR="$CONFIG/plugins" \
  bash "$CONFIG/plugins/tailscale.sh"
grep -q -- "--set tailscale drawing=off" "$TMP/missing.log" || fail "missing-tailscale: expected drawing=off"

echo "ALL CASES PASSED"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/chezmoi/test-sketchybar-tailscale-status.sh`
Expected: FAIL — the plugin file does not exist yet (the `cp` falls back to an empty file), so `bash "$CONFIG/plugins/tailscale.sh"` runs nothing and produces no `--set tailscale` lines; `assert_set` fails.

- [ ] **Step 3: Create the plugin (minimal implementation to satisfy the matrix)**

Create `dot_config/sketchybar/plugins/executable_tailscale.sh` with this exact content (glyphs are Nerd Font Private-Use-Area chars; tests compare bytes, rendering is dogfood-verified in Task 3):

```bash
#!/bin/bash

# shellcheck source=../colors.sh
source "$CONFIG_DIR/colors.sh"

# Nerd Font glyphs (dogfood-verify rendering; tests compare bytes).
ICON_TS_LOCK=󰌾
ICON_TS_EXIT=󰢷
ICON_TS_ALERT=󰂚

export TS_COLOR_GREY="$GREY" TS_COLOR_BLUE="$BLUE" TS_COLOR_YELLOW="$YELLOW" TS_COLOR_RED="$RED"
export TS_ICON_LOCK="$ICON_TS_LOCK" TS_ICON_EXIT="$ICON_TS_EXIT" TS_ICON_ALERT="$ICON_TS_ALERT"

if ! command -v tailscale >/dev/null 2>&1; then
  sketchybar --set "$NAME" drawing=off label=""
  exit 0
fi

status_json="$(tailscale status --json 2>/dev/null)" || {
  sketchybar --set "$NAME" drawing=off label=""
  exit 0
}

# Defensive: python3 is part of the expected toolchain (spotify plugin uses it too).
if [ ! -x /usr/bin/python3 ]; then
  sketchybar --set "$NAME" drawing=off label=""
  exit 0
fi

# JSON is passed as argv[1] so the program comes from the heredoc on stdin
# (the spotify plugin uses this same pattern; stdin stays free for the program).
IFS=$'\t' read -r drawing icon color label <<EOF
$(/usr/bin/python3 - "$status_json" <<'PY')
import json
import os
import sys

def env(name):
    return os.environ.get(name, "")

GREY, BLUE, YELLOW, RED = env("TS_COLOR_GREY"), env("TS_COLOR_BLUE"), env("TS_COLOR_YELLOW"), env("TS_COLOR_RED")
ICON_LOCK, ICON_EXIT, ICON_ALERT = env("TS_ICON_LOCK"), env("TS_ICON_EXIT"), env("TS_ICON_ALERT")

def trunc(s, n):
    s = s or ""
    if len(s) > n:
        s = s[: n - 1] + "…"
    return s

try:
    d = json.loads(sys.argv[1])
except Exception:
    print("off\t\t\t")
    raise SystemExit(0)

state = d.get("BackendState", "")
have_key = bool(d.get("HaveNodeKey", False))
self_node = d.get("Self") or {}
online = bool(self_node.get("Online", False))
health = d.get("Health") or []
peers = d.get("Peer") or {}
exit_host = ""
for n in peers.values():
    if n.get("ExitNode"):
        exit_host = n.get("HostName", "") or ""
        break

if not have_key or state == "NeedsLogin":
    print("on\t" + ICON_LOCK + "\t" + GREY + "\tlogin")
elif state == "Stopped":
    print("on\t" + ICON_LOCK + "\t" + GREY + "\toff")
elif state == "Running":
    if exit_host:
        print("on\t" + ICON_EXIT + "\t" + BLUE + "\t" + trunc(exit_host.split(".", 1)[0], 20))
    elif health:
        print("on\t" + ICON_ALERT + "\t" + YELLOW + "\t" + trunc(health[0], 20))
    elif not online:
        print("on\t" + ICON_ALERT + "\t" + RED + "\toffline")
    else:
        print("off\t\t\t")
else:
    print("on\t" + ICON_ALERT + "\t" + YELLOW + "\t" + trunc(state.lower(), 12))
PY
EOF

if [ "$drawing" = "off" ]; then
  sketchybar --set "$NAME" drawing=off label=""
else
  sketchybar --set "$NAME" drawing=on icon="$icon" icon.color="$color" label="$label" label.color="$LABEL_COLOR"
fi
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/chezmoi/test-sketchybar-tailscale-status.sh`
Expected: prints `ALL CASES PASSED`.

If `running_unhealthy` fails on the health truncation, confirm the expected `trunc("could not connect to the Sydney relay server", 20)` equals `could not connect t` + `…` (i.e. `could not connect t…`, 20 chars total). Adjust the expected string in the test only if the truncation math differs; do not weaken the assertion.

- [ ] **Step 5: Commit**

```bash
git add tests/chezmoi/test-sketchybar-tailscale-status.sh dot_config/sketchybar/plugins/executable_tailscale.sh
git commit -m "feat: add sketchybar tailscale status plugin"
```

---

### Task 2: Wire item + source order test (TDD red/green)

**Files:**
- Create: `dot_config/sketchybar/items/tailscale.sh`
- Modify: `dot_config/sketchybar/executable_sketchybarrc`
- Create: `tests/chezmoi/test-sketchybar-tailscale-sourcing.sh`

**Interfaces:**
- Consumes: `ITEM_DIR` and `PLUGIN_DIR` env vars set by `executable_sketchybarrc`; the plugin from Task 1.
- Produces: a right-side item named `tailscale` refreshed every 30s and on `system_woke`; the rc's right-items source order `calendar, battery, tailscale, spotify`.

- [ ] **Step 1: Write the failing sourcing test**

Create `tests/chezmoi/test-sketchybar-tailscale-sourcing.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RC="$ROOT/dot_config/sketchybar/executable_sketchybarrc"
ITEM="$ROOT/dot_config/sketchybar/items/tailscale.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }
[ -f "$ITEM" ] || fail "items/tailscale.sh missing"
[ -x "$ITEM" ] || [ -r "$ITEM" ] || fail "items/tailscale.sh not readable"

# Inspect the rc's right-items block in source order.
order="$(awk '
  /# right items/ {right=1; next}
  right && /^[[:space:]]*source "\$ITEM_DIR\// {
    sub(/.*source "\$ITEM_DIR\//, ""); sub(/".*/, ""); print
  }
  /^# / && right {right=0}
' "$RC")"

expect=$'calendar\nbattery\ntailscale\nspotify'
[ "$order" = "$expect" ] || fail "right source order wrong: got <$order> want <$expect>"

grep -q 'sketchybar --add item tailscale right' "$ITEM" || fail "item not added on right"
grep -q 'update_freq=30' "$ITEM" || fail "missing update_freq=30"
grep -q 'system_woke' "$ITEM" || fail "missing system_woke subscription"
grep -q -- "--set tailscale" "$ITEM" || fail "missing --set tailscale"

echo "SOURCING OK"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/chezmoi/test-sketchybar-tailscale-sourcing.sh`
Expected: FAIL — `items/tailscale.sh` missing, and rc does not source it yet.

- [ ] **Step 3: Create the item file**

Create `dot_config/sketchybar/items/tailscale.sh`:

```bash
#!/bin/bash

sketchybar --add item tailscale right \
  --set tailscale \
    update_freq=30 \
    script="$PLUGIN_DIR/tailscale.sh" \
  --subscribe tailscale system_woke
```

- [ ] **Step 4: Wire the item into the rc**

Modify `dot_config/sketchybar/executable_sketchybarrc`. In the right-items section, replace this block:

```bash
source "$ITEM_DIR/calendar.sh"
source "$ITEM_DIR/battery.sh"
# source "$ITEM_DIR/app_soundsource.sh" # shelved for now
source "$ITEM_DIR/spotify.sh"
```

with:

```bash
source "$ITEM_DIR/calendar.sh"
source "$ITEM_DIR/battery.sh"
source "$ITEM_DIR/tailscale.sh"
# source "$ITEM_DIR/app_soundsource.sh" # shelved for now
source "$ITEM_DIR/spotify.sh"
```

- [ ] **Step 5: Run the sourcing test to verify it passes**

Run: `bash tests/chezmoi/test-sketchybar-tailscale-sourcing.sh`
Expected: `SOURCING OK`.

- [ ] **Step 6: Re-run the plugin test to confirm no regression**

Run: `bash tests/chezmoi/test-sketchybar-tailscale-status.sh`
Expected: `ALL CASES PASSED`.

Also re-run the existing right-anchor polished test to confirm the new item did not break documented right-side ordering expectations:

Run: `bash tests/chezmoi/test-sketchybar-right-anchor-polish.sh`
Expected: PASS (if it asserts the full right-side order, verify/update expectations there to include `tailscale` in the documented position; if it only asserts calendar far-right, no change needed).

- [ ] **Step 7: Commit**

```bash
git add dot_config/sketchybar/items/tailscale.sh dot_config/sketchybar/executable_sketchybarrc tests/chezmoi/test-sketchybar-tailscale-sourcing.sh
git commit -m "feat: wire sketchybar tailscale item on right"
```

---

### Task 3: Lint, chezmoi dry-run, dogfood verification

**Files:**
- Verify only (no new files unless a glyph swap is needed).

- [ ] **Step 1: Shellcheck the touched shell files**

Run:
```bash
shellcheck -e SC1091 \
  dot_config/sketchybar/items/tailscale.sh \
  dot_config/sketchybar/plugins/executable_tailscale.sh \
  dot_config/sketchybar/executable_sketchybarrc \
  tests/chezmoi/test-sketchybar-tailscale-status.sh \
  tests/chezmoi/test-sketchybar-tailscale-sourcing.sh
```
Expected: no output (clean).

- [ ] **Step 2: Chezmoi render/dry-run on an ephemeral role**

Run:
```bash
CHEZMOI_ROLE=ephemeral,headless chezmoi init --source="$PWD" \
  --config=/tmp/chezmoi-ci.toml --apply=false
CHEZMOI_ROLE=ephemeral,headless chezmoi apply --source "$PWD" \
  --config=/tmp/chezmoi-ci.toml --dry-run --verbose --exclude=externals
```
Expected: init succeeds; dry-run applies `tailscale.sh` and the rc change with no errors and no unintended diffs.

- [ ] **Step 3: Verify the plugin against live Tailscale state (dogfood)**

Run on the host (real tailscale):
```bash
CONFIG_DIR="$HOME/.config/sketchybar" PLUGIN_DIR="$HOME/.config/sketchybar/plugins" \
  NAME=tailscale bash dot_config/sketchybar/plugins/executable_tailscale.sh
echo "exit=$?"
```
Expected: with Tailscale currently Stopped, the `--set tailscale` line shows `drawing=on label=off`. Confirm the icon glyph renders (not tofu) in a real terminal that uses JetBrainsMono Nerd Font Mono.

- [ ] **Step 4: Apply and reload SketchyBar, eyeball the bar**

Run on the host:
```bash
chezmoi apply
sketchybar --reload
```
Watch specifically:
- Tailscale item visible to the left of battery, with the stop/lock glyph and `off` label while Tailscale is stopped.
- When you run `tailscale up` (then back to healthy, no exit node), the item disappears (drawing=off).
- Date stays far-right; Spotify still appears left of Tailscale when playing.

- [ ] **Step 5: Exit-node flag dogfood (validate spec risk)**

Toggle an exit node on, then:
```bash
CONFIG_DIR="$HOME/.config/sketchybar" PLUGIN_DIR="$HOME/.config/sketchybar/plugins" \
  NAME=tailscale bash dot_config/sketchybar/plugins/executable_tailscale.sh
```
Watch specifically:
- The `--set tailscale` line shows `drawing=on`, an exit glyph, and a label equal to the exit-node `HostName` before the first `.`.
If the chosen peer does not have `ExitNode == true` (the spec risk), fall back to parsing `tailscale exit-node list` for the in-use exit node and update the plugin + test's canned JSON accordingly. Record the finding in the spec's Risks section if behavior differs.

- [ ] **Step 6: Glyph tofu check + swap if needed**

If any of the three glyphs (lock `󰌾`, exit `󰢷`, alert `󰂚`) renders as tofu in the live bar, swap that literal char in `dot_config/sketchybar/plugins/executable_tailscale.sh` for a Nerd Font glyph that renders, and update the corresponding expected glyph is NOT needed in the tests (tests compare bytes via the plugin's own literals only where they assert label/drawing/color, never the icon glyph bytes — verify the tests do not assert icon-glyph equality before relying on this). Re-run Task 1 and Task 2 tests after any swap.

- [ ] **Step 7: git diff --check and final review**

Run:
```bash
git diff --check
git status -sb
```
Expected: no whitespace errors; clean staged state aside from any glyph-swap edits.

- [ ] **Step 8: Append dogfood finding + close**

No commit needed unless a glyph swap or exit-node fix touched files. If files changed:
```bash
git add -p
git commit -m "fix: dogfood sketchybar tailscale glyph/exit-node"
```

---

## Done criteria

- `test-sketchybar-tailscale-status.sh` passes all matrix rows + tailscale-missing/non-zero/bad-JSON.
- `test-sketchybar-tailscale-sourcing.sh` passes; `test-sketchybar-right-anchor-polish.sh` still passes.
- `shellcheck -e SC1091` clean on the five touched shell files.
- `chezmoi apply --dry-run` clean under the ephemeral,headless role.
- Live bar: Tailscale hidden when healthy+online+no-exit-node; visible with `off` while stopped; visible with exit glyph + host label when an exit node is active; glyphs render (no tofu).
