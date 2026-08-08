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

assert_ignored() {
  local haystack=$1 path=$2 label=$3
  if ! grep -Fxq "$path" <<<"$haystack"; then
    echo "expected $label to ignore $path" >&2
    echo "$haystack" >&2
    exit 1
  fi
}

assert_not_ignored() {
  local haystack=$1 path=$2 label=$3
  if grep -Fxq "$path" <<<"$haystack"; then
    echo "expected $label not to ignore $path" >&2
    echo "$haystack" >&2
    exit 1
  fi
}

posix_runner=".chezmoiscripts/refresh-ssh-keys.sh"
windows_runner=".chezmoiscripts/windows/refresh-ssh-keys.ps1"
posix_helper=".local/bin/cz-ssh-refresh"
windows_helper=".local/bin/cz-ssh-refresh.ps1"
posix_migration=".chezmoiscripts/migrate-source-root-local-data.sh"
windows_migration=".chezmoiscripts/windows/migrate-source-root-local-data.ps1"

windows_ignored=$(ignored_for_os windows)
assert_ignored "$windows_ignored" "$posix_runner" windows
assert_ignored "$windows_ignored" "$posix_helper" windows
assert_ignored "$windows_ignored" "$posix_migration" windows
assert_not_ignored "$windows_ignored" "$windows_runner" windows
assert_not_ignored "$windows_ignored" "$windows_helper" windows
assert_not_ignored "$windows_ignored" "$windows_migration" windows

for os in darwin linux; do
  ignored=$(ignored_for_os "$os")
  assert_not_ignored "$ignored" "$posix_runner" "$os"
  assert_not_ignored "$ignored" "$posix_helper" "$os"
  assert_not_ignored "$ignored" "$posix_migration" "$os"
  assert_ignored "$ignored" "$windows_runner" "$os"
  assert_ignored "$ignored" "$windows_helper" "$os"
  assert_ignored "$ignored" "$windows_migration" "$os"
done

echo "OS-specific script target selection ok"
