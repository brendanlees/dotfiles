#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

data='{"personal":true,"work":false,"homelab":false,"headless":false,"ephemeral":false,"theme":"guts","chezmoi":{"os":"darwin","username":"test"}}'
chezmoi execute-template --source "$repo_root" --override-data "$data" \
  --file "$repo_root/home/dot_zshrc.tmpl" >"$tmpdir/zshrc"
grep -Fxq 'export PI_CACHE_RETENTION=long' "$tmpdir/zshrc"

echo 'Pi cache retention export renders correctly'
