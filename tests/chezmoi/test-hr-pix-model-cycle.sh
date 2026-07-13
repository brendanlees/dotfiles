#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="$ROOT/dot_config/zsh/exact_aliases.d/headroom.zsh.tmpl"
TMPDIR="${TMPDIR:-/tmp}/hr-pix-model-cycle-test-$$"
BIN="$TMPDIR/bin"
LOG="$TMPDIR/pi.log"
mkdir -p "$BIN"

cat > "$BIN/curl" <<'SH'
#!/usr/bin/env sh
exit 0
SH
chmod +x "$BIN/curl"

cat > "$BIN/pi" <<'SH'
#!/usr/bin/env sh
if [ "$1" = "--list-models" ]; then
  printf 'provider model\nheadroom-codex-oauth gpt-5.6-sol\nheadroom-codex-oauth gpt-5.5\nheadroom-codex-oauth gpt-5.4-mini\n'
  exit 0
fi
printf '%s\n' "$*" > "$PI_STUB_LOG"
SH
chmod +x "$BIN/pi"

PATH="$BIN:$PATH" PI_STUB_LOG="$LOG" zsh -fc "source '$HELPER'; HEADROOM_PORT=18881 HEADROOM_CODEX_SHIM_PORT=18882 hr-pix --no-session -p test"

python3 - "$LOG" <<'PY'
import sys
args=open(sys.argv[1]).read().strip()
assert '--model headroom-codex-oauth/gpt-5.6-sol' in args, args
assert '--models headroom-codex-oauth/gpt-5.6-sol,headroom-codex-oauth/gpt-5.5,headroom-codex-oauth/gpt-5.4-mini' in args, args
assert '--no-session -p test' in args, args
PY
