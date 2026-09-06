#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_root="$repo_root/home"
aliases_file="$source_root/dot_config/zsh/exact_aliases.d/chezmoi.zsh.tmpl"
ignore_file="$source_root/.chezmoiignore"
remove_file="$source_root/.chezmoiremove.tmpl"
chezmoi_bin=$(command -v chezmoi)
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/chezmoi-library-aliases.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT

fixture_source="$tmpdir/source"
fixture_home="$tmpdir/home"
config_file="$tmpdir/chezmoi.toml"
mkdir -p \
  "$fixture_source/private_Library/Nested" \
  "$fixture_source/.chezmoiscripts" \
  "$fixture_home"
: >"$config_file"

printf 'source plain\n' >"$fixture_source/private_Library/Nested/plain.txt"
printf 'rendered {{ "template" }}\n' >"$fixture_source/private_Library/template.txt.tmpl"
printf 'Nested/plain.txt\n' >"$fixture_source/private_Library/symlink_link.txt"
printf 'outside source\n' >"$fixture_source/outside.txt"
printf 'outside target\n' >"$fixture_home/outside.txt"
cat >"$fixture_source/.chezmoiscripts/run_after_library-side-effect.sh" <<'SCRIPT'
#!/bin/sh
printf 'script ran\n' >"$HOME/library-script-ran"
SCRIPT
cat >"$fixture_source/.chezmoiexternal.toml" <<EXTERNAL
["Library/external.txt"]
    type = "file"
    url = "file://$tmpdir/does-not-exist"
EXTERNAL

run_alias() {
  local alias_name=$1
  shift

  HOME="$fixture_home" \
  ALIASES_FILE="$aliases_file" \
  CHEZMOI_BIN="$chezmoi_bin" \
  FIXTURE_SOURCE="$fixture_source" \
  CONFIG_FILE="$config_file" \
    zsh -fc '
      chezmoi() {
        command "$CHEZMOI_BIN" \
          --source "$FIXTURE_SOURCE" \
          --destination "$HOME" \
          --config "$CONFIG_FILE" \
          "$@"
      }
      source "$ALIASES_FILE"
      "$@"
    ' zsh "$alias_name" "$@"
}

# Native target semantics map private_Library to ~/Library and recurse without side effects.
run_alias cz-lib-apply --dry-run --verbose >"$tmpdir/apply-dry-run.out"
[[ ! -e "$fixture_home/Library" ]]
[[ ! -e "$fixture_home/library-script-ran" ]]

run_alias cz-lib-apply --force >"$tmpdir/apply.out"
python3 - "$fixture_home" <<'PY'
import os
import stat
import sys
from pathlib import Path

home = Path(sys.argv[1])
library = home / "Library"
assert library.is_dir()
assert stat.S_IMODE(library.stat().st_mode) & 0o077 == 0
assert (library / "Nested/plain.txt").read_text() == "source plain\n"
assert (library / "template.txt").read_text() == "rendered template\n"
assert (library / "link.txt").is_symlink()
assert os.readlink(library / "link.txt") == "Nested/plain.txt"
assert not (library / "external.txt").exists()
assert not (home / "library-script-ran").exists()
assert (home / "outside.txt").read_text() == "outside target\n"
PY

# Re-add uses the same recursive Library target and dry-run leaves source unchanged.
printf 'target edit\n' >"$fixture_home/Library/Nested/plain.txt"
run_alias cz-lib-readd --dry-run >"$tmpdir/readd-dry-run.out"
grep -Fxq 'source plain' "$fixture_source/private_Library/Nested/plain.txt"
run_alias cz-lib-readd >"$tmpdir/readd.out"
grep -Fxq 'target edit' "$fixture_source/private_Library/Nested/plain.txt"
grep -Fxq 'rendered {{ "template" }}' "$fixture_source/private_Library/template.txt.tmpl"
grep -Fxq 'outside source' "$fixture_source/outside.txt"
grep -Fxq 'outside target' "$fixture_home/outside.txt"

# Arbitrary chezmoi flags are forwarded and failures remain visible to callers.
if run_alias cz-lib-apply --definitely-invalid >"$tmpdir/apply-error.out" 2>&1; then
  echo 'cz-lib-apply hid a chezmoi argument error' >&2
  exit 1
fi
if run_alias cz-lib-readd --definitely-invalid >"$tmpdir/readd-error.out" 2>&1; then
  echo 'cz-lib-readd hid a chezmoi argument error' >&2
  exit 1
fi

# Retirement must work on macOS despite the broad .local/bin ignore rule.
cleanup_source="$tmpdir/cleanup"
mkdir -p "$cleanup_source" "$fixture_home/.local/bin"
role='{"personal":true,"work":false,"homelab":false,"ephemeral":false,"headless":false,"chezmoi":{"os":"darwin"}}'
chezmoi execute-template --source "$repo_root" --override-data "$role" \
  --file "$ignore_file" >"$cleanup_source/.chezmoiignore"
chezmoi execute-template --source "$repo_root" --override-data "$role" \
  --file "$remove_file" >"$cleanup_source/.chezmoiremove"
for name in chezmoi-apply-library chezmoi-readd-library unrelated; do
  printf 'old binary\n' >"$fixture_home/.local/bin/$name"
done
HOME="$fixture_home" "$chezmoi_bin" apply --source "$cleanup_source" \
  --destination "$fixture_home" --config "$config_file" --no-tty --force
[[ ! -e "$fixture_home/.local/bin/chezmoi-apply-library" ]]
[[ ! -e "$fixture_home/.local/bin/chezmoi-readd-library" ]]
[[ -f "$fixture_home/.local/bin/unrelated" ]]
echo 'native Library operations and helper retirement ok'
