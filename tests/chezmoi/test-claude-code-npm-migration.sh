#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
packages_file="$repo_root/.chezmoidata/packages-darwin.yml"
npm_script="$repo_root/.chezmoiscripts/darwin/run_onchange_after_install-packages-npm.sh.tmpl"

python3 - "$packages_file" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
section = None
role = None
values = {}

for raw in path.read_text().splitlines():
    if not raw.strip() or raw.lstrip().startswith('#'):
        continue
    if raw and not raw.startswith(' '):
        section = raw.rstrip(':')
        role = None
        continue
    if section and raw.startswith('  ') and not raw.startswith('    '):
        role = raw.strip().rstrip(':')
        values.setdefault((section, role), [])
        continue
    if section and role and raw.startswith('    - '):
        item = raw.strip()[2:].strip().strip("'\"")
        values[(section, role)].append(item)

casks_personal = values.get(('casks', 'personal'), [])
npm_personal = values.get(('npm', 'personal'), [])

if 'claude-code' in casks_personal:
    raise SystemExit('claude-code must not be installed by Homebrew cask')
if '@anthropic-ai/claude-code' not in npm_personal:
    raise SystemExit('@anthropic-ai/claude-code must be declared in npm.personal')
PY

if [[ ! -f "$npm_script" ]]; then
  echo "missing npm install script: $npm_script" >&2
  exit 1
fi

rendered=$(CHEZMOI_ROLE=personal chezmoi execute-template --source="$repo_root" < "$npm_script")
printf '%s\n' "$rendered" | grep -Fq 'npm install -g @anthropic-ai/claude-code'
printf '%s\n' "$rendered" | grep -Fq 'exec node -- npm install -g @anthropic-ai/claude-code'
printf '%s\n' "$rendered" | grep -Fq 'exec node -- claude install --force latest'

if grep -Fq 'brew install --cask' <<<"$rendered"; then
  echo "npm package script must not use brew casks" >&2
  exit 1
fi

echo "claude code npm migration ok"
