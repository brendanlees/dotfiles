#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
aliases_file="$repo_root/home/dot_config/zsh/exact_private_aliases.d/bitwarden.zsh"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

fake_bin="$tmpdir/bin"
mkdir -p "$fake_bin"

export FIXTURE_ITEM="$tmpdir/item.json"
cat >"$FIXTURE_ITEM" <<'JSON'
{"id":"id-1","name":"HA MCP","fields":[
  {"name":"secret_path","value":"fixture-secret-1"},
  {"name":"api-key","value":"fixture-secret-2"},
  {"name":"unused","value":"fixture-secret-3"}]}
JSON

cat >"$fake_bin/bw" <<'BW'
#!/usr/bin/env bash
set -euo pipefail

case "$*" in
  'list items --search ha-mcp')
    jq -s '.' "$FIXTURE_ITEM"
    ;;
  'list items --search none') printf '[]\n' ;;
  *)
    echo "unexpected bw invocation: $*" >&2
    exit 64
    ;;
esac
BW
chmod +x "$fake_bin/bw"
for tool in jq cat bash zsh; do ln -s "$(command -v "$tool")" "$fake_bin/$tool"; done

run() {
  PATH="$fake_bin" ALIASES_FILE="$aliases_file" \
    zsh -fc 'source "$ALIASES_FILE"; cz-bw-fields "$@"' cz-bw-fields "$@"
}

# shellcheck disable=SC2016 # Expected output is literal chezmoi template text.
expected='# HA MCP
{{- $bw_ha_mcp := includeTemplate ".chezmoitemplates/vault-fields.tmpl" "id-1" | fromJson }}
[data.bw_ha_mcp]
  secret_path = {{ $bw_ha_mcp.secret_path.value | quote }}
  api_key = {{ (index $bw_ha_mcp "api-key").value | quote }}'
actual=$(run ha-mcp secret_path api-key)
[[ $actual == "$expected" ]] || {
  printf 'unexpected output:\n%s\n' "$actual" >&2
  exit 1
}

rm "$fake_bin/bw"
cat >"$fake_bin/rbw" <<'RBW'
#!/bin/sh
case "$*" in
  'search --fields id -- ha-mcp') echo id-1 ;;
  'search --fields id -- none') ;;
  'get --raw id-1') cat "$FIXTURE_ITEM" ;;
  *) exit 64 ;;
esac
RBW
chmod +x "$fake_bin/rbw"
[[ $(run ha-mcp secret_path api-key) == "$expected" ]]

all_fields=$(run ha-mcp)
# shellcheck disable=SC2016 # Literal chezmoi template text.
grep -Fq 'unused = {{ $bw_ha_mcp.unused.value | quote }}' <<<"$all_fields"
if grep -q 'fixture-secret' <<<"$all_fields"; then
  echo 'cz-bw-fields printed a Bitwarden field value' >&2
  exit 1
fi

if run none 2>/dev/null; then
  echo 'cz-bw-fields should fail when no items match' >&2
  exit 1
fi

echo 'cz-bw-fields prints lookup templates without secret values'
