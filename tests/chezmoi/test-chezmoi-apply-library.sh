#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/dot_local/bin/executable_chezmoi-apply-library"
TMPDIR="${TMPDIR:-/tmp}/chezmoi-apply-library-test-$$"
BIN="$TMPDIR/bin"
SOURCE_ROOT="$TMPDIR/source"
mkdir -p "$BIN" "$SOURCE_ROOT"
trap 'rm -rf "$TMPDIR"' EXIT

cat > "$BIN/chezmoi" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

case "$1" in
  source-path)
    printf '%s\n' "$CHEZMOI_SOURCE_ROOT"
    ;;
  apply)
    shift
    printf '%s\n' "$@" > "$CHEZMOI_APPLY_ARGS"
    ;;
  *)
    echo "unexpected chezmoi invocation: $*" >&2
    exit 64
    ;;
esac
SH
chmod +x "$BIN/chezmoi"

cat > "$BIN/git" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$1" == "-C" && "$2" == "$CHEZMOI_SOURCE_ROOT" && "$3" == "ls-files" && "$4" == "--" ]]; then
  printf '%s\n' \
    'Library/Application Support/SoundSource/Presets.plist' \
    'Library/LaunchAgents/com.federicoterzi.espanso.plist.tmpl' \
    'Library/Preferences/private_com.superultra.Homerow.plist' \
    'Library/Application Support/lazygit/symlink_config.yml.tmpl'
  exit 0
fi

echo "unexpected git invocation: $*" >&2
exit 64
SH
chmod +x "$BIN/git"

PATH="$BIN:$PATH" CHEZMOI_SOURCE_ROOT="$SOURCE_ROOT" CHEZMOI_APPLY_ARGS="$TMPDIR/apply.args" HOME='/Users/brendan' "$SCRIPT" --dry-run --verbose

python3 - "$TMPDIR/apply.args" <<'PY'
import sys
from pathlib import Path
args = Path(sys.argv[1]).read_text().splitlines()
assert args == [
    '--force',
    '--dry-run',
    '--verbose',
    '/Users/brendan/Library/Application Support/SoundSource/Presets.plist',
    '/Users/brendan/Library/LaunchAgents/com.federicoterzi.espanso.plist',
    '/Users/brendan/Library/Preferences/com.superultra.Homerow.plist',
    '/Users/brendan/Library/Application Support/lazygit/config.yml',
], args
PY
