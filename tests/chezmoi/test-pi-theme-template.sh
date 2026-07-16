#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
template="$repo_root/.chezmoitemplates/pi-theme.json.tmpl"
posix_writer="$repo_root/.chezmoiscripts/run_onchange_after_configure-pi-theme.py.tmpl"
windows_writer="$repo_root/.chezmoiscripts/windows/run_onchange_after_configure-pi-theme.ps1.tmpl"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

for required_file in "$template" "$posix_writer" "$windows_writer"; do
  if [[ ! -f "$required_file" ]]; then
    echo "missing Pi theme source: $required_file" >&2
    exit 1
  fi
done

data_file="$tmpdir/data.json"
rendered_dir="$tmpdir/rendered"
mkdir -p "$rendered_dir"
chezmoi data --source "$repo_root" --format json >"$data_file"

theme_count=0
while IFS= read -r theme; do
  theme_count=$((theme_count + 1))
  rendered="$rendered_dir/$theme.json"
  chezmoi execute-template \
    --source "$repo_root" \
    --override-data "{\"theme\":\"$theme\"}" \
    <"$template" >"$rendered"

  python3 - "$data_file" "$rendered" "$theme" <<'PY'
import json
import re
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text())
rendered_path = Path(sys.argv[2])
theme_name = sys.argv[3]
text = rendered_path.read_text()
if "<no value>" in text or "{{" in text or "}}" in text:
    raise SystemExit(f"{theme_name}: unresolved template output")

doc = json.loads(text)
palette = data["themes"][theme_name]["palette"]
required_palette = {
    "bg", "surface", "surface_alt", "border", "comment", "muted", "fg",
    "accent", "primary", "primary_alt", "secondary", "success", "warn",
    "error", "info", "info_alt", "orange", "tool_pending_bg",
    "tool_success_bg", "tool_error_bg",
}
missing_palette = sorted(required_palette - set(palette))
if missing_palette:
    raise SystemExit(f"{theme_name}: missing palette keys: {', '.join(missing_palette)}")

hex_color = re.compile(r"^#[0-9a-fA-F]{6}$")
for key in required_palette:
    value = palette[key]
    if not isinstance(value, str) or not hex_color.fullmatch(value):
        raise SystemExit(f"{theme_name}: invalid {key} color: {value!r}")

required_colors = {
    "accent", "border", "borderAccent", "borderMuted", "success", "error",
    "warning", "muted", "dim", "text", "thinkingText", "selectedBg",
    "userMessageBg", "userMessageText", "customMessageBg", "customMessageText",
    "customMessageLabel", "toolPendingBg", "toolSuccessBg", "toolErrorBg",
    "toolTitle", "toolOutput", "mdHeading", "mdLink", "mdLinkUrl", "mdCode",
    "mdCodeBlock", "mdCodeBlockBorder", "mdQuote", "mdQuoteBorder", "mdHr",
    "mdListBullet", "toolDiffAdded", "toolDiffRemoved", "toolDiffContext",
    "syntaxComment", "syntaxKeyword", "syntaxFunction", "syntaxVariable",
    "syntaxString", "syntaxNumber", "syntaxType", "syntaxOperator",
    "syntaxPunctuation", "thinkingOff", "thinkingMinimal", "thinkingLow",
    "thinkingMedium", "thinkingHigh", "thinkingXhigh", "bashMode",
}
missing_colors = sorted(required_colors - set(doc.get("colors", {})))
if missing_colors:
    raise SystemExit(f"{theme_name}: missing Pi colors: {', '.join(missing_colors)}")

if doc.get("name") != "chezmoi":
    raise SystemExit(f"{theme_name}: theme name must remain 'chezmoi'")
if doc.get("vars", {}).get("activeTheme") != theme_name:
    raise SystemExit(f"{theme_name}: vars.activeTheme mismatch")

vars_ = doc["vars"]
for key, value in doc["colors"].items():
    if value == "":
        continue
    if isinstance(value, int) and 0 <= value <= 255:
        continue
    if isinstance(value, str) and (value in vars_ or hex_color.fullmatch(value)):
        continue
    raise SystemExit(f"{theme_name}: unresolved color reference {key}={value!r}")

if theme_name == "guts":
    expected = {
        "tool_pending_bg": "#121315",
        "tool_success_bg": "#141716",
        "tool_error_bg": "#191314",
    }
    actual = {key: palette[key] for key in expected}
    if actual != expected:
        raise SystemExit(f"guts: status tints changed: {actual!r}")
PY
done < <(
  python3 - "$data_file" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text())
for name in sorted(data["themes"]):
    print(name)
PY
)

if [[ "$theme_count" -eq 0 ]]; then
  echo "no themes discovered" >&2
  exit 1
fi

rendered_posix="$tmpdir/pi-theme-writer.py"
chezmoi execute-template \
  --source "$repo_root" \
  --override-data '{"theme":"guts"}' \
  <"$posix_writer" >"$rendered_posix"

agent_dir="$tmpdir/pi-agent"
PI_AGENT_DIR="$agent_dir" python3 "$rendered_posix"
target="$agent_dir/themes/chezmoi.json"
test -f "$target"
jq -e '.name == "chezmoi" and .vars.activeTheme == "guts"' "$target" >/dev/null

rendered_windows="$tmpdir/pi-theme-writer.ps1"
chezmoi execute-template \
  --source "$repo_root" \
  --override-data '{"theme":"guts","chezmoi":{"os":"windows"}}' \
  <"$windows_writer" >"$rendered_windows"
grep -Fq '"activeTheme": "guts"' "$rendered_windows"
grep -Fq 'chezmoi.json' "$rendered_windows"

if [[ -n "${PI_THEME_SCHEMA:-}" ]]; then
  if [[ ! -f "$PI_THEME_SCHEMA" ]]; then
    echo "missing PI_THEME_SCHEMA: $PI_THEME_SCHEMA" >&2
    exit 1
  fi
  npx --yes ajv-cli@5.0.0 validate --spec=draft7 -s "$PI_THEME_SCHEMA" -d "$rendered_dir/*.json"
fi

echo "Pi theme template and writers ok ($theme_count themes)"
