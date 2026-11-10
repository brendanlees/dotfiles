#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_root="$repo_root/home"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

for path in \
  "$repo_root/agents/AGENTS.md" \
  "$repo_root/agents/pi/APPEND_SYSTEM.md" \
  "$repo_root/agents/.skill-lock.json" \
  "$repo_root/agents/skills" \
  "$source_root/symlink_dot_agents.tmpl" \
  "$source_root/dot_local/state/skills/symlink_dot_skill-lock.json.tmpl"; do
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
  echo '.agents must not be ignored: its empty symlink template removes the link' >&2
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
mkdir -p "$minimal_source/agents/skills" "$minimal_source/home/dot_local/state/skills" "$home_dir"
printf 'home\n' >"$minimal_source/.chezmoiroot"
printf '# canonical\n' >"$minimal_source/agents/AGENTS.md"
printf '{}\n' >"$minimal_source/agents/.skill-lock.json"
cp "$source_root/.chezmoiignore" "$minimal_source/home/.chezmoiignore"
cp "$source_root/.chezmoiremove.tmpl" "$minimal_source/home/.chezmoiremove.tmpl"
cp "$source_root/symlink_dot_agents.tmpl" "$minimal_source/home/symlink_dot_agents.tmpl"
cp "$source_root/dot_local/state/skills/symlink_dot_skill-lock.json.tmpl" \
  "$minimal_source/home/dot_local/state/skills/"
mkdir -p "$minimal_source/home/dot_codex"
cp "$source_root/dot_codex/symlink_AGENTS.md.tmpl" "$minimal_source/home/dot_codex/"
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
[[ "$(readlink "$home_dir/.codex/AGENTS.md")" == "../.agents/AGENTS.md" ]]
# The skills CLI uses the XDG state lock when XDG_STATE_HOME is set.
[[ "$(readlink "$home_dir/.local/state/skills/.skill-lock.json")" == "$minimal_source/agents/.skill-lock.json" ]]
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
[[ ! -L "$home_dir/.codex/AGENTS.md" ]]
[[ ! -L "$home_dir/.local/state/skills/.skill-lock.json" ]]

if git -C "$repo_root" check-ignore -q agents/AGENTS.md; then
  echo 'portable AGENTS.md must be tracked' >&2
  exit 1
fi
git -C "$repo_root" check-ignore -q agents/state/example
git -C "$repo_root" check-ignore -q agents/backups/example

# skills.sh installs stay untracked; only allowlisted custom skills are committed.
git -C "$repo_root" check-ignore -q agents/skills/example-upstream/SKILL.md
python3 - "$repo_root" <<'PY'
import json
import subprocess
import sys

root = sys.argv[1]
locked = set(json.load(open(f'{root}/agents/.skill-lock.json'))['skills'])
tracked = {p.split('/')[2] for p in subprocess.check_output(['git', '-C', root, 'ls-files', 'agents/skills'], text=True).split()}
assert tracked, 'custom skills must be tracked'
assert not tracked & locked, f'locked skills must not be committed: {sorted(tracked & locked)}'
for name in sorted(tracked):
    ignored = subprocess.run(['git', '-C', root, 'check-ignore', '-q', '--no-index', f'agents/skills/{name}/SKILL.md'])
    assert ignored.returncode == 1, f'tracked skill missing from the .gitignore allowlist: {name}'
PY

echo 'Agents home symlink ok'
