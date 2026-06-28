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
export GREEN=0xff22c55e
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
# boundary disambiguates "label=off" from "label=offline" without end-anchors
# (label values may contain spaces).
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

# Visible states: drawing=on + label + semantic color on both icon AND pill border.
assert_visible() {
  local scenario="$1"; local label="$2"; local color="$3"
  local log="$TMP/$scenario.log"
  assert_field "$scenario" "drawing" "on"
  assert_field "$scenario" "label" "$label"
  assert_field "$scenario" "icon.color" "$color"
  assert_field "$scenario" "background.border_color" "$color"
  # icon must carry a glyph (regression guard: an empty icon= once slipped through
  # because only icon.color was asserted). Match "icon=" followed by a non-space.
  grep -Eq -- "icon=[^ ]" "$log" || fail "$scenario: icon glyph is empty in $(cat "$log")"
}

J_NEEDS_LOGIN='{"BackendState":"NeedsLogin","HaveNodeKey":false,"Self":{"Online":false},"Health":[],"Peer":{}}'
J_STOPPED='{"BackendState":"Stopped","HaveNodeKey":true,"Self":{"Online":false},"Health":["Tailscale is stopped."],"Peer":{}}'
J_RUNNING_OK='{"BackendState":"Running","HaveNodeKey":true,"Self":{"Online":true},"Health":[],"CurrentTailnet":{"Name":"steadydigital.co"},"Peer":{}}'
J_RUNNING_EXIT='{"BackendState":"Running","HaveNodeKey":true,"Self":{"Online":true,"ExitNode":true},"Health":[],"Peer":{"abc":{"HostName":"vultr-syd01.example.ts.net","ExitNode":true,"Online":true}}}'
J_RUNNING_SICK='{"BackendState":"Running","HaveNodeKey":true,"Self":{"Online":true},"Health":["could not connect to the Sydney relay server"],"Peer":{}}'
J_RUNNING_OFFLINE='{"BackendState":"Running","HaveNodeKey":true,"Self":{"Online":false},"Health":[],"Peer":{}}'
J_OTHER_STATE='{"BackendState":"Starting","HaveNodeKey":true,"Self":{"Online":false},"Health":[],"Peer":{}}'

echo "# tailscale plugin state matrix (hide when off/inactive; pill while running)"

# Off / inactive states are hidden.
run_case needs_login "$J_NEEDS_LOGIN"; assert_hidden needs_login
run_case stopped "$J_STOPPED"; assert_hidden stopped

# Running states are visible with a state-tracking pill.
run_case running_healthy "$J_RUNNING_OK"
assert_visible running_healthy "steadydigital.co" "0xff22c55e"

run_case running_exit "$J_RUNNING_EXIT"
assert_visible running_exit "vultr-syd01" "0xff3b82f6"

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
# Font-glyph-validity guard (host-aware; catches the class of bug where a chosen
# Nerd Font codepoint maps to .notdef and renders blank in the bar). Reads the
# plugin file's actual ICON_TS_* glyph literals and asserts each maps to a real
# (non-.notdef) glyph in JetBrainsMono Nerd Font Mono Bold. Soft-skips (exit 0)
# when fc-match / the font / python3 are unavailable (ephemeral,headless non-macOS
# CI). A genuine .notdef mapping exits 1 and FAILS the test (not swallowed).
if ! command -v python3 >/dev/null 2>&1; then
  echo "skip: font glyph-validity guard needs python3"
else
  GLYPHGUARD_PLUGIN="$ROOT/dot_config/sketchybar/plugins/executable_tailscale.sh" python3 - <<'GLYPHGUARD' || fail "font glyph-validity guard failed (a chosen glyph maps to .notdef); see stderr"
import sys, struct, subprocess, shutil, os
def u16(b,o): return int.from_bytes(b[o:o+2],'big',signed=False)
def u32(b,o): return struct.unpack('>I', b[o:o+4])[0]
plugin = os.environ.get("GLYPHGUARD_PLUGIN","")
if not plugin or not os.path.exists(plugin):
    print("skip: plugin path not found:", plugin); sys.exit(0)
src = open(plugin, encoding="utf-8").read()
glyphs = {}
for m in __import__("re").finditer(r'^ICON_TS_([A-Z]+)=(\S)', src, __import__("re").MULTILINE):
    name, first = m.group(1), m.group(2)
    if first == "$":  # byte-escape form, not a literal; cannot validate
        print("skip: plugin uses a byte-escape glyph literal; cannot validate", file=sys.stderr)
        sys.exit(0)
    glyphs["TS_" + name] = ord(first)
if not glyphs:
    print("skip: no ICON_TS_* literals found in plugin"); sys.exit(0)
if not shutil.which("fc-match"):
    print("skip: fc-match not on PATH"); sys.exit(0)
fp = subprocess.run(["fc-match","-f","%{file}","JetBrainsMono Nerd Font Mono:Bold"],
                    capture_output=True, text=True).stdout.strip()
if not fp or "Nerd" not in fp:
    print("skip: JetBrainsMono Nerd Font Mono not resolved, got:", fp); sys.exit(0)
try:
    b = open(fp,"rb").read()
except OSError as e:
    print("skip: font file unreadable:", e); sys.exit(0)
ntabs = u16(b,4); tables={}
for i in range(ntabs):
    rec = 12+i*16; tag = b[rec:rec+4].decode("latin1"); tables[tag] = (u32(b,rec+8), u32(b,rec+12))
if "cmap" not in tables or "maxp" not in tables:
    print("skip: font missing cmap/maxp"); sys.exit(0)
numGlyphs = u16(b, tables["maxp"][0]+4)
cmap_off = tables["cmap"][0]; nsub = u16(b, cmap_off+2)
f12base = None; o = cmap_off+4
for _ in range(nsub):
    base = cmap_off + u32(b,o+4)
    if u16(b,base) == 12: f12base = base
    o += 8
if f12base is None:
    print("skip: no format-12 cmap subtable"); sys.exit(0)
ngrp = u32(b, f12base+12)
def gid(cp):
    for g in range(ngrp):
        off = f12base + 16 + g*12
        sc=u32(b,off); ec=u32(b,off+4); sg=u32(b,off+8)
        if sc <= cp <= ec: return sg + (cp - sc)
    return 0
bad = []
for name, cp in glyphs.items():
    g = gid(cp)
    if not (0 < g < numGlyphs):
        bad.append(f"{name} U+{cp:04X} -> gid={g} (.notdef/invalid)")
if bad:
    for x in bad: print("FAIL: glyph not real in", fp, ":", x, file=sys.stderr)
    sys.exit(1)
print("ok: all tailscale glyphs map to real outlines in", fp)
GLYPHGUARD
fi


echo "ALL CASES PASSED"
