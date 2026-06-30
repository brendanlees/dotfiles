#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="$ROOT/dot_config/zsh/exact_aliases.d/chezmoi.zsh.tmpl"
TMPDIR="${TMPDIR:-/tmp}/chezmoi-library-aliases-test-$$"
HOME_DIR="$TMPDIR/home"
mkdir -p "$HOME_DIR"
trap 'rm -rf "$TMPDIR"' EXIT

cat > "$TMPDIR/chezmoi" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

case "$1" in
  source-path)
    printf '%s\n' "$CHEZMOI_SOURCE_ROOT"
    ;;
  apply|re-add)
    shift
    printf '%s\n' "$*" > "$CHEZMOI_ARGS_FILE"
    ;;
  *)
    echo "unexpected chezmoi invocation: $*" >&2
    exit 64
    ;;
esac
SH
chmod +x "$TMPDIR/chezmoi"

cat > "$TMPDIR/git" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$1" == "-C" && "$2" == "$CHEZMOI_SOURCE_ROOT" && "$3" == "ls-files" && "$4" == "--" && "$5" == "Library/**" ]]; then
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
chmod +x "$TMPDIR/git"

PATH="$TMPDIR:$PATH" CHEZMOI_SOURCE_ROOT="$TMPDIR/source" HOME="$HOME_DIR" \
  CHEZMOI_ARGS_FILE="$TMPDIR/apply.args" zsh -fc 'source "'$HELPER'"; cz-lib-apply --dry-run --verbose'

PATH="$TMPDIR:$PATH" CHEZMOI_SOURCE_ROOT="$TMPDIR/source" HOME="$HOME_DIR" \
  CHEZMOI_ARGS_FILE="$TMPDIR/readd.args" zsh -fc 'source "'$HELPER'"; cz-lib-readd --dry-run'

python3 - "$TMPDIR/apply.args" "$TMPDIR/readd.args" "$HOME_DIR" <<'PY'
import sys
from pathlib import Path
apply = Path(sys.argv[1]).read_text().splitlines()
readd = Path(sys.argv[2]).read_text().splitlines()
home = Path(sys.argv[3])
expected = [
    str(home / 'Library/Application Support/SoundSource/Presets.plist'),
    str(home / 'Library/LaunchAgents/com.federicoterzi.espanso.plist'),
    str(home / 'Library/Preferences/com.superultra.Homerow.plist'),
    str(home / 'Library/Application Support/lazygit/config.yml'),
]
assert apply == ['--force --dry-run --verbose ' + ' '.join(expected)], apply
assert readd == ['--force --dry-run ' + ' '.join(expected)], readd
PY
