#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_root="$repo_root/home"
template="$source_root/dot_config/private_mcp/private_mcp.json.tmpl"
config_template="$source_root/.chezmoi.toml.tmpl"
ignore_template="$source_root/.chezmoiignore"
ha_item_id="afa4395b-8044-46b1-86c9-b48d007e82ac"
executor_url="https://executor.lab.brendans.cloud/mcp/toolkits/hermes-work"
# shellcheck disable=SC2016 # Match the literal Go-template variable name.
executor_assignment_pattern='\$bw_executor_work := bitwardenFields "item" "[0-9a-f-]{36}"'
# shellcheck disable=SC2016 # Match the literal Go-template variable name.
executor_bearer_template='bearer_token = {{ (index $bw_executor_work "api-key").value | quote }}'
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

missing=0
if [[ ! -f "$template" ]]; then
  echo "missing production private MCP template: $template" >&2
  missing=1
fi
if ! grep -Fq "bitwardenFields \"item\" \"$ha_item_id\"" "$config_template" ||
  ! grep -Fq '[data.bw_ha_mcp]' "$config_template"; then
  echo "missing cached bw_ha_mcp data wiring" >&2
  missing=1
fi
if ! grep -Eq "$executor_assignment_pattern" "$config_template" ||
  ! grep -Fq '[data.bw_executor_work]' "$config_template" ||
  ! grep -Fq "$executor_bearer_template" "$config_template"; then
  echo "missing cached bw_executor_work data wiring" >&2
  missing=1
fi
((missing == 0)) || exit 1

sentinel_url=$(printf 'https://%s/%s?%s=%s&%s=%s' \
  'sentinel.invalid' 'mcp' 'quote' '"' 'backslash' $'\\')
sentinel_token='sentinel-executor-token-not-a-secret'
minimal_source="$tmpdir/source"
mkdir -p "$minimal_source/dot_config/private_mcp"
cp "$template" "$minimal_source/dot_config/private_mcp/private_mcp.json.tmpl"
cp "$ignore_template" "$minimal_source/.chezmoiignore"

mode_of() {
  if stat -f '%Lp' "$1" >/dev/null 2>&1; then
    stat -f '%Lp' "$1"
  else
    stat -c '%a' "$1"
  fi
}

render_case() {
  local name=$1
  local expected=$2
  local config=$3
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
    echo "$name render case failed to apply" >&2
    return 1
  fi

  local target="$case_home/.config/mcp/mcp.json"
  [[ -f "$target" ]] || {
    echo "$name render case is missing the MCP target" >&2
    return 1
  }

  EXPECTED="$expected" SENTINEL_URL="$sentinel_url" SENTINEL_TOKEN="$sentinel_token" \
    EXECUTOR_URL="$executor_url" TARGET="$target" python3 - <<'PY'
import json
import os
from pathlib import Path

actual = json.loads(Path(os.environ["TARGET"]).read_text())
servers = {}
if os.environ["EXPECTED"] in {"both", "ha"}:
    servers["home-assistant"] = {
        "type": "http",
        "url": os.environ["SENTINEL_URL"],
    }
if os.environ["EXPECTED"] in {"both", "executor"}:
    servers["executor-work"] = {
        "type": "http",
        "url": os.environ["EXECUTOR_URL"],
        "headers": {
            "Authorization": f"Bearer {os.environ['SENTINEL_TOKEN']}"
        },
    }
if actual != {"mcpServers": servers}:
    raise SystemExit("rendered private MCP JSON has unexpected shape")
PY

  [[ $(mode_of "$case_home/.config/mcp") == 700 ]] || {
    echo "$name expected .config/mcp mode 0700" >&2
    return 1
  }
  [[ $(mode_of "$target") == 600 ]] || {
    echo "$name expected mcp.json mode 0600" >&2
    return 1
  }
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
    echo "$name ignored case failed to apply" >&2
    return 1
  fi
  if [[ -e "$case_home/.config/mcp" ]]; then
    echo "$name ignored case must not manage .config/mcp" >&2
    return 1
  fi
}

common_data=$(cat <<'TOML'
  work = false
  homelab = false
  headless = false
TOML
)

both_config=$(SENTINEL_URL="$sentinel_url" SENTINEL_TOKEN="$sentinel_token" python3 - <<'PY'
import json
import os
print(f'''[data]
  personal = true
  work = false
  homelab = false
  headless = false

[data.bw_ha_mcp]
  secret_path = {json.dumps(os.environ["SENTINEL_URL"])}

[data.bw_executor_work]
  bearer_token = {json.dumps(os.environ["SENTINEL_TOKEN"])}''')
PY
)
ha_only_config=$(SENTINEL_URL="$sentinel_url" python3 - <<'PY'
import json
import os
print(f'''[data]
  personal = true
  work = false
  homelab = false
  headless = false

[data.bw_ha_mcp]
  secret_path = {json.dumps(os.environ["SENTINEL_URL"])}''')
PY
)
executor_only_config=$(SENTINEL_TOKEN="$sentinel_token" python3 - <<'PY'
import json
import os
print(f'''[data]
  personal = true
  work = false
  homelab = false
  headless = false

[data.bw_executor_work]
  bearer_token = {json.dumps(os.environ["SENTINEL_TOKEN"])}''')
PY
)

render_case "both" "both" "$both_config"
render_case "ha-only" "ha" "$ha_only_config"
render_case "executor-only" "executor" "$executor_only_config"
render_case "malformed-ha-with-executor" "executor" "[data]
  personal = true
$common_data

[data.bw_ha_mcp]
  secret_path = \"https:/sentinel.invalid/mcp\"

[data.bw_executor_work]
  bearer_token = \"$sentinel_token\""

apply_ignored_case "nonpersonal" "[data]
  personal = false
$common_data

[data.bw_ha_mcp]
  secret_path = \"https://sentinel.invalid/mcp\"

[data.bw_executor_work]
  bearer_token = \"$sentinel_token\""
apply_ignored_case "missing-maps" "[data]
  personal = true
$common_data"
apply_ignored_case "empty-executor" "[data]
  personal = true
$common_data

[data.bw_executor_work]
  bearer_token = \"\""
apply_ignored_case "malformed-ha" "[data]
  personal = true
$common_data

[data.bw_ha_mcp]
  secret_path = \"ftp://sentinel.invalid/mcp\""

missing_data_config="$tmpdir/chezmoi-missing-data.toml"
printf '%s\n' "[data]
  personal = false
$common_data" >"$missing_data_config"
if ! missing_data_output=$(chezmoi execute-template --config "$missing_data_config" <"$template"); then
  echo "template must render safely when private MCP data is absent" >&2
  exit 1
fi
[[ -z "$missing_data_output" ]] || {
  echo "template must render empty when private MCP data is absent" >&2
  exit 1
}

if grep -R -Fq --exclude-dir=.git -- "$sentinel_url" "$repo_root"; then
  echo "a literal private MCP sentinel URL is present in the source tree" >&2
  exit 1
fi
if grep -Eqs 'secret_path[[:space:]]*=[[:space:]]*"https?://' \
  "$config_template" "$ignore_template" "$template" "$repo_root/docs/secrets.md"; then
  echo "a literal private Home Assistant MCP URL is present in production sources" >&2
  exit 1
fi
if grep -Eqs '"Authorization"[[:space:]]*:[[:space:]]*"Bearer[[:space:]][^"]+' \
  "$config_template" "$ignore_template" "$template"; then
  echo "a literal Executor bearer is present in production sources" >&2
  exit 1
fi
if ! grep -Fq "$executor_url" "$template"; then
  echo "production template is missing the fixed Executor toolkit URL" >&2
  exit 1
fi

echo "private mcp config ok"
