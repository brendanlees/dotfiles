#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_root="$repo_root/home"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/bin"
cat >"$tmpdir/bin/brew" <<'PY'
#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path
with Path(os.environ['BREW_LOG']).open('a') as log:
    log.write(json.dumps(sys.argv[1:]) + '\n')
if os.environ.get('FAIL_TRUST') == '1' and sys.argv[1] == 'trust':
    sys.exit(1)
PY
chmod +x "$tmpdir/bin/brew"

# Use fixtures instead of duplicating the package inventory.
for role in personal work homelab personal-work; do
  case "$role" in
    personal)
      flags='"personal":true,"work":false'; expected='["base","personal"]'
      data='{"personal":true,"work":false,"homelab":false,"chezmoi":{"os":"darwin"}}'
      ;;
    work)
      flags='"personal":false,"work":true'; expected='["base","work"]'
      data='{"personal":false,"work":true,"homelab":false,"chezmoi":{"os":"darwin"}}'
      ;;
    homelab)
      flags='"personal":false,"work":false'; expected='["base"]'
      data='{"personal":false,"work":false,"homelab":true,"chezmoi":{"os":"darwin"}}'
      ;;
    personal-work)
      flags='"personal":true,"work":true'; expected='["base","personal","work"]'
      data='{"personal":true,"work":true,"homelab":false,"chezmoi":{"os":"darwin"}}'
      ;;
  esac

  fixture="{$flags,\"brews\":{\"base\":[\"base\"],\"personal\":[\"personal\",\"base\"],\"work\":[\"work\",\"base\"]}}"
  merged=$(chezmoi execute-template --source "$repo_root" --override-data "$fixture" \
    '{{ includeTemplate ".chezmoitemplates/merge-by-role.tmpl" (list .brews .) }}')
  [[ "$merged" == "$expected" ]]

  for template in "$source_root"/.chezmoiscripts/darwin/*install-packages-*.tmpl; do
    chezmoi execute-template --source "$repo_root" --override-data "$data" \
      <"$template" >/dev/null
  done
  # shellcheck disable=SC2016 # These variables belong to the Go template.
  chezmoi execute-template --source "$repo_root" --override-data "$data" \
    '{{ $t := fromJson (includeTemplate ".chezmoitemplates/merge-by-role.tmpl" (list .taps .)) }}{{ $b := fromJson (includeTemplate ".chezmoitemplates/merge-by-role.tmpl" (list .brews .)) }}{{ $c := fromJson (includeTemplate ".chezmoitemplates/merge-by-role.tmpl" (list .casks .)) | default (list) }}{{ dict "taps" $t "packages" (concat $b $c) | toJson }}' >"$tmpdir/packages.json"
  chezmoi execute-template --source "$repo_root" --override-data "$data" \
    --file "$source_root/.chezmoiscripts/darwin/run_onchange_before_install-packages-0-taps.sh.tmpl" >"$tmpdir/taps.sh"
  : >"$tmpdir/brew.log"
  # Repeated invocations approve only the declared taps, before loading each tap.
  for _ in 1 2; do
    PATH="$tmpdir/bin:$PATH" BREW_LOG="$tmpdir/brew.log" sh "$tmpdir/taps.sh"
  done
  python3 - "$tmpdir" <<'PY'
import json
import sys
from pathlib import Path
root = Path(sys.argv[1])
data = json.loads((root / 'packages.json').read_text())
taps = list(dict.fromkeys(data['taps']))
for package in data['packages']:
    if package.count('/') == 2:
        assert package.rsplit('/', 1)[0] in taps, f'{package} needs an explicitly approved tap'
expected = [command for tap in taps for command in (['trust', '--tap', tap], ['tap', tap])]
actual = [json.loads(line) for line in (root / 'brew.log').read_text().splitlines()]
assert actual == expected * 2, actual
PY
  # A fixture keeps failure coverage even if a role declares no real taps.
  chezmoi execute-template --source "$repo_root" \
    --override-data "{$flags,\"taps\":{\"base\":[\"fixture/tap\"],\"personal\":[],\"work\":[]}}" \
    --file "$source_root/.chezmoiscripts/darwin/run_onchange_before_install-packages-0-taps.sh.tmpl" >"$tmpdir/taps.sh"
  : >"$tmpdir/brew.log"
  if PATH="$tmpdir/bin:$PATH" BREW_LOG="$tmpdir/brew.log" FAIL_TRUST=1 sh "$tmpdir/taps.sh"; then
    echo 'tap provisioning must stop when approval fails' >&2
    exit 1
  fi
  [[ $(wc -l <"$tmpdir/brew.log") -eq 1 ]]

  # Windows package commands follow the same roles, not a fixed app inventory.
  for kind in buckets scoops wingets; do
    case "$kind" in
      buckets) installer=0-buckets ;;
      scoops) installer=scoop ;;
      wingets) installer=winget ;;
    esac
    fixture="{$flags,\"chezmoi\":{\"os\":\"windows\"},\"$kind\":{\"base\":[\"base\"],\"personal\":[\"personal\",\"base\"],\"work\":[\"work\",\"base\"]}}"
    chezmoi execute-template --source "$repo_root" --override-data "$fixture" \
      --file "$source_root/.chezmoiscripts/windows/run_onchange_before_install-packages-$installer.ps1.tmpl" >"$tmpdir/$kind.ps1"
    python3 - "$tmpdir/$kind.ps1" "$kind" "$expected" <<'PY'
import json
import sys
from pathlib import Path
path, kind, expected = sys.argv[1:]
packages = json.loads(expected)
commands = [line.strip() for line in Path(path).read_text().splitlines()
            if line.strip() and not line.startswith('#')]
if kind == 'buckets':
    wanted = [f'scoop bucket add {package}' for package in packages]
elif kind == 'scoops':
    wanted = ['scoop install ' + ' '.join(packages)]
else:
    wanted = [f'winget install --exact --silent --accept-source-agreements --accept-package-agreements --id {package}'
              for package in packages]
assert commands == wanted, (commands, wanted)
PY
    empty="{$flags,\"$kind\":{\"base\":[],\"personal\":[],\"work\":[]}}"
    chezmoi execute-template --source "$repo_root" --override-data "$empty" \
      --file "$source_root/.chezmoiscripts/windows/run_onchange_before_install-packages-$installer.ps1.tmpl" >"$tmpdir/empty.ps1"
    if grep -Eq '^(scoop|winget) ' "$tmpdir/empty.ps1"; then
      echo 'empty package lists must not invoke an installer' >&2
      exit 1
    fi
  done
done

echo 'Darwin tap approval and Windows package role routing, deduplication and empty lists ok'
