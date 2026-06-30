#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="$ROOT/dot_config/zsh/exact_aliases.d/chezmoi.zsh.tmpl"
TMPDIR="${TMPDIR:-/tmp}/chezmoi-library-aliases-test-$$"
HOME_DIR="$TMPDIR/home"
BIN_DIR="$HOME_DIR/.local/bin"
mkdir -p "$BIN_DIR"
trap 'rm -rf "$TMPDIR"' EXIT

cat > "$BIN_DIR/chezmoi-apply-library" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "$HOME_DIR/apply.args"
SH
chmod +x "$BIN_DIR/chezmoi-apply-library"

cat > "$BIN_DIR/chezmoi-readd-library" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "$HOME_DIR/readd.args"
SH
chmod +x "$BIN_DIR/chezmoi-readd-library"

HOME="$HOME_DIR" HOME_DIR="$HOME_DIR" zsh -fc 'source "'$HELPER'"; cz-lib-apply --dry-run --verbose; cz-lib-readd --dry-run'

python3 - "$HOME_DIR/apply.args" "$HOME_DIR/readd.args" <<'PY'
import sys
from pathlib import Path
apply = Path(sys.argv[1]).read_text().splitlines()
readd = Path(sys.argv[2]).read_text().splitlines()
assert apply == ['--dry-run --verbose'], apply
assert readd == ['--dry-run'], readd
PY
