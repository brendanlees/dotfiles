#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
home="$tmpdir/home & test"
vault="$home/Notes/PKM's Vault"
: >"$tmpdir/config.toml"
mkdir -p "$home/.local/bin" "$vault/.obsidian" "$tmpdir/bin"
chezmoi_bin=$(command -v chezmoi)
export REAL_NODE
REAL_NODE=$(command -v node)
export SERVICE_STATE="$tmpdir/loaded" SERVICE_LOG="$tmpdir/service.log"
export SETUP_READY=1 CONFIG_DIR=.obsidian
agent=Library/LaunchAgents/com.brendan.obsidian-headless.plist

render() {
  local name=$1 os=$2 personal=$3 enabled=$4 data source
  source="$tmpdir/$name"
  mkdir -p "$source/.chezmoiscripts/darwin" "$source/Library/LaunchAgents"
  data=$(jq -n --arg home "$home" --arg vault "$vault" --arg os "$os" \
    --argjson personal "$personal" --argjson enabled "$enabled" \
    '{personal:$personal,work:false,homelab:false,ephemeral:false,headless:false,
      chezmoi:{os:$os,homeDir:$home},obsidian_headless:{enabled:$enabled,vault_path:$vault}}')
  for file in .chezmoiignore \
    .chezmoiscripts/darwin/run_once_before_remove-obsidian-setup-wrapper.sh.tmpl \
    .chezmoiscripts/darwin/run_onchange_after_configure-obsidian-headless.sh.tmpl \
    Library/LaunchAgents/private_com.brendan.obsidian-headless.plist.tmpl; do
    chezmoi execute-template --config "$tmpdir/config.toml" --source "$repo_root" --override-data "$data" \
      --file "$repo_root/home/$file" >"$source/${file%.tmpl}"
  done
}
render enabled darwin true true
render disabled darwin true false
render work darwin false true
render linux linux true true

cat >"$tmpdir/bin/launchctl" <<'SH'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$1" >>"$SERVICE_LOG"
case "$1" in
  print) test -f "$SERVICE_STATE" ;;
  bootout)
    [[ ${FAIL_BOOTOUT:-0} == 0 ]] || exit 42
    rm "$SERVICE_STATE"
    ;;
  bootstrap) test -f "$3"; touch "$SERVICE_STATE" ;;
  *) exit 90 ;;
esac
SH
cat >"$home/.local/bin/mise" <<'SH'
#!/bin/bash
set -euo pipefail
[[ $1 == --cd && $2 == "$HOME" && $3 == exec && $4 == -- ]] || exit 91
shift 4
case "$1" in
  ob)
    [[ $2 == sync-status && $3 == --path && -d $4 && $5 == --json && $SETUP_READY == 1 ]] || exit 3
    printf '{"configDir":"%s"}\n' "$CONFIG_DIR"
    ;;
  node) shift; exec "$REAL_NODE" "$@" ;;
  *) exit 91 ;;
esac
SH
chmod +x "$tmpdir/bin/launchctl" "$home/.local/bin/mise"
mkdir -p "$home/Library/LaunchAgents" "$home/.obsidian-headless" "$home/.config/obsidian-headless"
printf 'keep credentials\n' >"$home/.obsidian-headless/auth_token"
printf 'keep sync state\n' >"$home/.obsidian-headless/vault.json"
printf 'keep notes\n' >"$vault/note.md"
printf 'retired helper\n' >"$home/.local/bin/cz-obsidian"
printf '{}\n' >"$home/.config/obsidian-headless/setup.json"
printf '[]\n' >"$vault/.obsidian/core-plugins.json"
touch "$SERVICE_STATE"
apply() {
  HOME="$home" PATH="$tmpdir/bin:/usr/bin:/bin" "$chezmoi_bin" apply \
    --source "$tmpdir/$1" --destination "$home" --config "$tmpdir/config.toml" \
    --persistent-state "$tmpdir/state.boltdb" --no-tty --force
}
run_hook() {
  HOME="$home" PATH="$tmpdir/bin:/usr/bin:/bin" \
    bash "$tmpdir/enabled/.chezmoiscripts/darwin/run_onchange_after_configure-obsidian-headless.sh"
}

# Migrate an existing wrapper service, including a failed unload and retry.
if FAIL_BOOTOUT=1 apply enabled; then echo 'Unload failure must fail apply' >&2; exit 1; fi
test -f "$SERVICE_STATE"
apply enabled
test -f "$SERVICE_STATE"
test ! -e "$home/.local/bin/cz-obsidian"
test ! -e "$home/.config/obsidian-headless/setup.json"
python3 - "$home/$agent" "$home" "$vault" <<'PY'
import plistlib
import stat
import sys
from pathlib import Path
agent = plistlib.loads(Path(sys.argv[1]).read_bytes())
home, vault = sys.argv[2:]
assert agent["ProgramArguments"] == [
    home + "/.local/bin/mise", "--cd", home, "exec", "--",
    "ob", "sync", "--continuous", "--path", vault,
]
assert agent["RunAtLoad"] and agent["KeepAlive"]
assert agent["ThrottleInterval"] >= 30 and agent["Umask"] == 0o077
assert agent["StandardOutPath"] == home + "/Library/Logs/ObsidianHeadless/sync.log"
assert agent["StandardErrorPath"] == home + "/Library/Logs/ObsidianHeadless/error.log"
assert stat.S_IMODE(Path(home + "/Library/Logs/ObsidianHeadless").stat().st_mode) == 0o700
PY
cp "$SERVICE_LOG" "$tmpdir/unchanged.log"
apply enabled
cmp "$SERVICE_LOG" "$tmpdir/unchanged.log"

SETUP_READY=0
if run_hook; then echo 'Unlinked vault must not start syncing' >&2; exit 1; fi
test ! -f "$SERVICE_STATE"
SETUP_READY=1
for plugins in '["sync"]' '{"sync":true}'; do
  printf '%s\n' "$plugins" >"$vault/.obsidian/core-plugins.json"
  if run_hook; then echo 'Desktop Sync must block headless startup' >&2; exit 1; fi
  test ! -f "$SERVICE_STATE"
done
CONFIG_DIR=.custom-obsidian
mkdir "$vault/$CONFIG_DIR"
printf '["sync"]\n' >"$vault/$CONFIG_DIR/core-plugins.json"
if run_hook; then echo 'Custom desktop configuration must also be checked' >&2; exit 1; fi
test ! -f "$SERVICE_STATE"
CONFIG_DIR=.obsidian
# A newly linked headless vault need not have desktop settings yet.
rm "$vault/.obsidian/core-plugins.json"
run_hook
test -f "$SERVICE_STATE"
for scope in disabled work; do
  apply "$scope"
  test ! -f "$SERVICE_STATE"
  test ! -e "$home/$agent"
  grep -Fxq 'keep credentials' "$home/.obsidian-headless/auth_token"
  grep -Fxq 'keep sync state' "$home/.obsidian-headless/vault.json"
  grep -Fxq 'keep notes' "$vault/note.md"
  apply enabled
  test -f "$SERVICE_STATE"
done
cp "$SERVICE_LOG" "$tmpdir/before-linux.log"
apply linux
cmp "$SERVICE_LOG" "$tmpdir/before-linux.log"

echo 'Direct Obsidian service, wrapper migration, startup guards, repeat apply and safe opt-out passed'
