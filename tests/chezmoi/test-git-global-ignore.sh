#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# Git reads $XDG_CONFIG_HOME/git/ignore without a core.excludesFile setting.
fixture_source="$tmpdir/source"
fixture_home="$tmpdir/home"
config_file="$tmpdir/chezmoi.toml"
mkdir -p "$fixture_source/dot_config/git" "$fixture_home"
: >"$config_file"
cp "$repo_root/home/dot_config/git/ignore" "$fixture_source/dot_config/git/ignore"
HOME="$fixture_home" chezmoi apply --source "$fixture_source" \
  --destination "$fixture_home" --config "$config_file" --force --no-tty

repo="$tmpdir/repo"
git init -q "$repo"
mkdir -p "$repo/.serena" "$repo/.memory/session" "$repo/src"
check() {
  HOME="$fixture_home" XDG_CONFIG_HOME="$fixture_home/.config" GIT_CONFIG_NOSYSTEM=1 \
    git -C "$repo" check-ignore -q "$1"
}
for path in .DS_Store src/.DS_Store .serena/project.yml .memory/session/state.json; do
  check "$path" || { echo "global ignore misses $path" >&2; exit 1; }
done
if check src/index.ts; then
  echo 'global ignore hides ordinary source files' >&2
  exit 1
fi
echo 'git global ignore ok'
