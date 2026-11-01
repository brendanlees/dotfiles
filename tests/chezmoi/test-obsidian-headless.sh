#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
home="$tmpdir/home & test"
vault="$home/Notes/PKM's Vault"
: >"$tmpdir/config.toml"
mkdir -p "$home/.local/bin" "$vault/.obsidian" "$tmpdir/bin"
real_node=$(command -v node)
export REAL_NODE="$real_node" SERVICE_STATE="$tmpdir/loaded" SERVICE_LOG="$tmpdir/service.log"
export SETUP_READY=1

render() {
  local name=$1 os=$2 personal=$3 enabled=$4 data
  data=$(jq -n --arg home "$home" --arg vault "$vault" --arg os "$os" \
    --argjson personal "$personal" --argjson enabled "$enabled" \
    '{personal:$personal,work:false,homelab:false,ephemeral:false,headless:false,
      chezmoi:{os:$os,homeDir:$home},obsidian_headless:{enabled:$enabled,vault_path:$vault}}')
  chezmoi execute-template --config "$tmpdir/config.toml" --source "$repo_root" --override-data "$data" \
    --file "$repo_root/home/.chezmoiignore" >"$tmpdir/$name.ignore"
  chezmoi execute-template --config "$tmpdir/config.toml" --source "$repo_root" --override-data "$data" \
    --file "$repo_root/home/Library/LaunchAgents/private_com.brendan.obsidian-headless.plist.tmpl" >"$tmpdir/$name.plist"
  chezmoi execute-template --config "$tmpdir/config.toml" --source "$repo_root" --override-data "$data" \
    --file "$repo_root/home/.chezmoiscripts/darwin/run_onchange_after_configure-obsidian-headless.sh.tmpl" >"$tmpdir/$name.sh"
}
render enabled darwin true true
render disabled darwin true false
render work darwin false true
render linux linux true true

agent=Library/LaunchAgents/com.brendan.obsidian-headless.plist
if grep -Fxq "$agent" "$tmpdir/enabled.ignore"; then
  echo "Opted-in service must not be ignored" >&2
  exit 1
fi
for scope in disabled work linux; do grep -Fxq "$agent" "$tmpdir/$scope.ignore"; done
python3 - "$tmpdir/enabled.plist" "$home" "$vault" <<'PY'
import plistlib
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
assert agent["StandardOutPath"].startswith(home + "/Library/Logs/ObsidianHeadless/")
PY

cat >"$tmpdir/bin/launchctl" <<'SH'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$1" >>"$SERVICE_LOG"
case "$1" in
  print) test -f "$SERVICE_STATE" ;;
  bootout) rm "$SERVICE_STATE" ;;
  bootstrap) test -f "$3"; touch "$SERVICE_STATE" ;;
  *) exit 90 ;;
esac
SH
cat >"$home/.local/bin/mise" <<'SH'
#!/bin/bash
set -euo pipefail
[[ $1 == --cd && $2 == "$HOME" && $3 == exec && $4 == -- ]]
shift 4
case "$1" in
  ob)
    [[ $2 == sync-status && $3 == --path && -d $4 && $5 == --json ]]
    [[ $SETUP_READY == 1 ]]
    ;;
  node) shift; exec "$REAL_NODE" "$@" ;;
  *) exit 91 ;;
esac
SH
chmod +x "$tmpdir/bin/launchctl" "$home/.local/bin/mise"
mkdir -p "$home/Library/LaunchAgents" "$home/.obsidian-headless"
printf 'keep credentials\n' >"$home/.obsidian-headless/auth.json"
printf 'keep notes\n' >"$vault/note.md"
printf '[]\n' >"$vault/.obsidian/core-plugins.json"
cp "$tmpdir/enabled.plist" "$home/$agent"
run_hook() { HOME="$home" PATH="$tmpdir/bin:/usr/bin:/bin" bash "$tmpdir/$1.sh"; }

run_hook enabled
test -f "$SERVICE_STATE"
python3 - "$home/Library/Logs/ObsidianHeadless" <<'PY'
import os
import stat
import sys
assert stat.S_IMODE(os.stat(sys.argv[1]).st_mode) == 0o700
PY
run_hook enabled
[[ $(grep -c '^bootstrap$' "$SERVICE_LOG") == 2 ]]
[[ $(grep -c '^bootout$' "$SERVICE_LOG") == 1 ]]

SETUP_READY=0
if run_hook enabled; then echo 'Unlinked vault must not start syncing' >&2; exit 1; fi
test ! -f "$SERVICE_STATE"
SETUP_READY=1
for plugins in '["sync"]' '{"sync":true}'; do
  printf '%s\n' "$plugins" >"$vault/.obsidian/core-plugins.json"
  if run_hook enabled; then echo 'Desktop Sync must block headless startup' >&2; exit 1; fi
  test ! -f "$SERVICE_STATE"
done
printf '[]\n' >"$vault/.obsidian/core-plugins.json"
run_hook enabled
run_hook disabled
test ! -f "$SERVICE_STATE"
test ! -e "$home/$agent"
grep -Fxq 'keep credentials' "$home/.obsidian-headless/auth.json"
grep -Fxq 'keep notes' "$vault/note.md"
cp "$SERVICE_LOG" "$tmpdir/before-linux.log"
run_hook linux
cmp "$SERVICE_LOG" "$tmpdir/before-linux.log"
echo 'Headless Sync host opt-in, startup guards, restart and safe opt-out passed'
