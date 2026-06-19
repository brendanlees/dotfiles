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
  list-windows)
    if [ -n "${TMUX_LIST_WINDOWS_OUTPUT:-}" ]; then
      printf '%s\n' "$TMUX_LIST_WINDOWS_OUTPUT"
    fi
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
unescaped=joined.replace('\\', '')
assert any('new-window' in line and '-n headroom' in line for line in lines), joined
assert any('select-pane' in line and '-T proxy' in line for line in lines), joined
assert any('split-window' in line and '-h' in line for line in lines), joined
assert any('select-pane' in line and '-T codex-shim' in line for line in lines), joined
assert any('split-window' in line and '-v' in line for line in lines), joined
assert any('select-pane' in line and '-T stats' in line for line in lines), joined
assert 'headroom-watch-stats' in normalized, joined
assert 'select-layout even-horizontal' not in joined, joined
stats_idx = next(i for i, line in enumerate(lines) if 'select-pane' in line and '-T stats' in line)
shim_idx = next(i for i, line in enumerate(lines) if 'select-pane' in line and '-T codex-shim' in line)
assert stats_idx < shim_idx, joined
assert 'hproxy --foreground' in normalized and '--openai-api-url https://example.invalid/v1' in normalized, joined
assert 'headroom-pi-codex-shim' in normalized, joined

assert '38;2;101;133;148m' in unescaped, joined  # kanagawa-dragon primary -> proxy
assert '38;2;138;154;123m' in unescaped, joined  # kanagawa-dragon success -> stats
assert '38;2;162;146;163m' in unescaped, joined  # kanagawa-dragon secondary -> codex shim
PY

: > "$LOG"
PATH="$BIN:$PATH" TMUX_STUB_LOG="$LOG" TMUX=/tmp/tmux-stub zsh -fc "source '$HELPER'; hproxy --help"
python3 - "$LOG" <<'PY'
import sys
lines=open(sys.argv[1]).read().splitlines()
joined='\n'.join(lines)
assert lines == ['headroom proxy --help'], joined
PY

: > "$LOG"
PATH="$BIN:$PATH" TMUX_STUB_LOG="$LOG" TMUX=/tmp/tmux-stub TMUX_LIST_WINDOWS_OUTPUT='old:2:headroom' zsh -fc "source '$HELPER'; hproxy"
python3 - "$LOG" <<'PY'
import sys
lines=open(sys.argv[1]).read().splitlines()
joined='\n'.join(lines)
kill_idx = next(i for i, line in enumerate(lines) if 'kill-window' in line and '-t old:2' in line)
new_idx = next(i for i, line in enumerate(lines) if 'new-window' in line and '-n headroom' in line)
assert kill_idx < new_idx, joined
PY
