#!/bin/bash

CONFIG_DIR="${CONFIG_DIR:-${HOME}/.config/sketchybar}"
# shellcheck source=dot_config/sketchybar/colors.sh
source "$CONFIG_DIR/colors.sh"
# shellcheck source=dot_config/sketchybar/icons.sh
source "$CONFIG_DIR/icons.sh"

betterdisplay_bin="$(command -v betterdisplaycli || command -v BetterDisplayCLI || true)"
state="unknown"

if [ -n "$betterdisplay_bin" ] && [ -x "$betterdisplay_bin" ] && [ -x /usr/bin/python3 ]; then
  state="$(/usr/bin/python3 - "$betterdisplay_bin" <<'PY' 2>/dev/null || printf 'unknown'
import subprocess
import sys

try:
    result = subprocess.run(
        [sys.argv[1], "get", "-volume"],
        capture_output=True,
        check=True,
        text=True,
        timeout=3,
    )
    first_line = result.stdout.strip().splitlines()[0]
    volume = float(first_line)
except Exception:
    print("unknown")
    sys.exit(0)

if volume <= 0:
    print("silent")
else:
    print("active")
PY
)"
fi

case "$state" in
  active)
    icon="$ICON_VOLUME"
    color="$ICON_COLOR"
    ;;
  silent)
    icon="$ICON_VOLUME_MUTED"
    color="$ORANGE"
    ;;
  *)
    icon="$ICON_VOLUME_UNKNOWN"
    color="$GREY"
    ;;
esac

sketchybar --set "$NAME" \
  icon="$icon" \
  icon.color="$color" \
  label.drawing=off
