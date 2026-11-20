#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
template="$repo_root/home/dot_local/bin/executable_cz-profile-card.tmpl"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# Render with a synthetic theme name so the test follows the active palette, not a fixed one.
chezmoi data --source "$repo_root" --format json >"$tmpdir/data.json"
override=$(python3 - "$tmpdir/data.json" <<'PY'
import json
import sys
from pathlib import Path
sample = next(iter(json.loads(Path(sys.argv[1]).read_text())["themes"].values()))
print(json.dumps({"theme": "fixture", "themes": {"fixture": sample}, "personal": True}))
PY
)
chezmoi execute-template --source "$repo_root" --override-data "$override" \
  --file "$template" >"$tmpdir/cz-profile-card"

checkout="$tmpdir/profile"
mkdir "$checkout"
python3 "$tmpdir/cz-profile-card" "$checkout/whoami.svg" >/dev/null
python3 - "$checkout/whoami.svg" "$tmpdir/data.json" <<'PY'
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
svg = Path(sys.argv[1]).read_text()
palette = next(iter(json.loads(Path(sys.argv[2]).read_text())["themes"].values()))["palette"]
ET.fromstring(svg)
assert ">fixture<" in svg, "card names the active theme"
assert f'fill="{palette["bg"]}"' in svg, "card uses the active palette"
PY
cp "$checkout/whoami.svg" "$tmpdir/first.svg"
python3 "$tmpdir/cz-profile-card" "$checkout/whoami.svg" | grep -q 'already matches'
cmp "$tmpdir/first.svg" "$checkout/whoami.svg"
[[ -z $(find "$checkout" -name '*.tmp') ]] || { echo 'temporary file left behind' >&2; exit 1; }

# A wrong path must fail without creating directories.
if python3 "$tmpdir/cz-profile-card" "$tmpdir/missing/whoami.svg" 2>/dev/null; then
  echo 'writer accepted a missing checkout' >&2
  exit 1
fi
[[ ! -e $tmpdir/missing ]] || { echo 'writer created a missing checkout' >&2; exit 1; }

rendered=$(chezmoi execute-template --source "$repo_root" \
  --override-data '{"personal":false}' --file "$template")
[[ -z $rendered ]] || { echo 'profile card writer must be personal-only' >&2; exit 1; }

echo 'profile card renders the active palette, is idempotent, refuses missing checkouts and stays personal-only'
