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
