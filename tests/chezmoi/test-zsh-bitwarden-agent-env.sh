#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

rendered_zshrc="$tmpdir/zshrc"

chezmoi execute-template \
  --source "$repo_root" \
  --override-data '{"personal":true,"work":false,"homelab":false,"headless":false,"ephemeral":false}' \
  --file "$repo_root/dot_zshrc.tmpl" \
  > "$rendered_zshrc"

# shellcheck disable=SC2016
expected='export BITWARDEN_SSH_AUTH_SOCK="${BITWARDEN_SSH_AUTH_SOCK:-$HOME/.bitwarden-ssh-agent.sock}"'
if ! grep -Fqx -- "$expected" "$rendered_zshrc"; then
  echo "missing Bitwarden SSH Agent socket default export in rendered zshrc" >&2
  exit 1
fi

if grep -Eq '^[[:space:]]*(export[[:space:]]+)?SSH_AUTH_SOCK=' "$rendered_zshrc"; then
  echo "rendered zshrc must not set or override SSH_AUTH_SOCK" >&2
  exit 1
fi

echo "zsh Bitwarden SSH Agent env ok"
