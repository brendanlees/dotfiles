#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_root="$repo_root/home"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/bin" "$tmpdir/home"
cat >"$tmpdir/bin/spicetify" <<'SH'
#!/bin/sh
case "${1-}" in
  -v) printf '2.44.0\n' ;;
  *) exit 0 ;;
esac
SH
chmod +x "$tmpdir/bin/spicetify"

role_data=$(printf '{"personal":true,"work":false,"homelab":false,"ephemeral":false,"headless":false,"theme":"black-metal-bathory","chezmoi":{"homeDir":"%s","os":"darwin"}}' "$tmpdir/home")

rendered=$(PATH="$tmpdir/bin:$PATH" chezmoi execute-template \
  --source="$repo_root" \
  --override-data "$role_data" \
  <"$source_root/.chezmoiscripts/darwin/run_onchange_after_apply-spicetify.sh.tmpl")

rendered_config=$(chezmoi execute-template \
  --source="$repo_root" \
  --override-data "$role_data" \
  <"$source_root/dot_config/spicetify/config-xpui.ini.tmpl")

grep -Fq 'spicetify backup apply' <<<"$rendered"
grep -Fq 'extensions            = keyboardShortcut.js|cat-jam.js' <<<"$rendered_config"
grep -Fq 'custom_apps           = marketplace|stats|library' <<<"$rendered_config"
if grep -Fq 'spicetify auto' <<<"$rendered"; then
  echo 'Spicetify has no auto command' >&2
  exit 1
fi

external="$source_root/.chezmoiexternal.toml.tmpl"
grep -Fq '[".config/spicetify/CustomApps/marketplace"]' "$external"
grep -Fq 'releases/latest/download/marketplace.zip' "$external"
grep -Fq '[".config/spicetify/Extensions/{{ .filename }}"]' "$external"
grep -Fq 'url = "{{ .url }}"' "$external"
if grep -Fq 'marketplaceVersion:' "$source_root/.chezmoidata/spicetify.yml"; then
  echo 'Marketplace should track the latest release without a version bump' >&2
  exit 1
fi
grep -Fq 'filename: keyboardShortcut.js' "$source_root/.chezmoidata/spicetify.yml"
grep -Fq 'c9571cd0365ec653f18f002c9958f36026d753d5/Extensions/keyboardShortcut.js' \
  "$source_root/.chezmoidata/spicetify.yml"
grep -Fq 'filename: cat-jam.js' "$source_root/.chezmoidata/spicetify.yml"
grep -Fq 'e7bfd49fcc13457bbc98e696294cf5cf43eb6c31/marketplace/cat-jam.js' \
  "$source_root/.chezmoidata/spicetify.yml"

echo 'declarative Spicetify contract ok'
