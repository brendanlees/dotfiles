#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

chezmoi data --source "$repo_root" --format json >"$tmpdir/data.json"

python3 - "$tmpdir/data.json" "${GHOSTTY_THEME_DIR:-}" <<'PY'
import json
import re
import sys
from pathlib import Path

expected = {
    "black-metal": "Black Metal",
    "black-metal-bathory": "Black Metal (Bathory)",
    "black-metal-burzum": "Black Metal (Burzum)",
    "black-metal-dark-funeral": "Black Metal (Dark Funeral)",
    "black-metal-gorgoroth": "Black Metal (Gorgoroth)",
    "black-metal-immortal": "Black Metal (Immortal)",
    "black-metal-khold": "Black Metal (Khold)",
    "black-metal-marduk": "Black Metal (Marduk)",
    "black-metal-mayhem": "Black Metal (Mayhem)",
    "black-metal-nile": "Black Metal (Nile)",
    "black-metal-venom": "Black Metal (Venom)",
    "batman": "Batman",
    "darkmatrix": "Darkmatrix",
    "embers-dark": "Embers Dark",
    "fahrenheit": "Fahrenheit",
    "flatland": "Flatland",
    "japanesque": "Japanesque",
    "kanso-ink": "Kanso Ink",
    "kanso-zen": "Kanso Zen",
    "miasma": "Miasma",
    "mona-lisa": "Mona Lisa",
    "nvim-dark": "Nvim Dark",
    "sleepy-hollow": "Sleepy Hollow",
    "synthwave": "Synthwave",
    "synthwave-alpha": "Synthwave Alpha",
    "synthwave-everything": "Synthwave Everything",
    "twilight": "Twilight",
    "wryan": "Wryan",
}
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

missing = sorted(set(expected) - set(themes))
if missing:
    raise SystemExit(f"missing requested themes: {', '.join(missing)}")

for key, ghostty_name in expected.items():
    theme = themes[key]
    if set(theme) != {"palette", "apps"}:
        raise SystemExit(f"{key}: expected only palette and apps blocks")
    if set(theme["palette"]) != required_palette:
        raise SystemExit(f"{key}: palette schema mismatch")
    if set(theme["apps"]) != required_apps:
        raise SystemExit(f"{key}: apps schema mismatch")
    for color_key, color in theme["palette"].items():
        if not isinstance(color, str) or not hex_color.fullmatch(color):
            raise SystemExit(f"{key}: invalid {color_key}: {color!r}")
    if theme["apps"]["ghostty"] != ghostty_name:
        raise SystemExit(f"{key}: Ghostty mapping mismatch")
    if theme["apps"]["nvim_background"] != "dark":
        raise SystemExit(f"{key}: nvim_background must be dark")
    if theme["palette"]["tool_neutral_bg"].lower() == theme["palette"]["tool_error_bg"].lower():
        raise SystemExit(f"{key}: tool surfaces must differ")

root = Path(sys.argv[2]) if sys.argv[2] else None
if root:
    if not root.is_dir():
        raise SystemExit(f"Ghostty theme directory not found: {root}")
    absent = sorted(name for name in expected.values() if not (root / name).is_file())
    if absent:
        raise SystemExit(f"missing bundled Ghostty themes: {', '.join(absent)}")

print(f"theme registry ok ({len(expected)} requested themes)")
PY
