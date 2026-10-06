#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_root="$repo_root/home"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

render() {
  chezmoi execute-template --source "$repo_root" --override-data "$data" <"$1"
}

# Package membership and manager selection are owned here, not a copy of the YAML.
data='{"personal":true,"work":false,"homelab":false,"chezmoi":{"os":"darwin"}}'
chezmoi execute-template --source "$repo_root" --override-data "$data" \
  '{{ dict "brews" .brews "casks" .casks "mas" .mas "npm" .npm "uv" .uv "taps" .taps | toJson }}' >"$tmp/packages.json"
python3 - "$tmp/packages.json" <<'PY'
import json
import sys

packages = json.load(open(sys.argv[1]))
expected = {
    'brews': ['colima', 'incus', 'kubectl', 'docker', 'docker-compose',
              'docker-buildx', 'openclaw/tap/crabbox'],
    'casks': ['iina', 'thebrowsercompany-dia', 'ente-auth', 'homerow',
              'flux-app', 'typewhisper', 'finicky'],
    'npm': ['@pen.dev/cli'],
    'taps': ['openclaw/tap'],
}
for manager, names in expected.items():
    for name in names:
        assert name in packages[manager]['personal'], (manager, name)
        assert name not in packages[manager]['base'], (manager, name, 'base')
        # kubectl remains an existing work dependency as well.
        if name != 'kubectl':
            assert name not in packages[manager]['work'], (manager, name, 'work')
assert {'id': 1470584107, 'name': 'Dato'} in packages['mas']['personal']
assert {'name': 'serena-agent', 'python': '3.13'} in packages['uv']['personal']
removed = {'itsycal', 'sleeve', 'textsniper', 'cloudmounter', 'orbstack', 'onyx',
           'betterzip', 'vlc', 'lanscan', 'zen-browser', 'helium', 'helium-browser',
           'keka', 'transmit', 'dbngin', 'imageoptim', 'arc', 'flacon', 'daisydisk'}
for roles in packages.values():
    for role in ['base', 'personal', 'work']:
        for package in roles[role]:
            name = package['name'] if isinstance(package, dict) else package
            assert name.lower() not in removed, (role, name)
PY

for manager in brew cask mas; do
  render "$source_root/.chezmoiscripts/darwin/run_onchange_before_install-packages-$manager.sh.tmpl" >"$tmp/$manager.sh"
done
for manager in npm uv; do
  render "$source_root/.chezmoiscripts/darwin/run_onchange_after_install-packages-$manager.sh.tmpl" >"$tmp/$manager.sh"
done
grep -Fq '1470584107' "$tmp/mas.sh"
grep -Fq 'npm install -g @pen.dev/cli' "$tmp/npm.sh"
grep -Fq 'uv tool install -p "3.13" "serena-agent"' "$tmp/uv.sh"

# Other roles must not receive any of these additions. Work keeps its kubectl.
for data in \
  '{"personal":false,"work":true,"homelab":false,"chezmoi":{"os":"darwin"}}' \
  '{"personal":false,"work":false,"homelab":true,"chezmoi":{"os":"darwin"}}'; do
  for template in "$source_root"/.chezmoiscripts/darwin/*install-packages-*.tmpl; do
    render "$template" >"$tmp/nonpersonal.sh"
    if grep -Eq 'colima|incus|docker|crabbox|iina|thebrowsercompany-dia|ente-auth|homerow|flux-app|typewhisper|finicky|1470584107|@pen.dev/cli|serena-agent' "$tmp/nonpersonal.sh"; then
      echo "personal packages leaked into another role: $template" >&2
      exit 1
    fi
  done
done

# Native chezmoi symlinks discover the active prefix, including custom installs.
mkdir -p "$tmp/bin" "$tmp/source/cli-plugins" "$tmp/home"
cat >"$tmp/bin/brew" <<'SH'
#!/bin/sh
[ "$*" = --prefix ]
printf '%s\n' "$TEST_BREW_PREFIX"
SH
chmod +x "$tmp/bin/brew"
cp "$source_root"/dot_docker/cli-plugins/symlink_*.tmpl "$tmp/source/cli-plugins/"
printf '[data]\npersonal=true\n' >"$tmp/config.toml"
for prefix in /opt/homebrew /usr/local "$tmp/custom-brew"; do
  TEST_BREW_PREFIX="$prefix" PATH="$tmp/bin:$PATH" chezmoi apply \
    --source "$tmp/source" --destination "$tmp/home" --config "$tmp/config.toml" \
    --persistent-state "$tmp/state.boltdb" --override-data '{"chezmoi":{"os":"darwin"}}' --no-tty
  for plugin in docker-compose docker-buildx; do
    [[ $(readlink "$tmp/home/cli-plugins/$plugin") == "$prefix/opt/$plugin/bin/$plugin" ]]
  done
done

echo 'personal macOS package declarations and Docker CLI symlinks ok'
