#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_root="$repo_root/home"
[[ $(<"$repo_root/.chezmoiroot") == home ]]
[[ $(chezmoi source-path --source "$repo_root") == "$source_root" ]]

for path in AGENTS.md README.md agents docs install.sh tests; do
  [[ -e "$repo_root/$path" ]]
  [[ ! -e "$source_root/$path" ]]
done
if grep -Eq '^(AGENTS\.md|README\.md|agents|docs|install\.sh|tests)$' \
    "$source_root/.chezmoiignore"; then
  echo 'repository-only paths must not be listed in the source-state ignore file' >&2
  exit 1
fi

echo 'Chezmoi source root layout ok'
