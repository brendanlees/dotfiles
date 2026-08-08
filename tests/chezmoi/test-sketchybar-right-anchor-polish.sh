#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_ROOT="$ROOT/home"
RC="$SOURCE_ROOT/dot_config/sketchybar/executable_sketchybarrc"
CALENDAR="$SOURCE_ROOT/dot_config/sketchybar/items/calendar.sh"
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

assert source_lines == [
    'source "$ITEM_DIR/spaces.sh"',
    'source "$ITEM_DIR/front_app.sh"',
    'source "$ITEM_DIR/calendar.sh"',
    'source "$ITEM_DIR/battery.sh"',
    'source "$ITEM_DIR/backup_status.sh"',
    'source "$ITEM_DIR/tailscale.sh"',
    'source "$ITEM_DIR/spotify.sh"',
], source_lines
PY

cat > "$BIN/sketchybar" <<'SH'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$SKETCHYBAR_STUB_LOG"
SH
chmod +x "$BIN/sketchybar"

PATH="$BIN:$PATH" \
  SKETCHYBAR_STUB_LOG="$LOG" \
  FONT="JetBrainsMono Nerd Font Mono" \
  ICON_CALENDAR=CAL \
  ICON_CLOCK=CLOCK \
  CALENDAR_COLOR=0xff00ffff \
  WHITE=0xffffffff \
  SURFACE=0xff262626 \
  PILL_BG=0x88262626 \
  PILL_HEIGHT=36 \
  BORDER_RADIUS=8 \
  ITEM_PADDING=8 \
  PLUGIN_DIR=/tmp/plugins \
  bash "$CALENDAR"

python3 - "$LOG" <<'PY'
from pathlib import Path
import sys

log = Path(sys.argv[1]).read_text()
assert '--add item calendar right' in log, log
assert 'icon=CAL' in log, log
assert 'icon.color=0xff00ffff' in log, log
assert 'background.border_color=0xff262626' in log, log
assert 'background.drawing=on' in log, log
assert 'icon.drawing=off' not in log, log
assert 'script=/tmp/plugins/calendar.sh' in log, log
PY
