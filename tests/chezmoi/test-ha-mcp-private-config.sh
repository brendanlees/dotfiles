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
((missing == 0)) || exit 1

sentinel_url=$(printf 'https://%s/%s?%s=%s&%s=%s' \
  'sentinel.invalid' 'mcp' 'quote' '"' 'backslash' $'\\')
minimal_source="$tmpdir/source"
home_dir="$tmpdir/home"
config_file="$tmpdir/chezmoi.toml"
mkdir -p "$minimal_source/dot_config/private_mcp" "$home_dir"
cp "$template" "$minimal_source/dot_config/private_mcp/private_mcp.json.tmpl"
cp "$ignore_template" "$minimal_source/.chezmoiignore"

SENTINEL_URL="$sentinel_url" CONFIG_FILE="$config_file" python3 - <<'PY'
import json
import os
from pathlib import Path

config = """[data]
  personal = true
  work = false
  headless = false

[data.bw_ha_mcp]
  secret_path = {}
""".format(json.dumps(os.environ["SENTINEL_URL"]))
Path(os.environ["CONFIG_FILE"]).write_text(config)
PY

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

apply_ignored_case() {
  local name=$1
  local config=$2
  local case_home="$tmpdir/home-$name"
  local case_config="$tmpdir/chezmoi-$name.toml"
  local case_output="$tmpdir/chezmoi-$name.out"

  mkdir -p "$case_home"
  printf '%s\n' "$config" >"$case_config"
  if ! chezmoi apply \
    --source "$minimal_source" \
    --config "$case_config" \
    --destination "$case_home" \
    --force \
    --no-tty \
    >"$case_output" 2>&1; then
    echo "$name gating case failed to apply" >&2
    return 1
  fi
  if [[ -e "$case_home/.config/mcp" ]]; then
    echo "$name gating case must not manage .config/mcp" >&2
    return 1
  fi
}

common_data=$(cat <<'TOML'
  work = false
  headless = false
TOML
)

gating_failures=0
apply_ignored_case "nonpersonal" "[data]
  personal = false
$common_data

[data.bw_ha_mcp]
  secret_path = \"https://sentinel.invalid/mcp\"" || gating_failures=1
apply_ignored_case "missing-map" "[data]
  personal = true
$common_data" || gating_failures=1
apply_ignored_case "missing-key" "[data]
  personal = true
$common_data

[data.bw_ha_mcp]" || gating_failures=1
apply_ignored_case "empty" "[data]
  personal = true
$common_data

[data.bw_ha_mcp]
  secret_path = \"\"" || gating_failures=1
apply_ignored_case "malformed-url" "[data]
  personal = true
$common_data

[data.bw_ha_mcp]
  secret_path = \"https:/sentinel.invalid/mcp\"" || gating_failures=1
apply_ignored_case "non-http-url" "[data]
  personal = true
$common_data

[data.bw_ha_mcp]
  secret_path = \"ftp://sentinel.invalid/mcp\"" || gating_failures=1
((gating_failures == 0)) || exit 1

missing_data_config="$tmpdir/chezmoi-missing-data.toml"
printf '%s\n' "[data]
  personal = false
$common_data" >"$missing_data_config"
if ! missing_data_output=$(chezmoi execute-template --config "$missing_data_config" <"$template"); then
  echo "template must render safely when bw_ha_mcp data is absent" >&2
  exit 1
fi
[[ -z "$missing_data_output" ]] || {
  echo "template must render empty when bw_ha_mcp data is absent" >&2
  exit 1
}

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
