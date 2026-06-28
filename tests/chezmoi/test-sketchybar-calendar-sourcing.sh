#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RC="$ROOT/dot_config/sketchybar/executable_sketchybarrc"
ITEM="$ROOT/dot_config/sketchybar/items/calendar.sh"
TMP="${TMPDIR:-/tmp}/sketchybar-calendar-sourcing-test-$$"
BIN="$TMP/bin"
LOG="$TMP/sketchybar.log"
mkdir -p "$BIN"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
[ -f "$ITEM" ] || fail "items/calendar.sh missing"

order="$(awk '
  /# right items/ {right=1; next}
  /^# finalise/ {right=0}
  right && /^[[:space:]]*source "\$ITEM_DIR\// {
    sub(/.*source "\$ITEM_DIR\//, ""); sub(/\.sh".*/, ""); print
  }
' "$RC")"
expect=$'calendar\nbattery\ntailscale\nspotify'
[ "$order" = "$expect" ] || fail "right source order wrong: got <$order> want <$expect>"

cat > "$BIN/sketchybar" <<'SB'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$SKETCHYBAR_STUB_LOG"
SB
chmod +x "$BIN/sketchybar"

PATH="$BIN:$PATH" \
  SKETCHYBAR_STUB_LOG="$LOG" \
  FONT="JetBrainsMono Nerd Font Mono" \
  ICON_CALENDAR=CAL \
  CALENDAR_COLOR=0xff00ffff \
  WHITE=0xffffffff \
  GREY=0xff808080 \
  GREEN=0xff22c55e \
  ORANGE=0xfff97316 \
  PILL_BG=0x88262626 \
  PLUGIN_DIR=/tmp/plugins \
  bash "$ITEM"

python3 - "$LOG" <<'PY'
from pathlib import Path
import sys
log = Path(sys.argv[1]).read_text()
for name in ['calendar', 'cal_dot_fam', 'cal_dot_work', 'cal_dot_per', 'cal_dot_neutral', 'calendar_time']:
    assert f'--add item {name} right' in log, (name, log)
assert '--add bracket calendar_group' in log, log
assert 'background.color=0x88262626' in log, log
assert 'background.border_color=0xff00ffff' in log, log
assert 'icon=CAL' in log, log
assert 'label.color=0xffffffff' in log, log
assert 'script=/tmp/plugins/calendar.sh' in log, log
assert 'script=/tmp/plugins/calendar_dots.sh' in log, log
assert 'update_freq=15' in log, log
assert 'update_freq=300' in log, log
assert 'icon=●' in log, log
assert 'icon.color=0xff808080' in log, log
assert 'icon.color=0xff22c55e' in log, log
assert 'icon.color=0xfff97316' in log, log
assert '0xffE36BA0' in log, log
assert 'osascript -e' in log and 'control down' in log and 'option down' in log, log
assert 'open -a Itsycal' in log, log
assert 'background.drawing=off' in log, log
PY

echo 'SOURCING OK'
