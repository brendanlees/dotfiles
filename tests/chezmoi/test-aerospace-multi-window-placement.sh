#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG="$ROOT/home/dot_config/aerospace/aerospace.toml"
HELPER="$ROOT/home/dot_config/aerospace/executable_move-window-if-first.sh"
ACTIVATION_HELPER="$ROOT/home/dot_config/aerospace/executable_activate-arc-if-present.sh"

python3 - "$CONFIG" <<'PY'
import pathlib
import re
import sys
import tomllib

config = pathlib.Path(sys.argv[1]).read_text()
parsed = tomllib.loads(config)
assert parsed['mode']['main']['binding']['alt-1'] == [
    'workspace 1-browser',
    'exec-and-forget "$HOME/.config/aerospace/activate-arc-if-present.sh"',
]
assert parsed['mode']['main']['binding']['alt-b'] == [
    'workspace 1-browser',
    'exec-and-forget open -a Arc',
]
assert 'raycast: alt+b = browser' not in config
assert re.search(
    r"if\.app-id = 'company\.thebrowser\.Browser'\n"
    r"run = 'exec-and-forget \"\$HOME/\.config/aerospace/move-window-if-first\.sh\" "
    r"company\.thebrowser\.Browser 1-browser'",
    config,
), "browser windows should use first-window placement"
PY

for helper in "$HELPER" "$ACTIVATION_HELPER"; do
  if [ ! -x "$helper" ]; then
    printf 'expected executable helper at %s\n' "$helper" >&2
    exit 1
  fi
done

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT
mkdir -p "$TEMP_DIR/bin"

cat > "$TEMP_DIR/bin/aerospace" <<'SH'
#!/usr/bin/env sh
case "$1" in
  list-windows)
    if [ "${2:-}" = "--workspace" ]; then
      cat "$ARC_COUNT_FILE"
    else
      cat "$WINDOWS_FILE"
    fi
    ;;
  move-node-to-workspace)
    printf '%s\n' "$*" >> "$MOVES_FILE"
    ;;
  *)
    exit 1
    ;;
esac
SH
chmod +x "$TEMP_DIR/bin/aerospace"

cat > "$TEMP_DIR/bin/open" <<'SH'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$OPEN_FILE"
SH
chmod +x "$TEMP_DIR/bin/open"

printf '42\n' > "$TEMP_DIR/windows"
: > "$TEMP_DIR/moves"
PATH="$TEMP_DIR/bin:$PATH" \
WINDOWS_FILE="$TEMP_DIR/windows" \
MOVES_FILE="$TEMP_DIR/moves" \
AEROSPACE_WINDOW_ID=42 \
  "$HELPER" company.thebrowser.Browser 1-browser
grep -F -- 'move-node-to-workspace --window-id 42 1-browser' "$TEMP_DIR/moves" >/dev/null

printf '42\n99\n' > "$TEMP_DIR/windows"
: > "$TEMP_DIR/moves"
PATH="$TEMP_DIR/bin:$PATH" \
WINDOWS_FILE="$TEMP_DIR/windows" \
MOVES_FILE="$TEMP_DIR/moves" \
AEROSPACE_WINDOW_ID=99 \
  "$HELPER" company.thebrowser.Browser 1-browser
if [ -s "$TEMP_DIR/moves" ]; then
  printf 'a later browser window should remain in its current workspace\n' >&2
  exit 1
fi

printf '1\n' > "$TEMP_DIR/arc-count"
: > "$TEMP_DIR/open"
PATH="$TEMP_DIR/bin:$PATH" \
ARC_COUNT_FILE="$TEMP_DIR/arc-count" \
OPEN_FILE="$TEMP_DIR/open" \
  "$ACTIVATION_HELPER"
grep -F -- '-a Arc' "$TEMP_DIR/open" >/dev/null

printf '0\n' > "$TEMP_DIR/arc-count"
: > "$TEMP_DIR/open"
PATH="$TEMP_DIR/bin:$PATH" \
ARC_COUNT_FILE="$TEMP_DIR/arc-count" \
OPEN_FILE="$TEMP_DIR/open" \
  "$ACTIVATION_HELPER"
if [ -s "$TEMP_DIR/open" ]; then
  printf 'Arc should not be activated when it is absent from the browser workspace\n' >&2
  exit 1
fi
