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

# Run the shortcuts without opening the real vault or editor.
chezmoi execute-template --source "$repo_root" --override-data "$darwin_data" \
  --file "$source_root/dot_config/zsh/exact_private_aliases.d/general.zsh.tmpl" \
  >"$tmpdir/aliases.zsh"
vault="$tmpdir/home with spaces/Notes/Obsidian/PKM"
mkdir -p "$vault"
run_shortcut() {
  HOME="$tmpdir/home with spaces" ALIASES_FILE="$tmpdir/aliases.zsh" VAULT="$vault" \
    NVIM_LOG="$tmpdir/nvim.log" NVIM_STATUS="${NVIM_STATUS:-0}" \
    zsh -fc '
      nvim() {
        printf "%s\0" "$PWD" "$@" >"$NVIM_LOG"
        return "$NVIM_STATUS"
      }
      source "$ALIASES_FILE"
      shortcut=$1
      shift
      eval "$shortcut \"\$@\""
      result=$?
      [[ $result != 0 ]] && exit "$result"
      [[ $PWD -ef $VAULT ]]
    ' zsh "$@"
}

for shortcut in ov obv; do
  run_shortcut "$shortcut"
  [[ ! -e "$tmpdir/nvim.log" ]]
done

for shortcut in obf obn obr odb; do
  run_shortcut "$shortcut"
  cp "$tmpdir/nvim.log" "$tmpdir/$shortcut.log"
done
run_shortcut obr 'folder/My note.md' '-draft.md'
cp "$tmpdir/nvim.log" "$tmpdir/explicit.log"

python3 - "$tmpdir" "$vault" <<'PY'
import sys
from pathlib import Path

root, vault = Path(sys.argv[1]), sys.argv[2]
commands = {}
for shortcut in ("obf", "obn", "obr", "odb"):
    cwd, flag, command, end = (root / f"{shortcut}.log").read_bytes().decode().split("\0")
    assert cwd == vault and flag == "-c" and end == "", shortcut
    commands[shortcut] = command
assert commands["obf"] == 'lua require("fff").find_files()'
assert commands["obn"] == 'lua require("obsidian"); require("user.obsidian.templates").pick()'
assert commands["odb"] == "Obsidian today"
# Resume uses directory sessions, never AstroNvim's global Last Session.
assert 'require("resession")' in commands["obr"]
assert 'dir = "dirsession"' in commands["obr"]
assert "Last Session" not in commands["obr"]
(root / "resume.vim").write_text(commands["obr"] + "\n")
assert (root / "explicit.log").read_bytes().decode().split("\0") == [
    vault, "--", "folder/My note.md", "-draft.md", ""
]
PY

# Exercise the actual session API locally; CI does not install Neovim plugins.
plugin_root=${NVIM_PLUGIN_ROOT:-"${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy"}
if command -v nvim >/dev/null && [[ -d "$plugin_root/resession.nvim" ]]; then
  cat >"$tmpdir/resume.lua" <<'LUA'
vim.opt.rtp:prepend(vim.env.RESESSION_PLUGIN)
vim.opt.swapfile = false
vim.cmd.cd(vim.env.VAULT)
local session = require("resession")
session.setup({})
local picks = 0
package.preload.fff = function()
  return { find_files = function() picks = picks + 1 end }
end
local resume = table.concat(vim.fn.readfile(vim.env.RESUME_COMMAND), "\n")
local note = vim.fn.getcwd() .. "/session note.md"
vim.fn.writefile({ "# Session fixture" }, note)
vim.cmd.edit(vim.fn.fnameescape(note))
session.save("Last Session", { notify = false })
session.detach()
vim.cmd.enew()

-- A global session must not prevent the missing-vault-session picker fallback.
vim.cmd(resume)
assert(picks == 1 and session.get_current() == nil)
assert(vim.api.nvim_buf_get_name(0) == "")

-- Directory names contain path separators; list() returns encoded filenames.
vim.cmd.edit(vim.fn.fnameescape(note))
session.save(vim.fn.getcwd(), { dir = "dirsession", notify = false })
session.detach()
vim.cmd.enew()
vim.cmd(resume)
assert(picks == 1, "saved vault session fell back to picker")
assert(vim.api.nvim_buf_get_name(0) == note, "saved note was not restored")
vim.fn.delete(note)
print("Obsidian resume and missing-session fallback ok")
LUA
  HOME="$tmpdir/home with spaces" XDG_CONFIG_HOME="$tmpdir/config" \
    XDG_DATA_HOME="$tmpdir/data" XDG_STATE_HOME="$tmpdir/state" XDG_CACHE_HOME="$tmpdir/cache" \
    VAULT="$vault" RESESSION_PLUGIN="$plugin_root/resession.nvim" \
    RESUME_COMMAND="$tmpdir/resume.vim" \
    nvim --headless -u NONE -i NONE -l "$tmpdir/resume.lua"
else
  echo 'SKIP Obsidian resume integration (Neovim or resession.nvim not installed)'
fi

# Preserve editor failures and never launch it when the vault is missing.
for shortcut in obf obn obr odb; do
  status=0
  NVIM_STATUS=23 run_shortcut "$shortcut" || status=$?
  [[ $status == 23 ]]
done
rmdir "$vault"
for shortcut in ov obv obf obn obr odb; do
  rm -f "$tmpdir/nvim.log"
  if run_shortcut "$shortcut" 2>"$tmpdir/missing-vault.err"; then
    echo "$shortcut succeeded without a vault" >&2
    exit 1
  fi
  [[ ! -e "$tmpdir/nvim.log" ]]
done

echo 'Obsidian CLI path registration and vault shortcuts ok'
