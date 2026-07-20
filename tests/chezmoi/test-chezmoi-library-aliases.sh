#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="$ROOT/dot_config/zsh/exact_aliases.d/chezmoi.zsh.tmpl"
TMPDIR="${TMPDIR:-/tmp}"
TMPDIR="${TMPDIR%/}/chezmoi-library-aliases-test-$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT

# scenario 1: helper scripts exist, aliases must return so later commands run
HOME1="$TMPDIR/home-with-helpers"
mkdir -p "$HOME1/.local/bin"
cat > "$HOME1/.local/bin/chezmoi-apply-library" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "$HOME/apply.args"
SH
chmod +x "$HOME1/.local/bin/chezmoi-apply-library"
cat > "$HOME1/.local/bin/chezmoi-readd-library" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "$HOME/readd.args"
SH
chmod +x "$HOME1/.local/bin/chezmoi-readd-library"
HOME="$HOME1" zsh -fc "source '$HELPER'; cz-lib-apply --dry-run --verbose; print after-apply > '$HOME1/after-apply.txt'; cz-lib-readd --dry-run; print after-readd > '$HOME1/after-readd.txt'"
[ "$(cat "$HOME1/after-apply.txt")" = after-apply ]
[ "$(cat "$HOME1/after-readd.txt")" = after-readd ]
[ "$(cat "$HOME1/apply.args")" = '--dry-run --verbose' ]
[ "$(cat "$HOME1/readd.args")" = '--dry-run' ]

# scenario 2: no helper scripts; aliases must fall back to built-in chezmoi calls
HOME2="$TMPDIR/home-fallback"
SRC2="$TMPDIR/source"
BIN2="$TMPDIR/bin"
mkdir -p "$HOME2" "$SRC2" "$BIN2"
cat > "$BIN2/chezmoi" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  source-path)
    printf '%s\n' "$CHEZMOI_SOURCE_ROOT"
    ;;
  apply)
    shift
    printf '%s\n' "$*" > "$CHEZMOI_APPLY_ARGS"
    ;;
  re-add)
    shift
    printf '%s\n' "$*" > "$CHEZMOI_READD_ARGS"
    ;;
  *)
    echo "unexpected chezmoi invocation: $*" >&2
    exit 64
    ;;
esac
SH
chmod +x "$BIN2/chezmoi"
cat > "$BIN2/git" <<'SH'
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
chmod +x "$BIN2/git"
PATH="$BIN2:$PATH" HOME="$HOME2" CHEZMOI_SOURCE_ROOT="$SRC2" CHEZMOI_APPLY_ARGS="$TMPDIR/apply-fallback.args" CHEZMOI_READD_ARGS="$TMPDIR/readd-fallback.args" \
  zsh -fc "source '$HELPER'; cz-lib-apply --dry-run --verbose; print after-apply > '$TMPDIR/after-apply-fallback.txt'; cz-lib-readd --dry-run; print after-readd > '$TMPDIR/after-readd-fallback.txt'"
[ "$(cat "$TMPDIR/after-apply-fallback.txt")" = after-apply ]
[ "$(cat "$TMPDIR/after-readd-fallback.txt")" = after-readd ]
python3 - "$TMPDIR/apply-fallback.args" "$TMPDIR/readd-fallback.args" "$HOME2" <<'PY'
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
