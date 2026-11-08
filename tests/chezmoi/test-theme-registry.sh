#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_root="$repo_root/home"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

chezmoi data --source "$repo_root" --format json >"$tmpdir/data.json"

# Exercise theme switching through real chezmoi, with no access to live apps.
fixture="$tmpdir/source"
home="$tmpdir/home"
mkdir -p "$fixture/.chezmoidata" "$fixture/.chezmoitemplates" \
  "$fixture/.chezmoiscripts/darwin" "$fixture/dot_config/borders" "$tmpdir/bin" "$home"
mkdir -p "$home/.config/chezmoi-theme"
cat >"$home/.config/chezmoi-theme/obsidian-sync" <<'SCRIPT'
#!/bin/sh
printf '%s\n' "$@" >"$HOME/obsidian-sync-args"
SCRIPT
chmod +x "$home/.config/chezmoi-theme/obsidian-sync"
# Two synthetic choices keep picker tests independent of the theme inventory.
python3 - "$tmpdir/data.json" "$fixture/.chezmoidata/themes.yml" <<'PY'
import json
import sys
from pathlib import Path
sample = next(iter(json.loads(Path(sys.argv[1]).read_text())["themes"].values()))
Path(sys.argv[2]).write_text("themes:\n" + "".join(
    f"  {name}:\n    {json.dumps(sample)}\n" for name in ("first", "second")
))
PY
printf 'theme: first\n' >"$fixture/.chezmoidata/defaults.yml"
cp "$fixture/.chezmoidata/defaults.yml" "$tmpdir/defaults.before"
cp "$source_root/dot_config/borders/executable_bordersrc.tmpl" "$fixture/dot_config/borders/"
cp "$source_root/.chezmoitemplates/pi-theme.json.tmpl" \
  "$source_root/.chezmoitemplates/claude-theme.json.tmpl" \
  "$source_root/.chezmoitemplates/private-harness-ready.tmpl" "$fixture/.chezmoitemplates/"
cp "$source_root/.chezmoiscripts/run_onchange_after_configure-pi-theme.py.tmpl" \
  "$source_root/.chezmoiscripts/run_onchange_after_configure-claude-theme.py.tmpl" "$fixture/.chezmoiscripts/"
printf '{{ .theme }}\n' >"$fixture/dot_config/active-theme.tmpl"
cat >"$fixture/.chezmoiscripts/run_after_00-install-tools.sh" <<'SCRIPT'
#!/bin/sh
printf 'unexpected tool install\n' >"$HOME/tools-ran"
exit 99
SCRIPT
cat >"$fixture/.chezmoiexternal.toml" <<EXTERNAL
["external.txt"]
type = "file"
url = "file://$tmpdir/must-not-be-fetched"
EXTERNAL
printf '[data]\npersonal = true\nheadless = false\n' >"$tmpdir/config.toml"
chezmoi_bin=$(command -v chezmoi)
bash_bin=$(command -v bash)
cat >"$tmpdir/bin/chezmoi" <<'WRAPPER'
#!/bin/sh
if [ "$1" = source-path ]; then
  echo 'unexpected source-path lookup in theme picker' >&2
  exit 99
fi
if [ "$1" = apply ]; then
  printf '%s\n' "$*" >>"$HOME/apply-calls"
fi
exec "$REAL_CHEZMOI" --config "$TEST_CONFIG" --destination "$HOME" \
  --persistent-state "$HOME/state.boltdb" --cache "$HOME/cache" \
  --override-data '{"chezmoi":{"os":"darwin"}}' "$@"
WRAPPER
printf '#!/bin/sh\nexit 1\n' >"$tmpdir/bin/pgrep"
cat >"$tmpdir/bin/borders" <<'BORDERS'
#!/bin/sh
printf '%s\n' "$@" >"$HOME/borders-args"
BORDERS
chmod +x "$tmpdir/bin/chezmoi" "$tmpdir/bin/pgrep" "$tmpdir/bin/borders"
run_theme() {
  HOME="$home" USER=fixture PATH="$tmpdir/bin:/usr/bin:/bin" \
    PI_AGENT_DIR="$home/.pi/agent" CLAUDE_CONFIG_DIR="$home/.claude" CHEZMOI_SOURCE_DIR="$fixture" \
    REAL_CHEZMOI="$chezmoi_bin" TEST_CONFIG="$tmpdir/config.toml" \
    "$bash_bin" "$source_root/dot_local/bin/executable_theme" "$@"
}

[[ $(run_theme --current) == first ]]
grep -Fxq '  first (active)' <<<"$(run_theme --list)"
run_theme second >"$tmpdir/switch.log" 2>&1 || {
    cat "$tmpdir/switch.log" >&2
    exit 1
  }

grep -Fxq second "$home/.config/active-theme"
grep -Fxq "$home/.config/chezmoi-theme/obsidian.css" "$home/obsidian-sync-args"
jq -e '.vars.activeTheme == "second"' "$home/.pi/agent/themes/chezmoi.json" >/dev/null
jq -e '.name == "chezmoi (second)"' "$home/.claude/themes/chezmoi.json" >/dev/null
[[ ! -e "$home/tools-ran" && ! -e "$home/external.txt" ]]
echo 'theme switches without tool or external updates and invokes the optional Obsidian adapter'

# A controlled picker keeps this test non-interactive and away from live apps.
cat >"$tmpdir/bin/fzf" <<'PICKER'
#!/bin/sh
cat >"$HOME/picker-input"
printf '%s\n' "$@" >"$HOME/picker-args"
cat "$HOME/picker-choice"
exit "$(cat "$HOME/picker-status")"
PICKER
chmod +x "$tmpdir/bin/fzf"
printf 'unrelated: preserved\n' >>"$fixture/.chezmoidata/local.yml"
printf 'first\n' >"$home/picker-choice"
printf '0\n' >"$home/picker-status"
run_theme >"$tmpdir/picker.log" 2>&1 || {
  cat "$tmpdir/picker.log" >&2
  exit 1
}
grep -Fxq first "$home/picker-input"
grep -Fxq second "$home/picker-input"
grep -Fxq 'Select theme (current: second)' "$home/picker-args"
[[ $(run_theme --current) == first ]]
grep -Fxq first "$home/.config/active-theme"
grep -Fxq 'unrelated: preserved' "$fixture/.chezmoidata/local.yml"
cmp "$tmpdir/defaults.before" "$fixture/.chezmoidata/defaults.yml"
[[ ! -e "$home/tools-ran" && ! -e "$home/external.txt" ]]

# Cancellation must not write even if the picker emitted a valid theme first.
cp "$fixture/.chezmoidata/local.yml" "$tmpdir/local-before.yml"
cp "$home/apply-calls" "$tmpdir/apply-before"
printf 'second\n' >"$home/picker-choice"
printf '130\n' >"$home/picker-status"
status=0
run_theme >"$tmpdir/cancel.log" 2>&1 || status=$?
[[ $status == 130 ]]
cmp "$tmpdir/local-before.yml" "$fixture/.chezmoidata/local.yml"
cmp "$tmpdir/apply-before" "$home/apply-calls"

# Empty or invalid selections also leave the overlay and apply state untouched.
printf '0\n' >"$home/picker-status"
for choice in '' not-a-theme; do
  printf '%s\n' "$choice" >"$home/picker-choice"
  if run_theme >"$tmpdir/invalid.log" 2>&1; then
    echo "unexpected success for picker choice '$choice'" >&2
    exit 1
  fi
  cmp "$tmpdir/local-before.yml" "$fixture/.chezmoidata/local.yml"
  cmp "$tmpdir/apply-before" "$home/apply-calls"
done
run_theme first >"$tmpdir/unchanged.log" 2>&1
cmp "$tmpdir/apply-before" "$home/apply-calls"
echo 'theme picker, local overlay and cancellation safety ok'
