#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
template="$repo_root/dot_config/private_mcp/private_mcp.json.tmpl"
config_template="$repo_root/.chezmoi.toml.tmpl"
ignore_template="$repo_root/.chezmoiignore"
item_id="afa4395b-8044-46b1-86c9-b48d007e82ac"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

missing=0
if [[ ! -f "$template" ]]; then
  echo "missing production Home Assistant MCP template: $template" >&2
  missing=1
fi
if ! grep -Fq "bitwardenFields \"item\" \"$item_id\"" "$config_template" ||
  ! grep -Fq '[data.bw_ha_mcp]' "$config_template"; then
  echo "missing cached bw_ha_mcp data wiring" >&2
  missing=1
fi
if [[ -f "$template" ]] && ! grep -Fq '.bw_ha_mcp.secret_path | toJson' "$template"; then
  echo "Home Assistant MCP URL must use JSON-safe encoding" >&2
  missing=1
fi
((missing == 0)) || exit 1

sentinel_url=$(printf 'https://%s/%s?%s=%s' 'sentinel.invalid' 'mcp' 'token' 'test-only')
minimal_source="$tmpdir/source"
home_dir="$tmpdir/home"
config_file="$tmpdir/chezmoi.toml"
mkdir -p "$minimal_source/dot_config/private_mcp" "$home_dir"
cp "$template" "$minimal_source/dot_config/private_mcp/private_mcp.json.tmpl"
cp "$ignore_template" "$minimal_source/.chezmoiignore"

cat >"$config_file" <<TOML
[data]
  personal = true
  work = false
  headless = false
  zsh_patina_trial = false

[data.bw_ha_mcp]
  secret_path = "$sentinel_url"
TOML

chezmoi apply \
  --source "$minimal_source" \
  --config "$config_file" \
  --destination "$home_dir" \
  --force \
  --no-tty

target="$home_dir/.config/mcp/mcp.json"
[[ -f "$target" ]] || { echo "missing rendered target: $target" >&2; exit 1; }

SENTINEL_URL="$sentinel_url" TARGET="$target" python3 - <<'PY'
import json
import os
from pathlib import Path

actual = json.loads(Path(os.environ["TARGET"]).read_text())
expected = {
    "mcpServers": {
        "home-assistant": {
            "type": "http",
            "url": os.environ["SENTINEL_URL"],
        }
    }
}
if actual != expected:
    raise SystemExit("rendered MCP JSON has unexpected shape")
PY

mode_of() {
  if stat -f '%Lp' "$1" >/dev/null 2>&1; then
    stat -f '%Lp' "$1"
  else
    stat -c '%a' "$1"
  fi
}

[[ $(mode_of "$home_dir/.config/mcp") == 700 ]] || {
  echo "expected .config/mcp mode 0700" >&2
  exit 1
}
[[ $(mode_of "$target") == 600 ]] || {
  echo "expected mcp.json mode 0600" >&2
  exit 1
}

render_ignore() {
  local data=$1
  chezmoi execute-template \
    --source "$minimal_source" \
    --override-data "$data" \
    <"$ignore_template"
}

base_data='"work":false,"headless":false,"zsh_patina_trial":false,"chezmoi":{"os":"darwin"}'
nonpersonal=$(render_ignore "{\"personal\":false,\"bw_ha_mcp\":{\"secret_path\":\"present\"},$base_data}")
missing_data=$(render_ignore "{\"personal\":true,$base_data}")
missing_field=$(render_ignore "{\"personal\":true,\"bw_ha_mcp\":{},$base_data}")
present_data=$(render_ignore "{\"personal\":true,\"bw_ha_mcp\":{\"secret_path\":\"present\"},$base_data}")

grep -Fxq '.config/mcp' <<<"$nonpersonal" || {
  echo "non-personal rendering must ignore .config/mcp" >&2
  exit 1
}
grep -Fxq '.config/mcp' <<<"$missing_data" || {
  echo "personal rendering without bw_ha_mcp must ignore .config/mcp" >&2
  exit 1
}
grep -Fxq '.config/mcp' <<<"$missing_field" || {
  echo "personal rendering without secret_path must ignore .config/mcp" >&2
  exit 1
}
if grep -Fxq '.config/mcp' <<<"$present_data"; then
  echo "personal rendering with bw_ha_mcp must manage .config/mcp" >&2
  exit 1
fi

if grep -R -Fq --exclude-dir=.git -- "$sentinel_url" "$repo_root"; then
  echo "a literal private MCP URL is present in the source tree" >&2
  exit 1
fi

if grep -Eqs '"url"[[:space:]]*:[[:space:]]*"https?://|secret_path[[:space:]]*=[[:space:]]*"https?://' \
  "$config_template" "$ignore_template" "$template" "$repo_root/docs/secrets.md"; then
  echo "a literal private MCP URL is present in production sources" >&2
  exit 1
fi

echo "home assistant mcp private config ok"
