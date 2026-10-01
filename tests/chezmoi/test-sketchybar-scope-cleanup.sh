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
  chezmoi execute-template --source "$repo_root" --override-data "$data" \
    <"$source_root/.chezmoiscripts/darwin/run_after_configure-menu-bar.sh.tmpl" \
    >"$tmpdir/$name.menu-bar"
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
  "$minimal_source/home/.chezmoiscripts/darwin" \
  "$minimal_source/home/dot_config/sketchybar" \
  "$tmpdir/bin" "$tmpdir/defaults" \
  "$home_dir/.local/bin" \
  "$home_dir/.config/zsh-patina"
printf 'home\n' >"$minimal_source/.chezmoiroot"
cp "$source_root/.chezmoiignore" "$minimal_source/home/.chezmoiignore"
cp "$source_root/.chezmoiremove.tmpl" "$minimal_source/home/.chezmoiremove.tmpl"
cp \
  "$source_root/.chezmoiscripts/run_onchange_before_remove-out-of-scope-sketchybar.sh.tmpl" \
  "$minimal_source/home/.chezmoiscripts/"
cp "$source_root/.chezmoiscripts/darwin/run_after_configure-menu-bar.sh.tmpl" \
  "$minimal_source/home/.chezmoiscripts/darwin/"

# Isolate preference reads/writes so these applies never touch the host macOS settings.
export DEFAULTS_STATE_DIR="$tmpdir/defaults"
export PATH="$tmpdir/bin:$PATH"
cat >"$tmpdir/bin/defaults" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  read) cat "$DEFAULTS_STATE_DIR/$3" ;;
  write)
    case "$5" in
      true) value=1 ;;
      false) value=0 ;;
      *) exit 1 ;;
    esac
    printf '%s\n' "$value" >"$DEFAULTS_STATE_DIR/$3"
    printf '%s\n' "$*" >>"$DEFAULTS_STATE_DIR/writes"
    ;;
  *) exit 1 ;;
esac
SH
cat >"$tmpdir/bin/killall" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$DEFAULTS_STATE_DIR/restarts"
exit 1
SH
chmod +x "$tmpdir/bin/defaults" "$tmpdir/bin/killall"

apply_fixture() {
  chezmoi apply \
    --source "$minimal_source" \
    --destination "$home_dir" \
    --config "$config_file" \
    --persistent-state "$tmpdir/state.boltdb" \
    --override-data "$override" \
    --no-tty
}

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

apply_fixture

# Missing preferences become desktop and fullscreen autohide, not fullscreen-only.
printf '%s\n' 'write -g _HIHideMenuBar -bool true' \
  'write -g AppleMenuBarVisibleInFullscreen -bool false' >"$tmpdir/expected-writes"
cmp "$tmpdir/expected-writes" "$DEFAULTS_STATE_DIR/writes"
grep -Fxq 1 "$DEFAULTS_STATE_DIR/_HIHideMenuBar"
grep -Fxq 0 "$DEFAULTS_STATE_DIR/AppleMenuBarVisibleInFullscreen"

# An unchanged apply is a no-op; drift is repaired on the next apply.
: >"$DEFAULTS_STATE_DIR/writes"
apply_fixture
[[ ! -s "$DEFAULTS_STATE_DIR/writes" ]]
printf '0\n' >"$DEFAULTS_STATE_DIR/_HIHideMenuBar"
apply_fixture
printf '%s\n' 'write -g _HIHideMenuBar -bool true' >"$tmpdir/expected-writes"
cmp "$tmpdir/expected-writes" "$DEFAULTS_STATE_DIR/writes"
: >"$DEFAULTS_STATE_DIR/writes"
printf '1\n' >"$DEFAULTS_STATE_DIR/AppleMenuBarVisibleInFullscreen"
apply_fixture
printf '%s\n' 'write -g AppleMenuBarVisibleInFullscreen -bool false' >"$tmpdir/expected-writes"
cmp "$tmpdir/expected-writes" "$DEFAULTS_STATE_DIR/writes"

# Out-of-scope machines keep their own preferences, even when they differ.
printf '0\n' >"$DEFAULTS_STATE_DIR/_HIHideMenuBar"
printf '1\n' >"$DEFAULTS_STATE_DIR/AppleMenuBarVisibleInFullscreen"
: >"$DEFAULTS_STATE_DIR/writes"
for scope in work-darwin personal-linux; do
  bash "$tmpdir/$scope.menu-bar"
done
[[ ! -s "$DEFAULTS_STATE_DIR/writes" ]]

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

apply_fixture

[[ ! -e "$home_dir/.config/sketchybar" ]]
[[ ! -s "$DEFAULTS_STATE_DIR/writes" ]]
grep -Fxq 0 "$DEFAULTS_STATE_DIR/_HIHideMenuBar"
grep -Fxq 1 "$DEFAULTS_STATE_DIR/AppleMenuBarVisibleInFullscreen"
[[ ! -e "$DEFAULTS_STATE_DIR/restarts" ]]

echo 'SketchyBar scope cleanup and menu-bar autohide ok'
