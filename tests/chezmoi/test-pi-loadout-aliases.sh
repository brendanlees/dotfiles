#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ALIASES="$ROOT/dot_config/zsh/exact_aliases.d/pi.zsh.tmpl"
TMPDIR="${TMPDIR:-/tmp}"
TMPDIR="${TMPDIR%/}/pi-loadout-aliases-test-$$"
mkdir -p "$TMPDIR/bin"
trap 'rm -rf "$TMPDIR"' EXIT

cat >"$TMPDIR/bin/pi" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$PI_ALIAS_TEST_LOG"
SH
chmod +x "$TMPDIR/bin/pi"

PI_ALIAS_TEST_LOG="$TMPDIR/pi.log" PATH="$TMPDIR/bin:$PATH" zsh -fc \
  "setopt aliases; source '$ALIASES'; eval pipo; eval pisp; eval pice"

cat >"$TMPDIR/expected.log" <<'EOF'
/loadout use pocock
/loadout use superpowers
/loadout use ce
EOF
cmp "$TMPDIR/expected.log" "$TMPDIR/pi.log"
