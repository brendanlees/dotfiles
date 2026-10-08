#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_root="$repo_root/home"

# Use fixtures instead of duplicating the package inventory.
for role in personal work homelab; do
  case "$role" in
    personal)
      flags='"personal":true,"work":false'; expected='["base","personal"]'
      data='{"personal":true,"work":false,"homelab":false,"chezmoi":{"os":"darwin"}}'
      ;;
    work)
      flags='"personal":false,"work":true'; expected='["base","work"]'
      data='{"personal":false,"work":true,"homelab":false,"chezmoi":{"os":"darwin"}}'
      ;;
    homelab)
      flags='"personal":false,"work":false'; expected='["base"]'
      data='{"personal":false,"work":false,"homelab":true,"chezmoi":{"os":"darwin"}}'
      ;;
  esac

  fixture="{$flags,\"brews\":{\"base\":[\"base\"],\"personal\":[\"personal\"],\"work\":[\"work\"]}}"
  merged=$(chezmoi execute-template --source "$repo_root" --override-data "$fixture" \
    '{{ includeTemplate ".chezmoitemplates/merge-by-role.tmpl" (list .brews .) }}')
  [[ "$merged" == "$expected" ]]

  for template in "$source_root"/.chezmoiscripts/darwin/*install-packages-*.tmpl; do
    chezmoi execute-template --source "$repo_root" --override-data "$data" \
      <"$template" >/dev/null
  done
done

echo 'Darwin package roles render successfully'
