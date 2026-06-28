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
export BLUE=0xff3b82f6
export YELLOW=0xffe3b341
export RED=0xffef4444
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

assert_set() {
  # Every asserted field is followed by another --set arg in the captured line,
  # so a trailing-space boundary disambiguates "label=off" from "label=offline"
  # without relying on regex end-anchors (label values may contain spaces).
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

J_NEEDS_LOGIN='{"BackendState":"NeedsLogin","HaveNodeKey":false,"Self":{"Online":false},"Health":[],"Peer":{}}'
J_STOPPED='{"BackendState":"Stopped","HaveNodeKey":true,"Self":{"Online":false},"Health":["Tailscale is stopped."],"Peer":{}}'
J_RUNNING_OK='{"BackendState":"Running","HaveNodeKey":true,"Self":{"Online":true},"Health":[],"Peer":{}}'
J_RUNNING_EXIT='{"BackendState":"Running","HaveNodeKey":true,"Self":{"Online":true,"ExitNode":true},"Health":[],"Peer":{"abc":{"HostName":"vultr-syd01.example.ts.net","ExitNode":true,"Online":true}}}'
J_RUNNING_SICK='{"BackendState":"Running","HaveNodeKey":true,"Self":{"Online":true},"Health":["could not connect to the Sydney relay server"],"Peer":{}}'
J_RUNNING_OFFLINE='{"BackendState":"Running","HaveNodeKey":true,"Self":{"Online":false},"Health":[],"Peer":{}}'
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

run_case bad_json 'not-json-at-all'
assert_hidden bad_json

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
: > "$TMP/missing.log"
# "tailscale missing": PATH has the sketchybar stub (in its own dir) but no
# tailscale binary anywhere, so the plugin's missing-binary hide guard fires.
MBIN="$TMP/mbin"
mkdir -p "$MBIN"
cp "$BIN/sketchybar" "$MBIN/sketchybar"
SKETCHYBAR_STUB_LOG="$TMP/missing.log" TS_STATUS_JSON='{}' \
  PATH="$MBIN:/usr/bin:/bin" NAME=tailscale CONFIG_DIR="$CONFIG" PLUGIN_DIR="$CONFIG/plugins" \
  bash "$CONFIG/plugins/tailscale.sh"
grep -q -- "--set tailscale drawing=off" "$TMP/missing.log" || fail "missing-tailscale: expected drawing=off"

echo "ALL CASES PASSED"
