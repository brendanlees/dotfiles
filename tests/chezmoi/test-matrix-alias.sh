#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

rendered="$tmpdir/zshrc"
chezmoi execute-template \
  --source "$repo_root" \
  --override-data '{"personal":true,"work":false,"homelab":false,"headless":false,"ephemeral":false,"chezmoi":{"os":"darwin"}}' \
  --file "$repo_root/home/dot_zshrc.tmpl" \
  >"$rendered"

while IFS=: read -r theme expected_color; do
  override_data=$(printf '{"personal":true,"work":false,"homelab":false,"headless":false,"ephemeral":false,"theme":"%s","chezmoi":{"os":"darwin"}}' "$theme")
  if ! chezmoi execute-template \
    --source "$repo_root" \
    --override-data "$override_data" \
    --file "$repo_root/home/dot_zshrc.tmpl" | grep -Fq "cmatrix -C $expected_color"; then
    echo "$theme did not render cmatrix color $expected_color" >&2
    exit 1
  fi
done <<'THEME_COLORS'
tokyonight-night:cyan
black-metal-bathory:white
guts:green
japanesque:yellow
github_dark:blue
wryan:magenta
THEME_COLORS

matrix_function="$tmpdir/matrix.zsh"
awk '
  /^matrix\(\) \{$/ { in_matrix=1 }
  in_matrix { print }
  in_matrix && /^\}$/ { exit }
' "$rendered" >"$matrix_function"
grep -Fqx 'matrix() {' <(head -n1 "$matrix_function")

bin="$tmpdir/bin"
mkdir -p "$bin"

cat >"$bin/herdr" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'herdr %s\n' "$*" >>"$MATRIX_TEST_LOG"
if [[ "$1 $2" == 'pane split' ]]; then
  printf '%s\n' '{"result":{"pane":{"pane_id":"w1:p2"}}}'
fi
SH

cat >"$bin/osascript" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'osascript %s\n' "$*" >>"$MATRIX_TEST_LOG"
SH

cat >"$bin/tmux" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'tmux %s\n' "$*" >>"$MATRIX_TEST_LOG"
SH
chmod +x "$bin/herdr" "$bin/osascript" "$bin/tmux"

# Herdr splits and zooms a sibling pane, hides the client sidebar, and submits
# a self-cleaning cmatrix command to the new pane.
: >"$tmpdir/matrix.log"
PATH="$bin:$PATH" \
MATRIX_TEST_LOG="$tmpdir/matrix.log" \
HERDR_ENV=1 \
HERDR_BIN_PATH="$bin/herdr" \
TMUX='' \
zsh -fc "source '$matrix_function'; matrix"
grep -Fxq 'herdr pane split --current --direction right --no-focus' "$tmpdir/matrix.log"
grep -Fxq 'herdr pane zoom w1:p2 --on' "$tmpdir/matrix.log"
# shellcheck disable=SC2016 # Match the literal command sent to the new pane.
grep -Fq 'herdr pane run w1:p2 cmatrix -C cyan; "${HERDR_BIN_PATH:-herdr}" pane zoom w1:p2 --off' "$tmpdir/matrix.log"
[[ $(grep -c '^osascript ' "$tmpdir/matrix.log") -eq 1 ]]

# The existing no-multiplexer behavior remains unchanged.
: >"$tmpdir/matrix.log"
PATH="$bin:$PATH" \
MATRIX_TEST_LOG="$tmpdir/matrix.log" \
HERDR_ENV=0 \
TMUX='' \
zsh -fc "source '$matrix_function'; matrix"
grep -Fq 'tmux new-session cmatrix -C cyan' "$tmpdir/matrix.log"

# The existing in-tmux behavior still creates a window instead of a session.
: >"$tmpdir/matrix.log"
PATH="$bin:$PATH" \
MATRIX_TEST_LOG="$tmpdir/matrix.log" \
HERDR_ENV=0 \
TMUX=1 \
zsh -fc "source '$matrix_function'; matrix"
grep -Fq 'tmux new-window cmatrix -C cyan' "$tmpdir/matrix.log"

echo 'matrix multiplexer routing ok'
