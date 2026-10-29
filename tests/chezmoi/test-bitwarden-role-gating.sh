#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

bw_log="$tmpdir/bw.log"
fake_bin="$tmpdir/bin"
mkdir -p "$fake_bin"
: > "$bw_log"

cat > "$fake_bin/bw" <<'BW'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "${BW_LOG:?}"

item_id="${!#}"
case "$item_id" in
  acf48b07-70b7-43d0-9b2d-b42d0149b091)
    field_name="personal_field"
    field_value="personal-value"
    ;;
  d256649b-8944-43a3-a016-abc1018ad825)
    field_name="read_only_token"
    field_value="github-token"
    ;;
  7acadcd9-f0cf-4fa5-bed2-b46a00743ba5)
    field_name="read_only_token"
    field_value="huggingface-token"
    ;;
  040ae08a-b331-4d3b-abc6-b303002d2a94)
    field_name="gitea_field"
    field_value="gitea-value"
    ;;
  007b0e02-0af0-41e4-9779-b42d0156e6aa)
    field_name="homelab_admin_field"
    field_value="homelab-admin-value"
    ;;
  0c4c3b88-6ed3-49a0-9f59-b487007acf3e)
    field_name="api-key"
    field_value="executor-token"
    ;;
  afa4395b-8044-46b1-86c9-b48d007e82ac)
    field_name="secret_path"
    field_value="ha-mcp-value"
    ;;
  ce6cc659-50b0-43c1-a15c-b4f20011264f)
    field_name="${VICINAE_FIELD_NAME:-webhook_n8n_ws-tasks}"
    field_value="https://hooks.example.invalid/weekly-tasks?token=fixture"
    ;;
  0b9286df-9ffc-4ab8-996e-b42d014e44d4)
    field_name="work_field"
    field_value="work-value"
    ;;
  *)
    echo "unexpected bw item id: $item_id" >&2
    exit 64
    ;;
esac

cat <<JSON
{
  "id": "$item_id",
  "name": "fake-$item_id",
  "fields": [
    {"name": "$field_name", "value": "$field_value", "type": 0}
  ]
}
JSON
BW
chmod +x "$fake_bin/bw"

render_role() {
  local role=$1
  local safe_role=${role//[^A-Za-z0-9]/_}
  local home_dir="$tmpdir/home-$safe_role"
  local cache_dir="$tmpdir/cache-$safe_role"
  local config_file="$tmpdir/config-$safe_role.toml"
  local state_file="$tmpdir/state-$safe_role.boltdb"
  local output_file="$tmpdir/init-$safe_role.out"

  rm -rf "$home_dir" "$cache_dir" "$config_file" "$state_file" "$output_file"
  mkdir -p "$home_dir" "$cache_dir"
  cat > "$config_file" <<'TOML'
[data]
  headless = false
  github_token = "fixture-old-download-token"
  git_name = "Test User"
  git_email = "test@example.com"
TOML
  : > "$bw_log"

  if ! CHEZMOI_ROLE="$role" GITHUB_DOWNLOAD_TOKEN="${INIT_TOKEN:-}" \
    GH_TOKEN=fixture-agent-token GITHUB_TOKEN=fixture-project-token \
    BW_LOG="$bw_log" PATH="$fake_bin:$PATH" \
    chezmoi init \
      --source "$repo_root" \
      --config "$config_file" \
      --config-path "$config_file" \
      --destination "$home_dir" \
      --cache "$cache_dir" \
      --persistent-state "$state_file" \
      --force \
      --no-tty \
      > "$output_file" 2>&1; then
    cat "$output_file" >&2
    exit 1
  fi
}

assert_zero_bw_calls() {
  local role=$1
  render_role "$role"
  if [[ -s "$bw_log" ]]; then
    echo "expected zero bw calls for CHEZMOI_ROLE=$role, got:" >&2
    cat "$bw_log" >&2
    exit 1
  fi
}

assert_bw_item_ids() {
  local role=$1
  shift
  render_role "$role"

  local expected_count=$#
  local actual_count
  actual_count=$(wc -l < "$bw_log" | tr -d '[:space:]')
  if [[ "$actual_count" != "$expected_count" ]]; then
    echo "expected $expected_count bw calls for CHEZMOI_ROLE=$role, got $actual_count:" >&2
    cat "$bw_log" >&2
    exit 1
  fi

  local item_id
  for item_id in "$@"; do
    if ! grep -q -- "$item_id" "$bw_log"; then
      echo "missing bw item $item_id for CHEZMOI_ROLE=$role; calls were:" >&2
      cat "$bw_log" >&2
      exit 1
    fi
  done
  python3 - "$tmpdir/config-${role//[^A-Za-z0-9]/_}.toml" "${INIT_TOKEN:-github-token}" <<'PY'
import sys
import tomllib
from pathlib import Path
data = tomllib.loads(Path(sys.argv[1]).read_text())['data']
assert data['github_token'] == sys.argv[2]
assert data['bw_vicinae']['weekly_tasks_url'] == 'https://hooks.example.invalid/weekly-tasks?token=fixture'
PY
}

assert_zero_bw_calls "ephemeral,headless"
assert_zero_bw_calls "homelab"
assert_zero_bw_calls "work"

assert_bw_item_ids "personal" \
  "acf48b07-70b7-43d0-9b2d-b42d0149b091" \
  "d256649b-8944-43a3-a016-abc1018ad825" \
  "7acadcd9-f0cf-4fa5-bed2-b46a00743ba5" \
  "040ae08a-b331-4d3b-abc6-b303002d2a94" \
  "007b0e02-0af0-41e4-9779-b42d0156e6aa" \
  "afa4395b-8044-46b1-86c9-b48d007e82ac" \
  "0c4c3b88-6ed3-49a0-9f59-b487007acf3e" \
  "ce6cc659-50b0-43c1-a15c-b4f20011264f"

INIT_TOKEN=fixture-injected-token assert_bw_item_ids "personal,work" \
  "acf48b07-70b7-43d0-9b2d-b42d0149b091" \
  "d256649b-8944-43a3-a016-abc1018ad825" \
  "7acadcd9-f0cf-4fa5-bed2-b46a00743ba5" \
  "040ae08a-b331-4d3b-abc6-b303002d2a94" \
  "007b0e02-0af0-41e4-9779-b42d0156e6aa" \
  "afa4395b-8044-46b1-86c9-b48d007e82ac" \
  "0c4c3b88-6ed3-49a0-9f59-b487007acf3e" \
  "0b9286df-9ffc-4ab8-996e-b42d014e44d4" \
  "ce6cc659-50b0-43c1-a15c-b4f20011264f"

# A missing optional field must not break init or populate an unusable URL.
VICINAE_FIELD_NAME=unrelated_field render_role personal
python3 - "$tmpdir/config-personal.toml" <<'PY'
import sys
import tomllib
from pathlib import Path
assert not tomllib.loads(Path(sys.argv[1]).read_text())['data']['bw_vicinae']
PY

# Execute the rendered bootstrap expansion with a stub installer. It must pass
# the download input to init without replacing a project's GitHub credential.
PATH="$fake_bin:$PATH" chezmoi execute-template --source "$repo_root" \
  --config "$tmpdir/config-personal_work.toml" \
  --file "$repo_root/home/dot_config/espanso/match/cli.yml.tmpl" >"$tmpdir/cli.yml"
cat >"$fake_bin/curl" <<'CURL'
#!/bin/sh
exit 0
CURL
cat >"$fake_bin/sh" <<'SH'
#!/usr/bin/env bash
set -eu
[[ $GITHUB_DOWNLOAD_TOKEN == github-token && $GITHUB_TOKEN == fixture-project-token ]]
SH
chmod +x "$fake_bin/curl" "$fake_bin/sh"
python3 - "$tmpdir/cli.yml" "$fake_bin" <<'CHECK'
import os
import re
import subprocess
import sys
from pathlib import Path
snippet = re.search(r'trigger: "==cz-init-gh"\s+replace: \'(.*)\'', Path(sys.argv[1]).read_text()).group(1)
subprocess.run(['bash', '-c', snippet], check=True, env={
    **os.environ, 'PATH': sys.argv[2] + os.pathsep + os.environ['PATH'],
    'GITHUB_DOWNLOAD_TOKEN': '', 'GITHUB_TOKEN': 'fixture-project-token',
})
CHECK

echo "bitwarden role gating and download bootstrap input ok"
