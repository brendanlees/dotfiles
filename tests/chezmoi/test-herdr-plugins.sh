#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_root="$repo_root/home"
template="$source_root/.chezmoiscripts/run_onchange_after_install-herdr-plugins.sh.tmpl"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

[[ -f "$template" ]] || {
  echo "missing Herdr plugin reconciler: $template" >&2
  exit 1
}

rendered="$tmpdir/install-herdr-plugins.sh"
chezmoi execute-template \
  --source "$repo_root" \
  --override-data '{"personal":true}' \
  <"$template" >"$rendered"
chmod +x "$rendered"

fakebin="$tmpdir/bin"
mkdir -p "$fakebin" "$tmpdir/home/.local/bin" "$tmpdir/state/chezmoi" "$tmpdir/plugin-config" "$tmpdir/shims"
cat >"$tmpdir/home/.local/bin/mise" <<'SH'
#!/bin/sh
set -eu
[ "$1" = --cd ]
[ "$2" = "$HOME" ]
[ "$3" = exec ]
[ "$4" = -- ]
shift 4
cd "$HOME"
PATH="$HERDR_TEST_TOOLS_DIR:$PATH"
export PATH HERDR_TEST_MISE_ACTIVE=1
exec "$@"
SH
cat >"$tmpdir/shims/go" <<'SH'
#!/bin/sh
echo 'mise ERROR No version is set for shim: go' >&2
exit 1
SH
cat >"$fakebin/go" <<'SH'
#!/bin/sh
set -eu
[ "$HERDR_TEST_MISE_ACTIVE" = 1 ]
[ "$PWD" = "$HOME" ]
if [ "${HERDR_TEST_GO_FAIL:-0}" = 1 ]; then
  echo 'mise ERROR No version is set for shim: go' >&2
  exit 1
fi
[ "$*" = version ]
printf '%s\n' 'go version go1.26.2'
SH
cat >"$fakebin/herdr" <<'SH'
#!/bin/sh
set -eu
[ "$HERDR_TEST_MISE_ACTIVE" = 1 ]
[ "$PWD" = "$HOME" ]
printf '%s\n' "$*" >>"$HERDR_TEST_LOG"
case "$*" in
  --version) [ "${HERDR_TEST_HERDR_FAIL:-0}" != 1 ] ;;
  'plugin install cloudmanic/herdr-plus '*)
    # The pinned upstream build chooses source compilation whenever Go is on PATH.
    command -v go >/dev/null
    go version >/dev/null
    [ "${HERDR_TEST_INSTALL_FAIL:-0}" != 1 ] ;;
  'plugin config-dir worktrunk') printf '%s\n' "$HERDR_TEST_CONFIG_DIR" ;;
esac
SH
chmod +x "$tmpdir/home/.local/bin/mise" "$tmpdir/shims/go" "$fakebin/go" "$fakebin/herdr"

run_reconciler() {
  local script=$1
  shift
  env "$@" \
    HERDR_TEST_LOG="$tmpdir/herdr.log" \
    HERDR_TEST_CONFIG_DIR="$tmpdir/plugin-config" \
    HERDR_TEST_TOOLS_DIR="$fakebin" \
    HOME="$tmpdir/home" \
    XDG_STATE_HOME="$tmpdir/state" \
    PATH="$tmpdir/shims:/usr/bin:/bin" \
    "$script"
}

# First run has neither a ledger nor Herdr on the caller's PATH, only a broken Go shim.
run_reconciler "$rendered"
[[ -s "$tmpdir/state/chezmoi/herdr-plugins.txt" ]]
cp "$tmpdir/state/chezmoi/herdr-plugins.txt" "$tmpdir/first-state"
cp "$tmpdir/herdr.log" "$tmpdir/first-log"
: >"$tmpdir/herdr.log"
run_reconciler "$rendered"
cmp "$tmpdir/first-state" "$tmpdir/state/chezmoi/herdr-plugins.txt"
cmp "$tmpdir/first-log" "$tmpdir/herdr.log"

cat >"$tmpdir/state/chezmoi/herdr-plugins.txt" <<'STATE'
old-plugin|example/old-plugin|old-ref
official.browser|ogulcancelik/herdr-browser|be6888b71cf4eb5939ee79a746bd1a1c22ade046
third774.last-workspace|third774/herdr-last-workspace|8b55ebf15deaa52b49ff1c2500aab0c19c729420
persiyanov.reviewr|persiyanov/herdr-reviewr|f1dd491e47ef55410eca7c73daebe3726f06bda0
STATE

: >"$tmpdir/herdr.log"
run_reconciler "$rendered"

nav_ref='53e318c772c4d3b7fbd904ac43bcf3e5b5d8b244'
plus_ref='f32b0825f12543c1d03e54fb10d1741c40d66cdc'
last_workspace_ref='8b55ebf15deaa52b49ff1c2500aab0c19c729420'
worktrunk_ref='37605f0cde8037a58560ef87ce428e1a095fa3e2'
navigator_ref='03b803a00341d58382b6cda70a7cd618af5b8806'
crabbox_ref='70aaebd1083615eadeddb920b1f344822a2f013b'
grep -Fxq "plugin install paulbkim-dev/vim-herdr-navigation --ref $nav_ref --yes" "$tmpdir/herdr.log"
grep -Fxq "plugin install cloudmanic/herdr-plus --ref $plus_ref --yes" "$tmpdir/herdr.log"
grep -Fxq "plugin install third774/herdr-last-workspace --ref $last_workspace_ref --yes" "$tmpdir/herdr.log"
grep -Fxq "plugin install devashish2203/herdr-worktrunk --ref $worktrunk_ref --yes" "$tmpdir/herdr.log"
grep -Fxq "plugin install thanhdat77/herdr-navigator --ref $navigator_ref --yes" "$tmpdir/herdr.log"
grep -Fxq "plugin install openclaw/crabbox/plugins/herdr --ref $crabbox_ref --yes" "$tmpdir/herdr.log"
grep -Fxq 'plugin uninstall old-plugin' "$tmpdir/herdr.log"
grep -Fxq 'plugin uninstall official.browser' "$tmpdir/herdr.log"
grep -Fxq 'plugin uninstall persiyanov.reviewr' "$tmpdir/herdr.log"
grep -Fxq "vim-herdr-navigation|paulbkim-dev/vim-herdr-navigation|$nav_ref" \
  "$tmpdir/state/chezmoi/herdr-plugins.txt"
grep -Fxq "cloudmanic.herdr-plus|cloudmanic/herdr-plus|$plus_ref" \
  "$tmpdir/state/chezmoi/herdr-plugins.txt"
grep -Fxq "third774.last-workspace|third774/herdr-last-workspace|$last_workspace_ref" \
  "$tmpdir/state/chezmoi/herdr-plugins.txt"
grep -Fxq "worktrunk|devashish2203/herdr-worktrunk|$worktrunk_ref" \
  "$tmpdir/state/chezmoi/herdr-plugins.txt"
grep -Fxq "herdr-navigator|thanhdat77/herdr-navigator|$navigator_ref" \
  "$tmpdir/state/chezmoi/herdr-plugins.txt"
grep -Fxq "crabbox|openclaw/crabbox/plugins/herdr|$crabbox_ref" \
  "$tmpdir/state/chezmoi/herdr-plugins.txt"
grep -Fxq 'open_mode = "workspace"' "$tmpdir/plugin-config/config.toml"
for removed_plugin in old-plugin official.browser persiyanov.reviewr; do
  if grep -Fq "$removed_plugin" "$tmpdir/state/chezmoi/herdr-plugins.txt"; then
    echo "stale managed plugin remained in state ledger: $removed_plugin" >&2
    exit 1
  fi
done

# Failures must not publish a new ledger, rewrite config, or remove old plugins.
cp "$tmpdir/state/chezmoi/herdr-plugins.txt" "$tmpdir/success-state"
printf '%s\n' 'removed-plugin|example/removed|old-ref' >>"$tmpdir/state/chezmoi/herdr-plugins.txt"
printf '%s\n' 'user config must survive failures' >"$tmpdir/plugin-config/config.toml"
cp "$tmpdir/state/chezmoi/herdr-plugins.txt" "$tmpdir/before-failure-state"
cp "$tmpdir/plugin-config/config.toml" "$tmpdir/before-failure-config"
for failure in GO HERDR INSTALL; do
  : >"$tmpdir/herdr.log"
  if run_reconciler "$rendered" "HERDR_TEST_${failure}_FAIL=1" >"$tmpdir/failure.log" 2>&1; then
    echo "$failure failure was silently accepted" >&2
    exit 1
  fi
  cmp "$tmpdir/before-failure-state" "$tmpdir/state/chezmoi/herdr-plugins.txt"
  cmp "$tmpdir/before-failure-config" "$tmpdir/plugin-config/config.toml"
  if grep -Eq 'plugin (uninstall|config-dir)' "$tmpdir/herdr.log"; then
    echo "$failure failure allowed destructive reconciliation" >&2
    exit 1
  fi
  if [[ $failure != INSTALL ]] && grep -Fq 'plugin install' "$tmpdir/herdr.log"; then
    echo "$failure preflight failure allowed plugin installation" >&2
    exit 1
  fi
done

# An absent mise is a visible failure, not a successful no-op; PATH discovery also works.
mv "$tmpdir/home/.local/bin/mise" "$tmpdir/mise"
if run_reconciler "$rendered" >"$tmpdir/failure.log" 2>&1; then
  echo 'missing mise was silently accepted' >&2
  exit 1
fi
cmp "$tmpdir/before-failure-state" "$tmpdir/state/chezmoi/herdr-plugins.txt"
cmp "$tmpdir/before-failure-config" "$tmpdir/plugin-config/config.toml"
mv "$tmpdir/mise" "$tmpdir/shims/mise"
run_reconciler "$rendered"
cmp "$tmpdir/success-state" "$tmpdir/state/chezmoi/herdr-plugins.txt"
grep -Fxq 'plugin uninstall removed-plugin' "$tmpdir/herdr.log"
mv "$tmpdir/shims/mise" "$tmpdir/home/.local/bin/mise"

# Herdr itself is optional (for example on homelab hosts). Its absence must not
# fail a normal apply or alter a retained ledger/config from an earlier install.
mv "$fakebin/herdr" "$tmpdir/herdr"
cp "$tmpdir/plugin-config/config.toml" "$tmpdir/before-skip-config"
: >"$tmpdir/herdr.log"
run_reconciler "$rendered" >"$tmpdir/skip.log" 2>&1
cmp "$tmpdir/success-state" "$tmpdir/state/chezmoi/herdr-plugins.txt"
cmp "$tmpdir/before-skip-config" "$tmpdir/plugin-config/config.toml"
[[ ! -s "$tmpdir/herdr.log" ]]
mv "$tmpdir/herdr" "$fakebin/herdr"

windows_rendered="$tmpdir/install-herdr-plugins-windows.sh"
chezmoi execute-template \
  --source "$repo_root" \
  --override-data '{"personal":true,"chezmoi":{"os":"windows"}}' \
  <"$template" >"$windows_rendered"
[[ ! -s "$windows_rendered" ]] || {
  echo 'Windows must not reconcile Herdr plugins' >&2
  exit 1
}

nonpersonal_rendered="$tmpdir/install-herdr-plugins-nonpersonal.sh"
chezmoi execute-template \
  --source "$repo_root" \
  --override-data '{"personal":false}' \
  <"$template" >"$nonpersonal_rendered"
chmod +x "$nonpersonal_rendered"
: >"$tmpdir/herdr.log"
run_reconciler "$nonpersonal_rendered"

if grep -Fq 'plugin install openclaw/crabbox/plugins/herdr' "$tmpdir/herdr.log"; then
  echo 'non-personal install must not install the Crabbox plugin' >&2
  exit 1
fi
grep -Fxq 'plugin uninstall crabbox' "$tmpdir/herdr.log"
if grep -Fq 'crabbox|' "$tmpdir/state/chezmoi/herdr-plugins.txt"; then
  echo 'non-personal install retained Crabbox in the managed plugin ledger' >&2
  exit 1
fi

echo "Herdr plugin reconciliation ok"
