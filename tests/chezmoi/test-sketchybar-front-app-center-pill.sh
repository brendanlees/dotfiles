#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_ROOT="$ROOT/home"
TMP="${TMPDIR:-/tmp}/sketchybar-front-app-center-pill-test-$$"
BIN="$TMP/bin"
LOG="$TMP/sketchybar.log"
mkdir -p "$BIN"
trap 'rm -rf "$TMP"' EXIT

cat > "$BIN/sketchybar" <<'SH'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$SKETCHYBAR_STUB_LOG"
SH
chmod +x "$BIN/sketchybar"

PATH="$BIN:$PATH" \
  SKETCHYBAR_STUB_LOG="$LOG" \
  FONT="JetBrainsMono Nerd Font Mono" \
  WHITE=0xffffffff \
  SURFACE=0xff262626 \
  ITEM_PADDING=8 \
  BORDER_RADIUS=8 \
  PILL_HEIGHT=36 \
  PLUGIN_DIR=/tmp/plugins \
  bash "$SOURCE_ROOT/dot_config/sketchybar/items/front_app.sh"

python3 - "$LOG" <<'PY'
from pathlib import Path
import sys

log = Path(sys.argv[1]).read_text()
assert '--add item front_app center' in log, log
assert 'front_app_separator' not in log, log
assert 'background.drawing=on' in log, log
assert 'background.color=0xff262626' in log, log
assert 'background.border_color=0xff262626' in log, log
assert 'background.corner_radius=8' in log, log
assert 'background.height=36' in log, log
assert 'icon.font=sketchybar-app-font:Regular:11.0' in log, log
assert 'icon.color=0xffffffff' in log, log
assert 'label.color=0xffffffff' in log, log
assert 'script=/tmp/plugins/front_app.sh' in log, log
assert 'front_app_switched' in log, log
PY
