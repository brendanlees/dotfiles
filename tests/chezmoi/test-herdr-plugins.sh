#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
template="$repo_root/.chezmoiscripts/run_onchange_after_install-herdr-plugins.sh.tmpl"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

[[ -f "$template" ]] || { echo "missing Herdr plugin reconciler: $template" >&2; exit 1; }

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

nav_ref='53e318c772c4d3b7fbd904ac43bcf3e5b5d8b244'
plus_ref='f32b0825f12543c1d03e54fb10d1741c40d66cdc'
last_workspace_ref='8b55ebf15deaa52b49ff1c2500aab0c19c729420'
grep -Fxq "plugin install paulbkim-dev/vim-herdr-navigation --ref $nav_ref --yes" "$tmpdir/herdr.log"
grep -Fxq "plugin install cloudmanic/herdr-plus --ref $plus_ref --yes" "$tmpdir/herdr.log"
grep -Fxq "plugin install third774/herdr-last-workspace --ref $last_workspace_ref --yes" "$tmpdir/herdr.log"
grep -Fxq 'plugin uninstall old-plugin' "$tmpdir/herdr.log"
grep -Fxq "vim-herdr-navigation|paulbkim-dev/vim-herdr-navigation|$nav_ref" \
  "$tmpdir/state/chezmoi/herdr-plugins.txt"
grep -Fxq "cloudmanic.herdr-plus|cloudmanic/herdr-plus|$plus_ref" \
  "$tmpdir/state/chezmoi/herdr-plugins.txt"
grep -Fxq "third774.last-workspace|third774/herdr-last-workspace|$last_workspace_ref" \
  "$tmpdir/state/chezmoi/herdr-plugins.txt"
if grep -Fq 'old-plugin' "$tmpdir/state/chezmoi/herdr-plugins.txt"; then
  echo "stale managed plugin remained in state ledger" >&2
  exit 1
fi

echo "Herdr plugin reconciliation ok"
