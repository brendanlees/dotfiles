#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="${TMPDIR:-/tmp}/sketchybar-tailscale-test-$$"
CONFIG="$TMP/config"
BIN="$TMP/bin"
mkdir -p "$CONFIG/plugins" "$BIN"
trap 'rm -rf "$TMP"' EXIT

cat > "$CONFIG/colors.sh" <<'COL'
#!/bin/bash
export GREY=0xff808080
export YELLOW=0xffe3b341
export RED=0xffef4444
export GREEN=0xff22c55e
export WHITE=0xffeeeeee
export LABEL_COLOR=0xffeeeeee
COL

cp "$ROOT/dot_config/sketchybar/plugins/executable_tailscale.sh" "$CONFIG/plugins/tailscale.sh" 2>/dev/null || : > "$CONFIG/plugins/tailscale.sh"
chmod +x "$CONFIG/plugins/tailscale.sh"

cat > "$BIN/sketchybar" <<'SB'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$SKETCHYBAR_STUB_LOG"
SB
chmod +x "$BIN/sketchybar"

cat > "$BIN/tailscale" <<'TS'
#!/usr/bin/env sh
case "$1 $2" in
  "status --json")
    printf '%s\n' "${TS_STATUS_JSON}"
    exit "${TS_STATUS_EXIT:-0}"
    ;;
esac
exit 0
TS
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

# Every asserted field is followed by another --set arg, so a trailing-space
# boundary disambiguates "label=off" from "label=offline" without end-anchors.
assert_field() {
  local scenario="$1"; local field="$2"; local want="$3"
  local log="$TMP/$scenario.log"
  grep -Eq -- "${field}=${want} " "$log" || fail "$scenario: expected ${field}=${want} in $(cat "$log")"
}

assert_hidden() {
  local scenario="$1"
  local log="$TMP/$scenario.log"
  grep -Eq -- "drawing=off " "$log" || fail "$scenario: expected drawing=off in $(cat "$log")"
  if grep -Eq -- "drawing=on " "$log"; then
    fail "$scenario: must not set drawing=on"
  fi
}

# Visible states: drawing=on + label + semantic color on icon AND pill border.
assert_visible() {
  local scenario="$1"; local label="$2"; local color="$3"
  assert_field "$scenario" "drawing" "on"
  assert_field "$scenario" "label" "$label"
  assert_field "$scenario" "icon.color" "$color"
  assert_field "$scenario" "background.border_color" "$color"
}

J_NEEDS_LOGIN='{"BackendState":"NeedsLogin","HaveNodeKey":false,"Self":{"Online":false},"Health":[],"Peer":{}}'
J_STOPPED='{"BackendState":"Stopped","HaveNodeKey":true,"Self":{"Online":false},"Health":["Tailscale is stopped."],"Peer":{}}'
J_RUNNING_OK='{"BackendState":"Running","HaveNodeKey":true,"Self":{"Online":true},"Health":[],"CurrentTailnet":{"Name":"steadydigital.co"},"Peer":{}}'
J_RUNNING_SICK='{"BackendState":"Running","HaveNodeKey":true,"Self":{"Online":true},"Health":["could not connect to the Sydney relay server"],"Peer":{}}'
J_RUNNING_OFFLINE='{"BackendState":"Running","HaveNodeKey":true,"Self":{"Online":false},"Health":[],"Peer":{}}'
J_OTHER_STATE='{"BackendState":"Starting","HaveNodeKey":true,"Self":{"Online":false},"Health":[],"Peer":{}}'

echo "# tailscale plugin state matrix (hide when off/inactive; pill while running; no exit-node)"

# Off / inactive states are hidden.
run_case needs_login "$J_NEEDS_LOGIN"; assert_hidden needs_login
run_case stopped "$J_STOPPED"; assert_hidden stopped

# Running states are visible with a state-tracking pill (icon = :tailscale: token,
# recolored per state by the plugin).
run_case running_healthy "$J_RUNNING_OK"
assert_visible running_healthy "steadydigital.co" "0xff22c55e"

run_case running_unhealthy "$J_RUNNING_SICK"
assert_visible running_unhealthy "could not connect t…" "0xffe3b341"

run_case running_offline "$J_RUNNING_OFFLINE"
assert_visible running_offline "offline" "0xffef4444"

run_case other_state "$J_OTHER_STATE"
assert_visible other_state "starting" "0xffe3b341"

# Broken-machine paths hide.
run_case bad_json 'not-json-at-all'; assert_hidden bad_json

# tailscale exits non-zero
: > "$TMP/nz.log"
SKETCHYBAR_STUB_LOG="$TMP/nz.log" TS_STATUS_JSON='' TS_STATUS_EXIT=5 \
  PATH="$BIN:$PATH" NAME=tailscale CONFIG_DIR="$CONFIG" PLUGIN_DIR="$CONFIG/plugins" \
  bash "$CONFIG/plugins/tailscale.sh"
grep -q -- "--set tailscale drawing=off" "$TMP/nz.log" || fail "nonzero-status: expected drawing=off"
if grep -q -- "--set tailscale drawing=on" "$TMP/nz.log"; then
  fail "nonzero-status: must not set drawing=on"
fi

# tailscale missing from PATH
MBIN="$TMP/mbin"
mkdir -p "$MBIN"
cp "$BIN/sketchybar" "$MBIN/sketchybar"
: > "$TMP/missing.log"
SKETCHYBAR_STUB_LOG="$TMP/missing.log" TS_STATUS_JSON='{}' \
  PATH="$MBIN:/usr/bin:/bin" NAME=tailscale CONFIG_DIR="$CONFIG" PLUGIN_DIR="$CONFIG/plugins" \
  bash "$CONFIG/plugins/tailscale.sh"
grep -q -- "--set tailscale drawing=off" "$TMP/missing.log" || fail "missing-tailscale: expected drawing=off"

# --------------------------------------------------------------------------
# Icon-token guard (host-aware): the item's icon=\":tailscale:\" is rendered by
# sketchybar-app-font via a GSUB ligature. Validate the installed app-font binary
# actually carries the ligature input sequence 'tailscale'. Soft-skips when the
# font / python3 / grep are unavailable (ephemeral,headless non-macOS CI).
# --------------------------------------------------------------------------
if ! command -v python3 >/dev/null 2>&1; then
  echo "skip: icon-token guard needs python3"
else
  python3 - <<'TOKGUARD' || fail "icon-token guard failed (:tailscale: not in installed sketchybar-app-font); see stderr"
import os, shutil, struct, sys
def u16(b,o): return int.from_bytes(b[o:o+2],'big',signed=False)
def u32(b,o): return struct.unpack('>I',b[o:o+4])[0]
# Resolve the app-font the bar actually uses (matches items/tailscale.sh).
fp = None
import subprocess
# Resolve via fc-list by family substring (fc-match family:style can mis-resolve
# in some fontconfig envs); fall back to the standard $HOME/Library/Fonts path.
if shutil.which('fc-list'):
    for line in subprocess.run(['fc-list'],capture_output=True,text=True).stdout.splitlines():
        if 'sketchybar-app-font' in line and ':' in line:
            fp = line.split(':',1)[0].strip(); break
if not fp or not os.path.exists(fp):
    cand = os.path.expanduser('~/Library/Fonts/sketchybar-app-font.ttf')
    fp = cand if os.path.exists(cand) else fp
if not fp or not os.path.exists(fp) or 'app-font' not in (fp or ''):
    print("skip: sketchybar-app-font not installed/resolvable, got:", fp); sys.exit(0)
data = open(fp,'rb').read()
# The ligature input sequence 'tailscale' (and 'spotify' as a sanity anchor) must
# be present in the binary. Missing 'tailscale' => the :tailscale: token won't
# render on this host and the bar shows nothing.
for tok, name in [('tailscale','required'), ('spotify','sanity-anchor')]:
    if tok.encode() not in data:
        print(f"FAIL: '{tok}' ligature input not found in {fp} ({name})", file=sys.stderr)
        sys.exit(1 if name=='required' else 0)
print("ok: :tailscale: ligature input present in", fp)
TOKGUARD
fi

echo "ALL CASES PASSED"
