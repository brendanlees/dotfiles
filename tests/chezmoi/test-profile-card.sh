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
cat >"$checkout/card.json" <<'JSON'
{
  "tagline": "fixture tagline",
  "location": "fixture town",
  "rows": {"tools": ["alpha", "beta & gamma"]},
  "upgrade_command": "fixture --upgrade",
  "upgrade_progress": 0.5,
  "learning": ["delta"],
  "site": "example.test",
  "window_title": "fixture@github: ~"
}
JSON
printf '<p>\n  <img src="./whoami.svg" width="820" alt="stale">\n</p>\n' >"$checkout/README.md"
card() { python3 "$tmpdir/cz-profile-card" --card "$checkout/card.json" "$@"; }

card "$checkout/whoami.svg" >/dev/null
python3 - "$checkout" "$tmpdir/data.json" <<'PY'
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
checkout = Path(sys.argv[1])
svg = (checkout / "whoami.svg").read_text()
readme = (checkout / "README.md").read_text()
palette = next(iter(json.loads(Path(sys.argv[2]).read_text())["themes"].values()))["palette"]
title = ET.fromstring(svg).find("{http://www.w3.org/2000/svg}title").text
assert ">fixture<" in svg, "card names the active theme"
assert f'fill="{palette["bg"]}"' in svg, "card uses the active palette"
assert ">beta &amp; gamma<" in svg, "card renders rows from card.json"
assert "tools: alpha, beta & gamma" in title, "title summarises card.json"
assert 'alt="brendan, fixture tagline' in readme and "beta &amp; gamma" in readme, "README alt follows card.json"
PY
cp "$checkout/whoami.svg" "$tmpdir/first.svg"
cp "$checkout/README.md" "$tmpdir/first.md"
card "$checkout/whoami.svg" | grep -q 'already matches'
cmp "$tmpdir/first.svg" "$checkout/whoami.svg"
cmp "$tmpdir/first.md" "$checkout/README.md"
[[ -z $(find "$checkout" -name '.*.tmp') ]] || { echo 'temporary file left behind' >&2; exit 1; }

# A README whose image tag has drifted must fail rather than silently skip the alt text.
printf 'no card here\n' >"$checkout/README.md"
if card "$checkout/whoami.svg" >/dev/null 2>&1; then
  echo 'writer ignored a README without the card image' >&2
  exit 1
fi

# A missing card must fail.
if python3 "$tmpdir/cz-profile-card" --card "$tmpdir/missing.json" "$tmpdir/preview.svg" 2>/dev/null; then
  echo 'writer accepted a missing card.json' >&2
  exit 1
fi

# A wrong path must fail without creating directories.
if card "$tmpdir/missing/whoami.svg" 2>/dev/null; then
  echo 'writer accepted a missing checkout' >&2
  exit 1
fi
[[ ! -e $tmpdir/missing ]] || { echo 'writer created a missing checkout' >&2; exit 1; }

rendered=$(chezmoi execute-template --source "$repo_root" \
  --override-data '{"personal":false}' --file "$template")
[[ -z $rendered ]] || { echo 'profile card writer must be personal-only' >&2; exit 1; }

echo 'profile card renders card.json in the active palette, syncs README alt text, is idempotent, refuses missing inputs and stays personal-only'
