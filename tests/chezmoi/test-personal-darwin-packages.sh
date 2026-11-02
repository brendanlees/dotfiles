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
for role in personal work homelab; do
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
  esac

  fixture="{$flags,\"brews\":{\"base\":[\"base\"],\"personal\":[\"personal\"],\"work\":[\"work\"]}}"
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
  python3 - "$tmpdir" "$role" <<'PY'
import json
import sys
from pathlib import Path
root = Path(sys.argv[1])
data = json.loads((root / 'packages.json').read_text())
taps = list(dict.fromkeys(data['taps']))
assert 'oven-sh/bun' in taps, 'Bun is a base package on every Darwin role'
assert ('gromgit/brewtils' in taps) == (sys.argv[2] == 'personal')
for package in data['packages']:
    if package.count('/') == 2:
        assert package.rsplit('/', 1)[0] in taps, f'{package} needs an explicitly approved tap'
assert not {'itsycal', 'betterdisplay', 'spotify', 'soundsource', 'typewhisper', 'spicetify-cli', 'icm'} & set(data['packages'])
expected = [command for tap in taps for command in (['trust', '--tap', tap], ['tap', tap])]
actual = [json.loads(line) for line in (root / 'brew.log').read_text().splitlines()]
assert actual == expected * 2, actual
PY
  : >"$tmpdir/brew.log"
  if PATH="$tmpdir/bin:$PATH" BREW_LOG="$tmpdir/brew.log" FAIL_TRUST=1 sh "$tmpdir/taps.sh"; then
    echo 'tap provisioning must stop when approval fails' >&2
    exit 1
  fi
  [[ $(wc -l <"$tmpdir/brew.log") -eq 1 ]]
done

echo 'Darwin package roles, explicit tap approval and fail-closed provisioning ok'
