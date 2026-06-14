#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="$ROOT/dot_config/zsh/exact_aliases.d/headroom.zsh.tmpl"
TMPDIR="${TMPDIR:-/tmp}/headroom-tmux-launcher-test-$$"
BIN="$TMPDIR/bin"
LOG="$TMPDIR/tmux.log"
mkdir -p "$BIN"

cat > "$BIN/tmux" <<'SH'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$TMUX_STUB_LOG"
case "$1" in
  display-message)
    printf 'current\n'
    ;;
esac
SH
chmod +x "$BIN/tmux"

cat > "$BIN/headroom" <<'SH'
#!/usr/bin/env sh
printf 'headroom %s\n' "$*" >> "$TMUX_STUB_LOG"
exit 0
SH
chmod +x "$BIN/headroom"

PATH="$BIN:$PATH" TMUX_STUB_LOG="$LOG" TMUX=/tmp/tmux-stub zsh -fc "source '$HELPER'; hproxy --openai-api-url https://example.invalid/v1"

python3 - "$LOG" <<'PY'
import sys
lines=open(sys.argv[1]).read().splitlines()
joined='\n'.join(lines)
normalized=joined.replace('\\ ', ' ')
assert any('new-window' in line and '-n headroom' in line for line in lines), joined
assert any('select-pane' in line and '-T proxy' in line for line in lines), joined
assert any('split-window' in line and '-h' in line for line in lines), joined
assert any('select-pane' in line and '-T codex-shim' in line for line in lines), joined
assert any('split-window' in line and '-v' in line for line in lines), joined
assert any('select-pane' in line and '-T stats' in line for line in lines), joined
assert 'headroom-watch-stats' in normalized, joined
assert 'hproxy --foreground' in normalized and '--openai-api-url https://example.invalid/v1' in normalized, joined
assert 'headroom-pi-codex-shim' in normalized, joined
PY
