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
# Own the dark palette with or without Minimal Theme Settings' preset classes.
match = re.fullmatch(
    r'body\.theme-dark,\s*body\.theme-dark\[class\*="minimal-"\]\s*\{([^{}]*)\}',
    css,
    re.S,
)
assert match, f"{sys.argv[3]}: expected only the dark body palette rule"
declarations = {}
for declaration in match[1].split(";"):
    if not declaration.strip():
        continue
    key, value = (part.strip() for part in declaration.split(":", 1))
    assert key not in declarations, f"duplicate property: {key}"
    declarations[key] = value
rgb = lambda value: ", ".join(str(int(value[i:i+2], 16)) for i in (1, 3, 5))
expected = {
    "--cz-bg": palette["bg"],
    "--cz-bg-rgb": rgb(palette["bg"]),
    "--cz-surface": palette["surface"],
    "--cz-surface-alt": palette["surface_alt"],
    "--cz-surface-alt-rgb": rgb(palette["surface_alt"]),
    "--cz-border": palette["border"],
    "--cz-comment": palette["comment"],
    "--cz-muted": palette["muted"],
    "--cz-fg": palette["fg"],
    "--cz-accent": palette["accent"],
    "--cz-accent-rgb": rgb(palette["accent"]),
    "--cz-primary": palette["primary"],
    "--cz-primary-rgb": rgb(palette["primary"]),
    "--cz-primary-alt": palette["primary_alt"],
    "--cz-secondary": palette["secondary"],
    "--cz-secondary-rgb": rgb(palette["secondary"]),
    "--cz-success": palette["success"],
    "--cz-success-rgb": rgb(palette["success"]),
    "--cz-warn": palette["warn"],
    "--cz-warn-rgb": rgb(palette["warn"]),
    "--cz-error": palette["error"],
    "--cz-error-rgb": rgb(palette["error"]),
    "--cz-info": palette["info"],
    "--cz-info-rgb": rgb(palette["info"]),
    "--cz-info-alt": palette["info_alt"],
    "--cz-info-alt-rgb": rgb(palette["info_alt"]),
    "--cz-tool-neutral-bg": palette["tool_neutral_bg"],
    "--cz-tool-error-bg": palette["tool_error_bg"],
    "--cz-orange": palette["orange"],
    "--cz-orange-rgb": rgb(palette["orange"]),
    "--bg1": "var(--cz-bg)",
    "--bg2": "var(--cz-surface)",
    "--bg3": "var(--cz-surface-alt)",
    "--tx1": "var(--cz-fg)",
    "--tx2": "var(--cz-muted)",
    "--tx3": "var(--cz-comment)",
    "--tx4": "var(--cz-muted)",
    "--ui1": "var(--cz-border)",
    "--ui2": "var(--cz-comment)",
    "--ui3": "var(--cz-muted)",
    "--ax1": "var(--cz-accent)",
    "--ax2": "var(--cz-primary-alt)",
    "--ax3": "var(--cz-primary)",
    "--divider-color": "var(--cz-border)",
    "--tab-outline-color": "var(--cz-border)",
    "--color-red": "var(--cz-error)",
    "--color-red-rgb": "var(--cz-error-rgb)",
    "--color-orange": "var(--cz-orange)",
    "--color-orange-rgb": "var(--cz-orange-rgb)",
    "--color-yellow": "var(--cz-warn)",
    "--color-yellow-rgb": "var(--cz-warn-rgb)",
    "--color-green": "var(--cz-success)",
    "--color-green-rgb": "var(--cz-success-rgb)",
    "--color-cyan": "var(--cz-info)",
    "--color-cyan-rgb": "var(--cz-info-rgb)",
    "--color-blue": "var(--cz-primary)",
    "--color-blue-rgb": "var(--cz-primary-rgb)",
    "--color-purple": "var(--cz-secondary)",
    "--color-purple-rgb": "var(--cz-secondary-rgb)",
    "--color-pink": "var(--cz-error)",
    "--color-pink-rgb": "var(--cz-error-rgb)",
    "--hl1": "rgba(var(--cz-primary-rgb), 0.30)",
    "--hl2": "rgba(var(--cz-warn-rgb), 0.30)",
    "--sp1": "var(--cz-bg)",
    "--text-on-accent": "var(--cz-bg)",
    "--text-on-accent-inverted": "var(--cz-fg)",
    "--accent-color": "var(--cz-primary)",
    "--accent-color-hover": "var(--cz-primary-alt)",
    "--interactive-accent-rgb": "var(--cz-primary-rgb)",
    "--background-modifier-cover": "rgba(var(--cz-bg-rgb), 0.50)",
    "--workspace-background-translucent": "rgba(var(--cz-bg-rgb), 0.70)",
    "--active-line-bg": "rgba(var(--cz-surface-alt-rgb), 0.40)",
    "--text-highlight-bg-active": "rgba(var(--cz-warn-rgb), 0.35)",
    "--background-modifier-error": "rgba(var(--cz-error-rgb), 0.12)",
    "--background-modifier-error-hover": "rgba(var(--cz-error-rgb), 0.18)",
    "--background-modifier-box-shadow": "rgba(var(--cz-bg-rgb), 0.30)",
    "--shadow-color": "rgba(var(--cz-bg-rgb), 0.30)",
    "--btn-shadow-color": "rgba(var(--cz-bg-rgb), 0.20)",
    "--frame-background": "var(--cz-surface)",
    "--frame-outline-color": "var(--cz-border)",
    "--frame-muted-color": "var(--cz-muted)",
    "--background-primary": "var(--cz-bg)",
    "--background-primary-alt": "var(--cz-surface)",
    "--background-secondary": "var(--cz-surface)",
    "--background-secondary-alt": "var(--cz-bg)",
    "--background-table-rows": "var(--cz-surface)",
    "--setting-items-background": "var(--cz-surface-alt)",
    "--ribbon-background": "var(--cz-surface)",
    "--titlebar-background": "var(--cz-surface)",
    "--titlebar-background-focused": "var(--cz-surface)",
    "--background-modifier-form-field": "var(--cz-bg)",
    "--background-modifier-form-field-highlighted": "var(--cz-bg)",
    "--search-result-background": "var(--cz-bg)",
}
assert declarations == expected, f"{sys.argv[3]}: full palette mismatch: {declarations}"
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
