#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="${TMPDIR:-/tmp}/sketchybar-front-app-separator-test-$$"
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
  GREY=0xff808080 \
  PLUGIN_DIR=/tmp/plugins \
  bash "$ROOT/dot_config/sketchybar/items/front_app.sh"

python3 - "$LOG" <<'PY'
from pathlib import Path
import sys

log = Path(sys.argv[1]).read_text()
assert '--add item front_app_separator left' in log, log
assert '--add item front_app left' in log, log
assert log.index('--add item front_app_separator left') < log.index('--add item front_app left'), log
assert 'front_app_separator icon=⣿' in log, log
assert 'icon.color=0xff808080' in log, log
assert 'label.drawing=off' in log, log
assert 'script=/tmp/plugins/front_app.sh' in log, log
PY
