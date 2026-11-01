#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_root="$repo_root/home"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# Path selection must not download unrelated external archives.
fixture_source="$tmpdir/source"
cp -R "$repo_root/home" "$fixture_source"
rm "$fixture_source/.chezmoiexternal.toml.tmpl"

darwin_data='{"personal":true,"work":false,"homelab":false,"headless":false,"ephemeral":false,"chezmoi":{"os":"darwin","username":"test"}}'
linux_data='{"personal":true,"work":false,"homelab":false,"headless":false,"ephemeral":false,"chezmoi":{"os":"linux","username":"test"}}'

link_target=$(<"$source_root/dot_local/bin/symlink_obsidian.tmpl")
[[ $link_target == /Applications/Obsidian.app/Contents/MacOS/obsidian-cli ]]

chezmoi execute-template --source "$repo_root" --override-data "$darwin_data" \
  --file "$source_root/dot_zshrc.tmpl" >"$tmpdir/darwin.zshrc"
# shellcheck disable=SC2016 # Match the literal rendered PATH assignment.
expected_path='export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"'
grep -Fqx -- "$expected_path" "$tmpdir/darwin.zshrc"

chezmoi execute-template --source "$repo_root" --override-data "$darwin_data" \
  <"$source_root/.chezmoiignore" >"$tmpdir/darwin.ignore"
grep -Fqx '!.local/bin/obsidian' "$tmpdir/darwin.ignore"

chezmoi execute-template --source "$repo_root" --override-data "$linux_data" \
  <"$source_root/.chezmoiignore" >"$tmpdir/linux.ignore"
grep -Fqx '.local/bin/obsidian' "$tmpdir/linux.ignore"

managed_darwin=$(chezmoi managed --source "$fixture_source" --override-data "$darwin_data")
grep -Fxq '.local/bin/obsidian' <<<"$managed_darwin"
managed_linux=$(chezmoi managed --source "$fixture_source" --override-data "$linux_data")
if grep -Fxq '.local/bin/obsidian' <<<"$managed_linux"; then
  echo 'Obsidian CLI link must be macOS-only' >&2
  exit 1
fi

define_fixture() {
  local os=$1
  local fixture="$tmpdir/$os/source"
  local destination="$tmpdir/$os/home"
  local config="$tmpdir/$os/config.toml"

  mkdir -p "$fixture/home/dot_local/bin" "$destination"
  printf 'home\n' >"$fixture/.chezmoiroot"
  cp "$source_root/.chezmoiignore" "$fixture/home/.chezmoiignore"
  cp "$source_root/dot_local/bin/symlink_obsidian.tmpl" \
    "$fixture/home/dot_local/bin/symlink_obsidian.tmpl"
  mkdir -p "${config%/*}"
  printf '%s\n' \
    '[data]' \
    'personal = true' \
    'work = false' \
    'homelab = false' \
    'ephemeral = false' \
    'headless = false' >"$config"

  chezmoi apply --source "$fixture" --config "$config" \
    --destination "$destination" --override-data "{\"chezmoi\":{\"os\":\"$os\"}}" \
    --no-tty
}

define_fixture darwin
[[ -L "$tmpdir/darwin/home/.local/bin/obsidian" ]]
[[ $(readlink "$tmpdir/darwin/home/.local/bin/obsidian") == "$link_target" ]]

define_fixture linux
[[ ! -e "$tmpdir/linux/home/.local/bin/obsidian" && \
  ! -L "$tmpdir/linux/home/.local/bin/obsidian" ]]

# Start inside the vault, but do not open a directory buffer: Neo-tree would
# steal focus from the daily note. Preserve the calling shell's working directory.
chezmoi execute-template --source "$repo_root" --override-data "$darwin_data" \
  --file "$source_root/dot_config/zsh/exact_aliases.d/general.zsh.tmpl" \
  >"$tmpdir/aliases.zsh"
vault="$tmpdir/home with spaces/Notes/Obsidian/Vaults/PKM Vault/PKM"
mkdir -p "$tmpdir/bin" "$vault"
cat >"$tmpdir/bin/nvim" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$OV_TEST_LOG"
pwd -P >"$OV_TEST_LOG.cwd"
SH
chmod +x "$tmpdir/bin/nvim"

OV_TEST_LOG="$tmpdir/nvim.log" HOME="$tmpdir/home with spaces" \
  PATH="$tmpdir/bin:$PATH" ALIASES_FILE="$tmpdir/aliases.zsh" \
  zsh -fc 'alias ov=false; source "$ALIASES_FILE"; before=$PWD; eval "ov --headless"; [[ $PWD == $before ]]'

printf '%s\n' \
  '-c' 'Obsidian today' \
  '--headless' >"$tmpdir/expected.log"
cmp "$tmpdir/expected.log" "$tmpdir/nvim.log"
(cd "$vault" && pwd -P) >"$tmpdir/expected.cwd"
cmp "$tmpdir/expected.cwd" "$tmpdir/nvim.log.cwd"

# A missing vault must fail rather than launching an editor in the wrong directory.
if OV_TEST_LOG="$tmpdir/missing.log" HOME="$tmpdir/missing home" \
  PATH="$tmpdir/bin:$PATH" ALIASES_FILE="$tmpdir/aliases.zsh" \
  zsh -fc 'source "$ALIASES_FILE"; eval ov' >"$tmpdir/missing.out" 2>&1; then
  echo 'ov must fail when the vault is missing' >&2
  exit 1
fi
[[ ! -e "$tmpdir/missing.log" ]]

echo 'Obsidian CLI path registration and Neovim daily-note shortcut ok'
