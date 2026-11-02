#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
: >"$tmpdir/config.toml"
mkdir -p "$tmpdir/bin"
chezmoi_bin=$(command -v chezmoi)
hook=darwin/run_once_before_remove-obsidian-sync-automation.sh

cat >"$tmpdir/bin/launchctl" <<'SH'
#!/bin/bash
set -euo pipefail
[[ $2 == "gui/$(id -u)/com.brendan.obsidian-headless" ]]
printf '%s\n' "$1" >>"$SERVICE_LOG"
case "$1" in
  print) test -f "$SERVICE_STATE" ;;
  bootout)
    test -f "$HOME/Library/LaunchAgents/com.brendan.obsidian-headless.plist"
    [[ ${FAIL_BOOTOUT:-0} == 0 ]] || exit 42
    rm "$SERVICE_STATE"
    ;;
  *) exit 90 ;;
esac
SH
chmod +x "$tmpdir/bin/launchctl"

retired=(
  .local/bin/cz-obsidian
  Library/LaunchAgents/com.brendan.obsidian-headless.plist
  .config/obsidian-headless/setup.json
)
retained=(
  .obsidian-headless/auth_token
  .obsidian-headless/sync/vault.json
  "Notes/PKM's Vault/note.md"
  Library/Logs/ObsidianHeadless/sync.log
  Library/LaunchAgents/unrelated.plist
  .config/obsidian-headless/unrelated.json
)

for scope in personal work linux fresh; do
  home="$tmpdir/$scope home"
  source="$tmpdir/$scope source"
  mkdir -p "$home" "$source/.chezmoiscripts/darwin"
  os=darwin personal=true
  [[ $scope != work ]] || personal=false
  [[ $scope != linux ]] || os=linux
  data=$(jq -n --arg os "$os" --argjson personal "$personal" \
    '{personal:$personal,work:true,homelab:false,ephemeral:false,headless:false,chezmoi:{os:$os}}')
  chezmoi execute-template --source "$repo_root" --config "$tmpdir/config.toml" \
    --override-data "$data" --file "$repo_root/home/.chezmoiignore" >"$source/.chezmoiignore"
  chezmoi execute-template --source "$repo_root" --config "$tmpdir/config.toml" \
    --override-data "$data" --file "$repo_root/home/.chezmoiscripts/$hook.tmpl" \
    >"$source/.chezmoiscripts/$hook"
  export SERVICE_STATE="$tmpdir/$scope.loaded" SERVICE_LOG="$tmpdir/$scope.log"
  if [[ $scope != fresh ]]; then
    for file in "${retired[@]}" "${retained[@]}"; do
      mkdir -p "$home/$(dirname "$file")"
      printf 'keep contents\n' >"$home/$file"
    done
    touch "$SERVICE_STATE"
  fi
  apply() {
    HOME="$home" PATH="$tmpdir/bin:/usr/bin:/bin" "$chezmoi_bin" apply \
      --source "$source" --destination "$home" --config "$tmpdir/config.toml" \
      --persistent-state "$tmpdir/$scope.boltdb" --no-tty --force
  }
  if [[ $scope == personal ]]; then
    # Failed unloading must leave the installation intact and permit a retry.
    if FAIL_BOOTOUT=1 apply; then
      echo 'Unloading failure must fail apply' >&2
      exit 1
    fi
    test -f "$SERVICE_STATE"
    for file in "${retired[@]}"; do test -f "$home/$file"; done
  fi
  apply
  if [[ $scope == linux ]]; then
    test -f "$SERVICE_STATE"
    test ! -f "$SERVICE_LOG"
    for file in "${retired[@]}"; do test -f "$home/$file"; done
  else
    test ! -f "$SERVICE_STATE"
    for file in "${retired[@]}"; do test ! -e "$home/$file"; done
    [[ $scope == fresh ]] || grep -Fxq 'bootout' "$SERVICE_LOG"
    cp "$SERVICE_LOG" "$tmpdir/before.log"
    apply
    cmp "$SERVICE_LOG" "$tmpdir/before.log"
  fi
  if [[ $scope != fresh ]]; then
    for file in "${retained[@]}"; do grep -Fxq 'keep contents' "$home/$file"; done
  fi
done

echo 'Obsidian automation retirement, safe retry, fresh install and credential preservation passed'
