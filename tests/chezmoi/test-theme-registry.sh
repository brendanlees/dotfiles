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
    "zed", "nvim", "nvim_background", "matrix",
}
valid_matrix_colors = {"black", "blue", "cyan", "green", "magenta", "red", "white", "yellow"}
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
    if theme["apps"]["matrix"] not in valid_matrix_colors:
        raise SystemExit(f"{key}: unsupported cmatrix color: {theme['apps']['matrix']!r}")
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

expected_exact_nvim = {
    "fahrenheit": "fahrenheit",
    "flatland": "base24-flatland",
    "japanesque": "base24-japanesque",
    "nvim-dark": "github_dark",
    "nightfly": "nightfly",
    "sleepy-hollow": "base24-sleepy-hollow",
    "twilight": "base24-twilight",
    "wryan": "base24-wryan",
}
for key, expected in expected_exact_nvim.items():
    actual = themes[key]["apps"]["nvim"]
    if actual != expected:
        raise SystemExit(
            f"{key}: expected Neovim colorscheme {expected!r}, got {actual!r}"
        )

# Keep the upstream dark styles distinct, without importing excluded or light variants.
expected_github = {
    "github_dark": ("GitHub Dark", "#30363d"),
    "github_dark_default": ("GitHub Dark Default", "#0d1117"),
    "github_dark_dimmed": ("GitHub Dark Dimmed", "#22272e"),
    "github_dark_high_contrast": ("GitHub Dark High Contrast", "#0a0c10"),
}
if {key for key in themes if key.startswith("github")} != set(expected_github):
    raise SystemExit("expected only the four non-colorblind, non-tritanopia GitHub dark styles")
for key, (ghostty, bg) in expected_github.items():
    if themes[key]["palette"]["bg"] != bg:
        raise SystemExit(f"{key}: upstream background must remain {bg}")
    expected_apps = {
        "ghostty": ghostty,
        "nvim": key,
        "nvim_background": "dark",
        "matrix": themes[key]["apps"]["matrix"],
        "starship": key,
        "glow": "auto",
        "bat": "tokyonight_night",
        "btop": "tokyonight_night",
        "tmux_ukiyo": "tokyonight/night",
        "zed": "Tokyo Night",
    }
    if themes[key]["apps"] != expected_apps:
        raise SystemExit(f"{key}: named/generated mappings or documented fallbacks changed")
if themes["nvim-dark"]["palette"]["bg"] != "#14161b":
    raise SystemExit("nvim-dark must retain its own palette despite its github_dark alias")

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

for theme in github_dark github_dark_default github_dark_dimmed github_dark_high_contrast; do
  rendered_bridge=$(
    chezmoi execute-template --source "$repo_root" \
      --override-data "{\"theme\":\"$theme\"}" \
      --file "$source_root/dot_config/chezmoi-theme/active.lua.tmpl"
  )
  if ! grep -Fq "colorscheme = \"$theme\"" <<<"$rendered_bridge"; then
    echo "$theme bridge did not select its upstream colorscheme" >&2
    exit 1
  fi
done

# Exercise theme switching through real chezmoi, with no access to live apps.
fixture="$tmpdir/source"
home="$tmpdir/home"
mkdir -p "$fixture/.chezmoidata" "$fixture/.chezmoitemplates" \
  "$fixture/.chezmoiscripts/darwin" "$fixture/dot_config" "$tmpdir/bin" "$home"
mkdir -p "$home/.config/chezmoi-theme"
cat >"$home/.config/chezmoi-theme/obsidian-sync" <<'SCRIPT'
#!/bin/sh
printf '%s\n' "$@" >"$HOME/obsidian-sync-args"
SCRIPT
chmod +x "$home/.config/chezmoi-theme/obsidian-sync"
cp "$source_root/.chezmoidata/themes.yml" "$fixture/.chezmoidata/themes.yml"
printf 'theme: black-metal-bathory\n' >"$fixture/.chezmoidata/defaults.yml"
cp "$source_root/.chezmoitemplates/pi-theme.json.tmpl" "$fixture/.chezmoitemplates/"
cp "$source_root/.chezmoiscripts/run_onchange_after_configure-pi-theme.py.tmpl" "$fixture/.chezmoiscripts/"
printf '{{ .theme }}\n' >"$fixture/dot_config/active-theme.tmpl"
cat >"$fixture/.chezmoiscripts/run_after_install_tools.sh" <<'SCRIPT'
#!/bin/sh
printf 'unexpected tool install\n' >"$HOME/tools-ran"
exit 99
SCRIPT
cat >"$fixture/.chezmoiscripts/darwin/run_onchange_after_apply-spicetify.sh.tmpl" <<'SCRIPT'
#!/bin/sh
printf '{{ .theme }}\n' >"$HOME/spicetify-theme"
SCRIPT
cat >"$fixture/.chezmoiexternal.toml" <<EXTERNAL
["external.txt"]
type = "file"
url = "file://$tmpdir/must-not-be-fetched"
EXTERNAL
printf '[data]\npersonal = true\nheadless = false\n' >"$tmpdir/config.toml"
chezmoi_bin=$(command -v chezmoi)
bash_bin=$(command -v bash)
cat >"$tmpdir/bin/chezmoi" <<'WRAPPER'
#!/bin/sh
exec "$REAL_CHEZMOI" --config "$TEST_CONFIG" --destination "$HOME" \
  --persistent-state "$HOME/state.boltdb" --cache "$HOME/cache" \
  --override-data '{"chezmoi":{"os":"darwin"}}' "$@"
WRAPPER
printf '#!/bin/sh\nexit 1\n' >"$tmpdir/bin/pgrep"
chmod +x "$tmpdir/bin/chezmoi" "$tmpdir/bin/pgrep"
HOME="$home" USER=fixture PATH="$tmpdir/bin:/usr/bin:/bin" \
  PI_AGENT_DIR="$home/.pi/agent" CHEZMOI_SOURCE_DIR="$fixture" \
  REAL_CHEZMOI="$chezmoi_bin" TEST_CONFIG="$tmpdir/config.toml" \
  "$bash_bin" "$source_root/dot_local/bin/executable_theme" guts >"$tmpdir/switch.log" 2>&1 || {
    cat "$tmpdir/switch.log" >&2
    exit 1
  }

grep -Fxq guts "$home/.config/active-theme"
grep -Fxq guts "$home/spicetify-theme"
grep -Fxq "$home/.config/chezmoi-theme/obsidian.css" "$home/obsidian-sync-args"
jq -e '.vars.activeTheme == "guts"' "$home/.pi/agent/themes/chezmoi.json" >/dev/null
[[ ! -e "$home/tools-ran" && ! -e "$home/external.txt" ]]
echo 'theme switches without tool or external updates and invokes the optional Obsidian adapter'
