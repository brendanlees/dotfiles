#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG="$ROOT/home/dot_config/aerospace/aerospace.toml"
HELPER="$ROOT/home/dot_config/aerospace/executable_move-window-if-first.sh"

python3 - "$CONFIG" <<'PY'
import pathlib
import re
import sys

config = pathlib.Path(sys.argv[1]).read_text()
assert re.search(
    r"if\.app-id = 'company\.thebrowser\.Browser'\n"
    r"run = 'exec-and-forget \"\$HOME/\.config/aerospace/move-window-if-first\.sh\" "
    r"company\.thebrowser\.Browser 1-browser'",
    config,
), "browser windows should use first-window placement"
PY

if [ ! -x "$HELPER" ]; then
  printf 'expected executable helper at %s\n' "$HELPER" >&2
  exit 1
fi

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT
mkdir -p "$TEMP_DIR/bin"

cat > "$TEMP_DIR/bin/aerospace" <<'SH'
#!/usr/bin/env sh
case "$1" in
  list-windows)
    cat "$WINDOWS_FILE"
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
