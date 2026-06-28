#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="${TMPDIR:-/tmp}/sketchybar-soundsource-launcher-test-$$"
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
  ICON_COLOR=0xffffffff \
  ICON_VOLUME_UNKNOWN=󰕾 \
  bash "$ROOT/dot_config/sketchybar/items/app_soundsource.sh"

python3 - "$LOG" <<'PY'
import pathlib
import sys
log = pathlib.Path(sys.argv[1]).read_text()
assert '--add item soundsource right' in log, log
assert 'icon=󰕾' in log, log
assert 'label.drawing=off' in log, log
assert 'System Events' in log, log
assert 'key code 0 using {control down, option down}' in log, log
assert ' update_freq=' not in log, log
assert ' script=' not in log, log
assert 'soundsource.sh' not in log, log
PY
