#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_root="$repo_root/home"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

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

fixture="$tmpdir/repo"
mkdir -p "$fixture/home/.chezmoidata" "$fixture/.chezmoidata"
printf 'home\n' >"$fixture/.chezmoiroot"
printf '%s\n' 'theme: default' >"$fixture/home/.chezmoidata/defaults.yml"
printf '%s\n' 'themes:' '  default:' '  legacy:' >"$fixture/home/.chezmoidata/themes.yml"
printf 'theme: legacy\n' >"$fixture/.chezmoidata/local.yml"
git -C "$fixture" init -q

migration="$tmpdir/migrate.sh"
chezmoi execute-template --source "$fixture" \
  <"$source_root/.chezmoiscripts/run_once_before_migrate-source-root-local-data.sh.tmpl" \
  >"$migration"
bash "$migration"
[[ ! -e "$fixture/.chezmoidata/local.yml" ]]
grep -Fxq 'theme: legacy' "$fixture/home/.chezmoidata/local.yml"
[[ $(CHEZMOI_SOURCE_DIR="$fixture" bash "$source_root/dot_local/bin/executable_theme" --current) == legacy ]]

mkdir -p "$fixture/.chezmoidata"
printf 'theme: preserved\n' >"$fixture/.chezmoidata/local.yml"
printf 'theme: current\n' >"$fixture/home/.chezmoidata/local.yml"
bash "$migration" 2>"$tmpdir/migration-warning"
grep -Fxq 'theme: preserved' "$fixture/.chezmoidata/local.yml"
grep -Fxq 'theme: current' "$fixture/home/.chezmoidata/local.yml"
grep -Fq 'preserving legacy chezmoi data' "$tmpdir/migration-warning"

echo 'Chezmoi source root layout ok'
