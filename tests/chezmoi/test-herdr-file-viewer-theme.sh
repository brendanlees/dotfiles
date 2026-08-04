#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
export CHEZMOI_ROLE=ephemeral,headless
role_data='{"personal":false,"work":false,"homelab":false,"ephemeral":true,"headless":true}'

chezmoi data --source "$repo_root" --format json >"$tmpdir/data.json"
home_dir=$(jq -r '.chezmoi.homeDir' "$tmpdir/data.json")

for theme in $(jq -r '.themes | keys[]' "$tmpdir/data.json"); do
  override=$(jq -cn --arg theme "$theme" --argjson role "$role_data" \
    '$role + {theme: $theme}')
  chezmoi execute-template --source "$repo_root" --override-data "$override" \
    <"$repo_root/dot_config/herdr/plugins/config/herdr-file-viewer/config.toml.tmpl" \
    >"$tmpdir/viewer.toml"
  chezmoi execute-template --source "$repo_root" --override-data "$override" \
    <"$repo_root/dot_config/glow/glow.yml.tmpl" >"$tmpdir/glow.yml"
  chezmoi execute-template --source "$repo_root" --override-data "$override" \
    <"$repo_root/dot_config/glow/chezmoi.json.tmpl" >"$tmpdir/glow.json"

  python3 - \
    "$tmpdir/data.json" "$tmpdir/viewer.toml" "$tmpdir/glow.yml" \
    "$tmpdir/glow.json" "$theme" "$home_dir" <<'PY'
import json
import sys
import tomllib
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text())
viewer = tomllib.loads(Path(sys.argv[2]).read_text())
glow_config = Path(sys.argv[3]).read_text()
glow_style = json.loads(Path(sys.argv[4]).read_text())
theme_name = sys.argv[5]
home = sys.argv[6]
theme = data["themes"][theme_name]
apps = theme["apps"]
palette = theme["palette"]

style = apps["glow"]
if style == "auto":
    style = f"{home}/.config/glow/chezmoi.json"

assert viewer["markdown"] == f'glow -s "{style}" -w 0 -'
assert viewer["diff"] == f'delta --syntax-theme="{apps["bat"]}"'
assert viewer["syntax"] == (
    f'bat --theme="{apps["bat"]}" --color=always --style=numbers '
    '--paging=never --file-name={name} -'
)
assert "diffs" not in viewer
assert "compact_dirs" not in viewer
assert f'style: "{style}"' in glow_config
assert glow_style["document"]["color"] == palette["fg"]
assert glow_style["h1"]["color"] == palette["secondary"]
assert glow_style["h2"]["color"] == palette["primary"]
assert glow_style["code_block"]["chroma"]["background"]["background_color"] == palette["surface"]
assert glow_style["code_block"]["chroma"]["generic_deleted"]["color"] == palette["error"]
assert glow_style["code_block"]["chroma"]["generic_inserted"]["color"] == palette["success"]
PY
done

chezmoi execute-template --source "$repo_root" --override-data "$role_data" \
  <"$repo_root/dot_config/mise/config.toml.tmpl" >"$tmpdir/mise.toml"
python3 - "$tmpdir/mise.toml" <<'PY'
import sys
import tomllib
from pathlib import Path

tools = tomllib.loads(Path(sys.argv[1]).read_text())["tools"]
assert tools["bat"] == "latest"
assert tools["delta"] == "latest"
assert tools["glow"] == "latest"
PY

echo "Herdr file viewer theme integration ok"
