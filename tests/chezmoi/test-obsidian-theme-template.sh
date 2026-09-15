#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_root="$repo_root/home"
template="$source_root/dot_config/chezmoi-theme/obsidian.css.tmpl"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

[[ -f $template ]] || { echo 'missing Obsidian palette template' >&2; exit 1; }
chezmoi data --source "$repo_root" --format json >"$tmpdir/data.json"

# One owner for the palette mapping and its deliberately narrow CSS surface.
while IFS= read -r theme; do
  chezmoi execute-template --source "$repo_root" \
    --override-data "{\"theme\":\"$theme\"}" --file "$template" >"$tmpdir/obsidian.css"
  python3 - "$tmpdir/data.json" "$tmpdir/obsidian.css" "$theme" <<'PY'
import json
import re
import sys
from pathlib import Path

palette = json.loads(Path(sys.argv[1]).read_text())["themes"][sys.argv[3]]["palette"]
css = re.sub(r"/\*.*?\*/", "", Path(sys.argv[2]).read_text(), flags=re.S).strip()
# Restrict to the installed dark scheme; no element rules, light rules or !important.
match = re.fullmatch(r"body\.theme-dark\.minimal-things-dark\s*\{([^{}]*)\}", css, re.S)
assert match, f"{sys.argv[3]}: expected only a Things dark body rule"
declarations = {}
for declaration in match[1].split(";"):
    if not declaration.strip():
        continue
    key, value = (part.strip() for part in declaration.split(":", 1))
    assert key not in declarations, f"duplicate property: {key}"
    declarations[key] = value
expected = {
    "--bg1": palette["bg"],
    "--bg2": palette["surface"],
    "--bg3": palette["surface_alt"],
    "--tx1": palette["fg"],
    "--tx2": palette["muted"],
    "--tx3": palette["comment"],
    "--tx4": palette["muted"],
    "--ui1": palette["border"],
    "--ui2": palette["comment"],
    "--ui3": palette["muted"],
    "--divider-color": "var(--ui1)",
    "--tab-outline-color": "var(--ui1)",
    "--ax1": palette["accent"],
    "--ax2": palette["primary_alt"],
    "--ax3": palette["primary"],
    "--interactive-accent-rgb": ", ".join(str(int(palette["primary"][i:i+2], 16)) for i in (1, 3, 5)),
}
# This allowlist also preserves HSL-derived decoration, highlights and personal colors.
assert declarations == expected, f"{sys.argv[3]}: core palette mismatch: {declarations}"
PY
done < <(jq -r '.themes | keys[]' "$tmpdir/data.json")

check_routing() {
  local os=$1 personal=$2 headless=$3 expected=$4
  chezmoi execute-template --source "$repo_root" \
    --override-data "{\"personal\":$personal,\"work\":true,\"homelab\":false,\"headless\":$headless,\"chezmoi\":{\"os\":\"$os\"}}" \
    --file "$source_root/.chezmoiignore" >"$tmpdir/ignore"
  local actual=managed
  if grep -Fxq '.config/chezmoi-theme/obsidian.css' "$tmpdir/ignore"; then
    actual=ignored
  fi
  [[ $actual == "$expected" ]] || {
    echo "Obsidian routing: $os personal=$personal headless=$headless: $actual, expected $expected" >&2
    exit 1
  }
}
check_routing darwin true false managed
check_routing darwin false false ignored
check_routing darwin true true ignored
check_routing linux true false ignored
check_routing windows true false ignored

echo "Obsidian core palette and personal GUI macOS routing ok ($(jq '.themes | length' "$tmpdir/data.json") themes)"
