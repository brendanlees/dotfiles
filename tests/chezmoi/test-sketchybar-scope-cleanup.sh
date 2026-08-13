#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_root="$repo_root/home"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

render_scope() {
  local name=$1
  local data=$2

  chezmoi execute-template --source "$repo_root" --override-data "$data" \
    <"$source_root/.chezmoiignore" >"$tmpdir/$name.ignore"
  chezmoi execute-template --source "$repo_root" --override-data "$data" \
    <"$source_root/.chezmoiremove.tmpl" >"$tmpdir/$name.remove"
}

assert_has() { grep -Fxq "$2" "$tmpdir/$1.$3"; }
assert_lacks() { ! grep -Fxq "$2" "$tmpdir/$1.$3"; }

personal_darwin='{"personal":true,"work":false,"homelab":false,"ephemeral":false,"headless":false,"chezmoi":{"os":"darwin"}}'
work_darwin='{"personal":false,"work":true,"homelab":false,"ephemeral":false,"headless":false,"chezmoi":{"os":"darwin"}}'
personal_linux='{"personal":true,"work":false,"homelab":false,"ephemeral":false,"headless":false,"chezmoi":{"os":"linux"}}'

render_scope personal-darwin "$personal_darwin"
render_scope work-darwin "$work_darwin"
render_scope personal-linux "$personal_linux"

assert_lacks personal-darwin '.config/sketchybar' ignore
assert_lacks personal-darwin '.config/sketchybar' remove
assert_has work-darwin '.config/sketchybar' ignore
assert_has work-darwin '.config/sketchybar' remove
assert_has personal-linux '.config/sketchybar' ignore
assert_has personal-linux '.config/sketchybar' remove

for scope in personal-darwin work-darwin personal-linux; do
  assert_has "$scope" '.local/bin/zsh-patina' remove
  assert_has "$scope" '.config/zsh-patina' remove
done

minimal_source="$tmpdir/source"
home_dir="$tmpdir/home"
config_file="$tmpdir/chezmoi.toml"
override=$(printf '{"chezmoi":{"os":"darwin","homeDir":"%s"}}' "$home_dir")
mkdir -p \
  "$minimal_source/home/.chezmoiscripts" \
  "$minimal_source/home/dot_config/sketchybar" \
  "$home_dir/.local/bin" \
  "$home_dir/.config/zsh-patina"
printf 'home\n' >"$minimal_source/.chezmoiroot"
cp "$source_root/.chezmoiignore" "$minimal_source/home/.chezmoiignore"
cp "$source_root/.chezmoiremove.tmpl" "$minimal_source/home/.chezmoiremove.tmpl"
cp \
  "$source_root/.chezmoiscripts/run_onchange_before_remove-out-of-scope-sketchybar.sh.tmpl" \
  "$minimal_source/home/.chezmoiscripts/"
printf 'managed\n' >"$minimal_source/home/dot_config/sketchybar/marker"
printf 'stale\n' >"$home_dir/.local/bin/zsh-patina"
printf 'stale\n' >"$home_dir/.config/zsh-patina/config.toml"
printf '%s\n' \
  '[data]' \
  'personal = true' \
  'work = false' \
  'homelab = false' \
  'ephemeral = false' \
  'headless = false' \
  >"$config_file"

chezmoi apply \
  --source "$minimal_source" \
  --destination "$home_dir" \
  --config "$config_file" \
  --override-data "$override" \
  --no-tty

[[ -f "$home_dir/.config/sketchybar/marker" ]]
[[ ! -e "$home_dir/.local/bin/zsh-patina" ]]
[[ ! -e "$home_dir/.config/zsh-patina" ]]

printf '%s\n' \
  '[data]' \
  'personal = false' \
  'work = true' \
  'homelab = false' \
  'ephemeral = false' \
  'headless = false' \
  >"$config_file"

chezmoi apply \
  --source "$minimal_source" \
  --destination "$home_dir" \
  --config "$config_file" \
  --override-data "$override" \
  --no-tty

[[ ! -e "$home_dir/.config/sketchybar" ]]

echo 'SketchyBar scope cleanup ok'
