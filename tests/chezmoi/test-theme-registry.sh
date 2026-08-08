#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_root="$repo_root/home"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

chezmoi data --source "$repo_root" --format json >"$tmpdir/data.json"

python3 - "$tmpdir/data.json" "${GHOSTTY_THEME_DIR:-}" <<'PY'
import json
import re
import sys
from pathlib import Path

required_palette = {
    "bg", "surface", "surface_alt", "border", "comment", "muted", "fg",
    "accent", "primary", "primary_alt", "secondary", "success", "warn",
    "error", "info", "info_alt", "orange", "tool_neutral_bg",
    "tool_error_bg",
}
required_apps = {
    "ghostty", "btop", "bat", "glow", "starship", "tmux_ukiyo",
    "zed", "nvim", "nvim_background",
}
hex_color = re.compile(r"^#[0-9a-fA-F]{6}$")
data = json.loads(Path(sys.argv[1]).read_text())
themes = data["themes"]

if not isinstance(themes, dict) or not themes:
    raise SystemExit("theme registry must be a non-empty object")

for key, theme in sorted(themes.items()):
    if not isinstance(theme, dict) or set(theme) != {"palette", "apps"}:
        raise SystemExit(f"{key}: expected only palette and apps blocks")
    if not isinstance(theme["palette"], dict) or set(theme["palette"]) != required_palette:
        raise SystemExit(f"{key}: palette schema mismatch")
    if not isinstance(theme["apps"], dict) or set(theme["apps"]) != required_apps:
        raise SystemExit(f"{key}: apps schema mismatch")
    for app_key, app_value in theme["apps"].items():
        if not isinstance(app_value, str) or not app_value:
            raise SystemExit(f"{key}: invalid {app_key} mapping: {app_value!r}")
    for color_key, color in theme["palette"].items():
        if not isinstance(color, str) or not hex_color.fullmatch(color):
            raise SystemExit(f"{key}: invalid {color_key}: {color!r}")
    if theme["apps"]["nvim_background"] != "dark":
        raise SystemExit(f"{key}: nvim_background must be dark")
    if theme["palette"]["tool_neutral_bg"].lower() == theme["palette"]["tool_error_bg"].lower():
        raise SystemExit(f"{key}: tool surfaces must differ")

expected_black_metal_nvim = {
    "black-metal": "bathory",
    "black-metal-bathory": "bathory",
    "black-metal-burzum": "burzum",
    "black-metal-dark-funeral": "dark-funeral",
    "black-metal-gorgoroth": "gorgoroth",
    "black-metal-immortal": "immortal",
    "black-metal-khold": "khold",
    "black-metal-marduk": "marduk",
    "black-metal-mayhem": "mayhem",
    "black-metal-nile": "nile",
    "black-metal-venom": "venom",
}
for key, expected in expected_black_metal_nvim.items():
    actual = themes[key]["apps"]["nvim"]
    if actual != expected:
        raise SystemExit(
            f"{key}: expected Neovim colorscheme {expected!r}, got {actual!r}"
        )

root = Path(sys.argv[2]) if sys.argv[2] else None
if root:
    if not root.is_dir():
        raise SystemExit(f"Ghostty theme directory not found: {root}")
    ghostty_names = sorted({theme["apps"]["ghostty"] for theme in themes.values()})
    absent = sorted(name for name in ghostty_names if not (root / name).is_file())
    if absent:
        raise SystemExit(f"missing bundled Ghostty themes: {', '.join(absent)}")

print(f"theme registry ok ({len(themes)} themes)")
PY

rendered_bridge=$(
  chezmoi execute-template \
    --source "$repo_root" \
    --override-data '{"theme":"black-metal-bathory"}' \
    --file "$source_root/dot_config/chezmoi-theme/active.lua.tmpl"
)
if ! grep -Fq 'colorscheme = "bathory"' <<<"$rendered_bridge"; then
  echo 'black-metal-bathory bridge did not render colorscheme = "bathory"' >&2
  exit 1
fi
