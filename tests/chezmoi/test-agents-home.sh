#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_root="$repo_root/home"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

for path in \
  "$repo_root/agents/AGENTS.md" \
  "$repo_root/agents/.skill-lock.json" \
  "$repo_root/agents/skills" \
  "$source_root/symlink_dot_agents.tmpl"; do
  [[ -e "$path" ]] || {
    echo "missing agents source path: $path" >&2
    exit 1
  }
done

grep -Fxq '/agents/state/' "$repo_root/.gitignore"
grep -Fxq '/agents/backups/' "$repo_root/.gitignore"

personal_ignore="$tmpdir/personal-ignore"
chezmoi execute-template \
  --source "$repo_root" \
  --override-data '{"personal":true,"work":false,"homelab":false,"headless":false}' \
  <"$source_root/.chezmoiignore" >"$personal_ignore"
if grep -Fxq 'agents' "$personal_ignore"; then
  echo 'root-level agents must remain outside the chezmoi source state' >&2
  exit 1
fi
if grep -Fxq '.agents' "$personal_ignore"; then
  echo 'personal machines must manage ~/.agents' >&2
  exit 1
fi

nonpersonal_ignore="$tmpdir/nonpersonal-ignore"
chezmoi execute-template \
  --source "$repo_root" \
  --override-data '{"personal":false,"work":true,"homelab":false,"headless":false}' \
  <"$source_root/.chezmoiignore" >"$nonpersonal_ignore"
if grep -Fxq 'agents' "$nonpersonal_ignore"; then
  echo 'root-level agents must remain outside the chezmoi source state' >&2
  exit 1
fi
if grep -Fxq '.agents' "$nonpersonal_ignore"; then
  echo '.agents must not be ignored because .chezmoiremove cleans it up' >&2
  exit 1
fi
python3 - "$source_root/.chezmoiexternal.toml.tmpl" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text()
for name in ('.claude', '.pi'):
    match = re.search(rf'^\["{re.escape(name)}"\]\n(.*?)(?=^\[|\Z)', text, re.M | re.S)
    if match is None:
        raise SystemExit(f'missing external block: {name}')
    if '"*/*.md"' in match.group(1):
        raise SystemExit(f'broad Markdown external exclusion would omit {name} harness link')
PY

minimal_source="$tmpdir/source"
home_dir="$tmpdir/home"
config_file="$tmpdir/chezmoi.toml"
mkdir -p "$minimal_source/agents/skills" "$minimal_source/home" "$home_dir"
printf 'home\n' >"$minimal_source/.chezmoiroot"
printf '# canonical\n' >"$minimal_source/agents/AGENTS.md"
printf '{}\n' >"$minimal_source/agents/.skill-lock.json"
cp "$source_root/.chezmoiignore" "$minimal_source/home/.chezmoiignore"
cp "$source_root/.chezmoiremove.tmpl" "$minimal_source/home/.chezmoiremove.tmpl"
cp "$source_root/symlink_dot_agents.tmpl" "$minimal_source/home/symlink_dot_agents.tmpl"
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
  --config "$config_file" \
  --destination "$home_dir" \
  --no-tty

[[ -L "$home_dir/.agents" ]]
[[ "$(readlink "$home_dir/.agents")" == "$minimal_source/agents" ]]
[[ ! -e "$home_dir/agents" ]]
printf '# edited through target\n' >"$home_dir/.agents/AGENTS.md"
grep -Fxq '# edited through target' "$minimal_source/agents/AGENTS.md"

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
  --config "$config_file" \
  --destination "$home_dir" \
  --no-tty

[[ ! -e "$home_dir/.agents" && ! -L "$home_dir/.agents" ]]

if git -C "$repo_root" check-ignore -q agents/AGENTS.md; then
  echo 'portable AGENTS.md must be tracked' >&2
  exit 1
fi
git -C "$repo_root" check-ignore -q agents/state/example
git -C "$repo_root" check-ignore -q agents/backups/example

echo 'Agents home symlink ok'
