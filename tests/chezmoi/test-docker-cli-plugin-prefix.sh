#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_root="$repo_root/home"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin" "$tmp/source/cli-plugins" "$tmp/home"
cat >"$tmp/bin/brew" <<'SH'
#!/bin/sh
[ "$*" = --prefix ]
printf '%s\n' "$TEST_BREW_PREFIX"
SH
chmod +x "$tmp/bin/brew"

cp "$source_root"/dot_docker/cli-plugins/symlink_*.tmpl "$tmp/source/cli-plugins/"
printf '[data]\npersonal=true\n' >"$tmp/config.toml"

for prefix in /opt/homebrew /usr/local "$tmp/custom-brew"; do
  TEST_BREW_PREFIX="$prefix" PATH="$tmp/bin:$PATH" chezmoi apply \
    --source "$tmp/source" --destination "$tmp/home" --config "$tmp/config.toml" \
    --persistent-state "$tmp/state.boltdb" \
    --override-data '{"chezmoi":{"os":"darwin"}}' --no-tty

  for plugin in docker-compose docker-buildx; do
    [[ $(readlink "$tmp/home/cli-plugins/$plugin") == "$prefix/opt/$plugin/bin/$plugin" ]]
  done
done

echo 'Docker CLI plugins use the active Homebrew prefix'
