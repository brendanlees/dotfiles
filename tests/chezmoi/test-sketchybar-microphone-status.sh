#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_ROOT="$ROOT/home"
ITEM="$SOURCE_ROOT/dot_config/sketchybar/items/microphone.sh"
BALANCE_ITEM="$SOURCE_ROOT/dot_config/sketchybar/items/microphone_balance.sh"
PLUGIN="$SOURCE_ROOT/dot_config/sketchybar/plugins/executable_microphone.sh"
HELPER_SOURCE="$SOURCE_ROOT/dot_config/sketchybar/helpers/mic_activity.c"
RC="$SOURCE_ROOT/dot_config/sketchybar/executable_sketchybarrc"
TMP="${TMPDIR:-/tmp}/sketchybar-microphone-test-$$"
CONFIG="$TMP/config"
BIN="$TMP/bin"
mkdir -p "$CONFIG" "$BIN"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

cat > "$BIN/sketchybar" <<'SB'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$SKETCHYBAR_STUB_LOG"
SB
chmod +x "$BIN/sketchybar"

# Item configuration: the icon sits beside the focused app in the center,
# starts hidden, and updates only in response to native watcher events.
item_log="$TMP/item.log"
PATH="$BIN:$PATH" \
  SKETCHYBAR_STUB_LOG="$item_log" \
  ICON_MICROPHONE=MIC \
  MICROPHONE_ACTIVE_COLOR=0xffff453a \
  WHITE=0xffffffff \
  PLUGIN_DIR=/tmp/plugins \
  bash "$BALANCE_ITEM"
PATH="$BIN:$PATH" \
  SKETCHYBAR_STUB_LOG="$item_log" \
  MICROPHONE_ACTIVE_COLOR=0xffff453a \
  WHITE=0xffffffff \
  ICON_MICROPHONE=MIC \
  PLUGIN_DIR=/tmp/plugins \
  bash "$ITEM"

grep -q -- '--add item microphone_balance center' "$item_log" || fail 'microphone counterweight is not centered'
grep -q -- '--set microphone_balance drawing=off width=28' "$item_log" || fail 'microphone counterweight width changed'
grep -q -- '--add item microphone center' "$item_log" || fail 'microphone item is not centered'
grep -q -- 'drawing=off' "$item_log" || fail 'microphone item must start hidden'
grep -q -- 'width=28' "$item_log" || fail 'microphone circle width changed'
grep -q -- 'align=center' "$item_log" || fail 'microphone content must be centered in its fixed width'
grep -q -- 'icon=MIC' "$item_log" || fail 'microphone icon missing'
grep -q -- 'icon.color=0xffffffff' "$item_log" || fail 'microphone icon must contrast in white'
grep -q -- 'background.color=0xffff453a' "$item_log" || fail 'active circle must use fixed signal red'
grep -q -- 'background.corner_radius=14' "$item_log" || fail 'microphone background must be circular'
grep -q -- 'background.height=28' "$item_log" || fail 'microphone circle height changed'
grep -q -- 'label.drawing=off' "$item_log" || fail 'microphone must remain icon-only'
grep -q -- 'update_freq=0' "$item_log" || fail 'microphone must not poll'
grep -q -- 'microphone_change' "$item_log" || fail 'microphone event subscription missing'
grep -q -- 'script=/tmp/plugins/microphone.sh' "$item_log" || fail 'microphone plugin missing'
grep -q -- 'sketchybar --add event microphone_change' "$RC" || fail 'custom event is not registered'
# A transport/helper process can claim running input without owning an input
# device (Rogue Amoeba arkaudiod reproduced this). It must not light the icon.
grep -Fq -- 'running != 0 && process_has_input_device(processes[i])' "$HELPER_SOURCE" || \
  fail 'active-process detection must require a concrete input device'
# TONOR powers off by disappearing from CoreAudio and powers on as a live USB
# input before an application opens a capture stream.
grep -Fq -- 'process_active || any_device_uses_input() || any_live_usb_input()' "$HELPER_SOURCE" || \
  fail 'powered USB microphones must count as live input'
center_order="$(awk '
  /# center items/ {center=1; next}
  /^# right items/ {center=0}
  center && /^[[:space:]]*source "\$ITEM_DIR\// {
    sub(/.*source "\$ITEM_DIR\//, ""); sub(/\.sh".*/, ""); print
  }
' "$RC")"
[[ $center_order == $'microphone_balance\nfront_app\nmicrophone' ]] || \
  fail "center source order wrong: got <$center_order>"

cat > "$CONFIG/colors.sh" <<'COL'
#!/bin/bash
export MICROPHONE_ACTIVE_COLOR=0xffff453a
export WHITE=0xffffffff
COL

cat > "$BIN/mic-active" <<'SH'
#!/usr/bin/env sh
printf '%s\n' active
SH
cat > "$BIN/mic-inactive" <<'SH'
#!/usr/bin/env sh
printf '%s\n' inactive
SH
cat > "$BIN/mic-error" <<'SH'
#!/usr/bin/env sh
exit 1
SH
cat > "$BIN/mic-watchable" <<'SH'
#!/usr/bin/env sh
if [ "${1:-}" = "--watch" ]; then
  printf '%s\n' "$*" > "$MIC_WATCH_LOG"
  exit 0
fi
printf '%s\n' active
SH
chmod +x "$BIN/mic-active" "$BIN/mic-inactive" "$BIN/mic-error" "$BIN/mic-watchable"

run_case() {
  local scenario="$1"
  local helper="$2"
  local log="$TMP/$scenario.log"
  : > "$log"
  PATH="$BIN:$PATH" \
    SKETCHYBAR_STUB_LOG="$log" \
    MIC_ACTIVITY_HELPER="$helper" \
    MIC_WATCHER_DISABLE=1 \
    NAME=microphone \
    CONFIG_DIR="$CONFIG" \
    bash "$PLUGIN"
}

run_case active "$BIN/mic-active"
grep -q -- '--set microphone drawing=on icon.color=0xffffffff background.color=0xffff453a --set microphone_balance drawing=on' "$TMP/active.log" || \
  fail "active input must show a white mic in a red circle with its counterweight: $(cat "$TMP/active.log")"

run_case inactive "$BIN/mic-inactive"
grep -q -- '--set microphone drawing=off --set microphone_balance drawing=off' "$TMP/inactive.log" || \
  fail "inactive input must hide the icon and counterweight: $(cat "$TMP/inactive.log")"

run_case error "$BIN/mic-error"
grep -q -- '--set microphone drawing=off --set microphone_balance drawing=off' "$TMP/error.log" || \
  fail "helper errors must hide the icon and counterweight: $(cat "$TMP/error.log")"

run_event() {
  local scenario="$1"
  local active="$2"
  local log="$TMP/$scenario.log"
  : > "$log"
  PATH="$BIN:$PATH" \
    SKETCHYBAR_STUB_LOG="$log" \
    SENDER=microphone_change \
    MIC_ACTIVE="$active" \
    NAME=microphone \
    CONFIG_DIR="$CONFIG" \
    bash "$PLUGIN"
}

run_event event_active 1
grep -q -- '--set microphone drawing=on icon.color=0xffffffff background.color=0xffff453a --set microphone_balance drawing=on' "$TMP/event_active.log" || \
  fail "active event must show the balanced white mic in a red circle: $(cat "$TMP/event_active.log")"
run_event event_inactive 0
grep -q -- '--set microphone drawing=off --set microphone_balance drawing=off' "$TMP/event_inactive.log" || \
  fail "inactive event must hide the icon and counterweight: $(cat "$TMP/event_inactive.log")"

# SketchyBar and interactive shells can have different XDG environments. The
# watcher must still converge on one stable macOS cache and lock path.
watch_log="$TMP/mock-watcher.log"
HOME="$TMP/home" \
  XDG_CACHE_HOME="$TMP/xdg-cache" \
  PATH="$BIN:$PATH" \
  SKETCHYBAR_STUB_LOG="$TMP/watch-start-sketchybar.log" \
  MIC_ACTIVITY_HELPER="$BIN/mic-watchable" \
  MIC_WATCH_LOG="$watch_log" \
  NAME=microphone \
  CONFIG_DIR="$CONFIG" \
  bash "$PLUGIN"
for _ in 1 2 3 4 5 6 7 8 9 10; do
  [[ -s $watch_log ]] && break
  sleep 0.05
done
grep -q -- "--watch $TMP/home/Library/Caches/sketchybar/mic_activity.lock $BIN/sketchybar" "$watch_log" || \
  fail "watcher did not use the stable macOS cache path: $(cat "$watch_log" 2>/dev/null || true)"
[[ ! -e $TMP/xdg-cache/sketchybar/mic_activity.lock ]] || \
  fail 'watcher lock must not depend on XDG_CACHE_HOME'

# Compile and launch the real CoreAudio event provider where available. Runtime
# activity is host-dependent, but it must immediately publish one valid event.
if [[ $(uname -s) == Darwin ]] && command -v xcrun >/dev/null 2>&1; then
  xcrun clang -O2 -Wall -Wextra -Werror -framework CoreAudio \
    -framework CoreFoundation "$HELPER_SOURCE" -o "$TMP/mic_activity"
  state="$("$TMP/mic_activity")"
  [[ $state == active || $state == inactive ]] || fail "unexpected helper state: $state"

  watcher_log="$TMP/watcher.log"
  : > "$watcher_log"
  SKETCHYBAR_STUB_LOG="$watcher_log" \
    "$TMP/mic_activity" --watch "$TMP/watcher.lock" "$BIN/sketchybar" &
  watcher_pid=$!
  published=0
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 \
    21 22 23 24 25 26 27 28 29 30; do
    if grep -q -- '--trigger microphone_change MIC_ACTIVE=' "$watcher_log"; then
      published=1
      break
    fi
    sleep 0.1
  done
  kill "$watcher_pid" 2>/dev/null || true
  wait "$watcher_pid" 2>/dev/null || true
  [[ $published == 1 ]] || fail 'watcher did not publish its initial state'
else
  echo 'skip: CoreAudio helper compile requires macOS and xcrun'
fi

echo 'MICROPHONE STATUS OK'
