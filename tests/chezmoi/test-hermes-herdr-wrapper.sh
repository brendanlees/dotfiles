#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_root="$repo_root/home"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

rendered_zshrc="$tmpdir/zshrc"

chezmoi execute-template \
  --source "$repo_root" \
  --override-data '{"personal":true,"work":false,"homelab":false,"headless":false,"ephemeral":false}' \
  --file "$source_root/dot_zshrc.tmpl" \
  > "$rendered_zshrc"

expected='hermes() { HERDR_AGENT=hermes docker exec -u hermes -it hermes /opt/hermes/.venv/bin/hermes "$@"; }'
if ! grep -Fqx -- "$expected" "$rendered_zshrc"; then
  echo "rendered Hermes wrapper must expose the scoped Herdr agent hint" >&2
  exit 1
fi

if grep -Eq '^[[:space:]]*export[[:space:]]+HERDR_AGENT=' "$rendered_zshrc"; then
  echo "rendered zshrc must not export HERDR_AGENT globally" >&2
  exit 1
fi

zsh -n "$rendered_zshrc"
echo "Hermes Herdr wrapper hint ok"
