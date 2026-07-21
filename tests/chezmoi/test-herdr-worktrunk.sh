#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

rendered="$tmpdir/reconcile.sh"
chezmoi execute-template --source "$repo_root" \
  <"$repo_root/.chezmoiscripts/run_onchange_after_install-herdr-plugins.sh.tmpl" >"$rendered"
chmod +x "$rendered"
mkdir -p "$tmpdir/bin" "$tmpdir/home" "$tmpdir/state" "$tmpdir/plugin-config"
cat >"$tmpdir/bin/herdr" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >>"$HERDR_TEST_LOG"
if [ "$*" = "plugin config-dir worktrunk" ]; then
  printf '%s\n' "$HERDR_TEST_CONFIG_DIR"
fi
SH
chmod +x "$tmpdir/bin/herdr"

HERDR_TEST_LOG="$tmpdir/herdr.log" \
HERDR_TEST_CONFIG_DIR="$tmpdir/plugin-config" \
HOME="$tmpdir/home" \
XDG_STATE_HOME="$tmpdir/state" \
PATH="$tmpdir/bin:/usr/bin:/bin" \
  "$rendered"

ref=e9131c0b576fd68635194c758c9691dbfb778b61
grep -Fxq "plugin install devashish2203/herdr-worktrunk --ref $ref --yes" "$tmpdir/herdr.log"
grep -Fxq 'plugin config-dir worktrunk' "$tmpdir/herdr.log"
grep -Fxq 'open_mode = "workspace"' "$tmpdir/plugin-config/config.toml"

echo "Herdr Worktrunk reconciliation ok"
