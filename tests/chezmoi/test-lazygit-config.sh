#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_root="$repo_root/home"
template="$source_root/dot_config/lazygit/config.yml.tmpl"
symlink_template="$source_root/Library/Application Support/lazygit/symlink_config.yml.tmpl"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# LazyGit migrates the old git.pagers/pager shape to this schema on startup.
rendered=$(chezmoi execute-template --source "$repo_root" \
  --override-data '{"theme":"black-metal-bathory"}' --file "$template")
grep -Fxq '  diffRenderers:' <<<"$rendered"
grep -Fxq '    - command: hunk pager' <<<"$rendered"
if grep -Fxq '  pagers:' <<<"$rendered"; then
  echo 'legacy git.pagers syntax is still rendered' >&2
  exit 1
fi

# Both macOS and XDG paths must resolve to the same managed file, not two
# independently managed copies that can drift.
fixture_source="$tmpdir/source"
fixture_home="$tmpdir/home"
config_file="$tmpdir/chezmoi.toml"
mkdir -p \
  "$fixture_source/dot_config/lazygit" \
  "$fixture_source/Library/Application Support/lazygit" \
  "$fixture_home"
: >"$config_file"
printf '%s\n' "$rendered" >"$fixture_source/dot_config/lazygit/config.yml"
cp "$symlink_template" \
  "$fixture_source/Library/Application Support/lazygit/symlink_config.yml.tmpl"

HOME="$fixture_home" chezmoi apply --source "$fixture_source" \
  --destination "$fixture_home" --config "$config_file" --force --no-tty

xdg_config="$fixture_home/.config/lazygit/config.yml"
mac_config="$fixture_home/Library/Application Support/lazygit/config.yml"
[[ -f "$xdg_config" ]]
[[ -L "$mac_config" ]]
[[ $(readlink "$mac_config") == "$xdg_config" ]]
cmp "$xdg_config" "$fixture_source/dot_config/lazygit/config.yml"

# Reapplying the rendered shape must be a no-op.
[[ -z $(HOME="$fixture_home" chezmoi diff --source "$fixture_source" \
  --destination "$fixture_home" --config "$config_file" --no-pager) ]]
echo 'lazygit config schema and macOS alias ok'
