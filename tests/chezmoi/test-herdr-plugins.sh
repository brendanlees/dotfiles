#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
template="$repo_root/.chezmoiscripts/run_onchange_after_install-herdr-plugins.sh.tmpl"
nvim_bridge="$repo_root/dot_config/nvim/after/plugin/herdr_nav.lua"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

[[ -f "$template" ]] || { echo "missing Herdr plugin reconciler: $template" >&2; exit 1; }
[[ -f "$nvim_bridge" ]] || { echo "missing Neovim Herdr navigation bridge: $nvim_bridge" >&2; exit 1; }

rendered="$tmpdir/install-herdr-plugins.sh"
chezmoi execute-template --source "$repo_root" <"$template" >"$rendered"
chmod +x "$rendered"

fakebin="$tmpdir/bin"
mkdir -p "$fakebin" "$tmpdir/home" "$tmpdir/state/chezmoi"
cat >"$fakebin/herdr" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >>"$HERDR_TEST_LOG"
SH
chmod +x "$fakebin/herdr"

cat >"$tmpdir/state/chezmoi/herdr-plugins.txt" <<'STATE'
old-plugin|example/old-plugin|old-ref
STATE

HERDR_TEST_LOG="$tmpdir/herdr.log" \
HOME="$tmpdir/home" \
XDG_STATE_HOME="$tmpdir/state" \
PATH="$fakebin:/usr/bin:/bin" \
  "$rendered"

ref='53e318c772c4d3b7fbd904ac43bcf3e5b5d8b244'
grep -Fxq "plugin install paulbkim-dev/vim-herdr-navigation --ref $ref --yes" "$tmpdir/herdr.log"
grep -Fxq 'plugin uninstall old-plugin' "$tmpdir/herdr.log"
grep -Fxq "vim-herdr-navigation|paulbkim-dev/vim-herdr-navigation|$ref" \
  "$tmpdir/state/chezmoi/herdr-plugins.txt"
if grep -Fq 'old-plugin' "$tmpdir/state/chezmoi/herdr-plugins.txt"; then
  echo "stale managed plugin remained in state ledger" >&2
  exit 1
fi

grep -Fq 'vim.env.HERDR_PANE_ID' "$nvim_bridge"
grep -Fq '"pane", "focus", "--direction", dir, "--current"' "$nvim_bridge"
grep -Fq 'TmuxNavigate' "$nvim_bridge"

echo "Herdr plugin reconciliation ok"
