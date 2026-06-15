#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FACADE="$ROOT/dot_config/zsh/exact_aliases.d/headroom.zsh.tmpl"
ENV_FILE="$ROOT/dot_config/headroom/env.zsh.tmpl"
FUNCTIONS_FILE="$ROOT/dot_config/headroom/functions.zsh.tmpl"
CODEX_SHIM="$ROOT/dot_local/bin/executable_headroom-codex-shim"
TMUX_LAUNCHER="$ROOT/dot_local/bin/executable_headroom-tmux"

for path in "$ENV_FILE" "$FUNCTIONS_FILE" "$CODEX_SHIM" "$TMUX_LAUNCHER"; do
  [ -f "$path" ] || { echo "missing expected Headroom split file: $path" >&2; exit 1; }
done

line_count="$(wc -l < "$FACADE" | tr -d ' ')"
[ "$line_count" -lt 90 ] || { echo "facade too large: $line_count lines" >&2; exit 1; }

if grep -q "python3 -" "$FACADE" || grep -q "<<'PY'" "$FACADE"; then
  echo 'facade must not embed the Codex shim Python heredoc' >&2
  exit 1
fi

if grep -q '^headroom-pi-codex-shim()' "$FACADE"; then
  echo 'public command implementations should live in functions.zsh.tmpl, not facade' >&2
  exit 1
fi

TMPDIR="${TMPDIR:-/tmp}/headroom-layout-test-$$"
mkdir -p "$TMPDIR/home/.config" "$TMPDIR/bin"
trap 'rm -rf "$TMPDIR"' EXIT

PATH="$ROOT/dot_local/bin:$TMPDIR/bin:$PATH" HOME="$TMPDIR/home" XDG_CONFIG_HOME="$TMPDIR/home/.config" zsh -fc "
  source '$FACADE'
  for name in \
    hr-env hr-proxy-url hr-proxy-active hr-codex-shim-url hr-codex-shim-active \
    hr-wait-for-proxy hr-require-proxy hr-pi-provider-exists hr-run-headroom-command \
    hproxy hproxy-openrouter hproxy-foreground hclaude hcodex \
    headroom-pi-codex-shim hpi hpix hstats headroom-watch-stats; do
    whence -w \"\$name\" >/dev/null || { echo \"missing command/function: \$name\" >&2; exit 1; }
  done
  command -v executable_headroom-codex-shim >/dev/null
  command -v executable_headroom-tmux >/dev/null
"
