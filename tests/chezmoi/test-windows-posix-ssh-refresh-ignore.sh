#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

ignored_for_os() {
  local os=$1
  local dest="$tmpdir/dest-$os"
  mkdir -p "$dest"
  chezmoi ignored \
    --source "$repo_root" \
    --destination "$dest" \
    --override-data '{"chezmoi":{"os":"'"$os"'"},"headless":false,"personal":true,"work":false,"homelab":false,"ephemeral":false}' \
    --no-tty
}

ssh_script=".chezmoiscripts/refresh-ssh-keys.sh"
ssh_helper=".local/bin/cz-ssh-refresh"

windows_ignored=$(ignored_for_os windows)
for path in "$ssh_script" "$ssh_helper"; do
  if ! grep -Fxq "$path" <<<"$windows_ignored"; then
    echo "expected Windows to ignore $path" >&2
    echo "$windows_ignored" >&2
    exit 1
  fi
done

for os in darwin linux; do
  ignored=$(ignored_for_os "$os")
  for path in "$ssh_script" "$ssh_helper"; do
    if grep -Fxq "$path" <<<"$ignored"; then
      echo "expected $os not to ignore $path" >&2
      echo "$ignored" >&2
      exit 1
    fi
  done
done

echo "windows posix ssh refresh ignore ok"
