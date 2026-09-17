#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
source_root="$repo_root/home"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/bin" "$tmpdir/home"
cat >"$tmpdir/bin/spicetify" <<'SH'
#!/bin/sh
if [ "${1-}" = '-v' ]; then
  printf '2.44.0\n'
  exit 0
fi
printf '%s\n' "$*" >>"$SPICETIFY_LOG"
exit 0
SH
cat >"$tmpdir/bin/pgrep" <<'SH'
#!/bin/sh
[ "${SPOTIFY_RUNNING:-0}" = 1 ]
SH
chmod +x "$tmpdir/bin/spicetify" "$tmpdir/bin/pgrep"

role_data=$(printf '{"personal":true,"work":false,"homelab":false,"ephemeral":false,"headless":false,"theme":"black-metal-bathory","chezmoi":{"homeDir":"%s","os":"darwin"}}' "$tmpdir/home")

rendered=$(PATH="$tmpdir/bin:$PATH" chezmoi execute-template \
  --source="$repo_root" \
  --override-data "$role_data" \
  <"$source_root/.chezmoiscripts/darwin/run_onchange_after_apply-spicetify.sh.tmpl")

rendered_config=$(chezmoi execute-template \
  --source="$repo_root" \
  --override-data "$role_data" \
  <"$source_root/dot_config/spicetify/config-xpui.ini.tmpl")

grep -Fq 'if spicetify_apply apply; then' <<<"$rendered"
grep -Fq 'elif spicetify_apply backup apply; then' <<<"$rendered"
grep -Fq 'spicetify_apply restore backup apply' <<<"$rendered"
grep -Fq 'pgrep -x Spotify' <<<"$rendered"
grep -Fq 'spicetify "$@" --no-restart' <<<"$rendered"
grep -Fq 'extensions            = keyboardShortcut.js|cat-jam.js' <<<"$rendered_config"
grep -Fq 'custom_apps           = marketplace|stats|library' <<<"$rendered_config"
# The upstream checker ignores GitHub tokens and runs on every CLI invocation.
grep -Eq '^check_spicetify_update[[:space:]]*=[[:space:]]*0$' <<<"$rendered_config"
if grep -Fq 'spicetify auto' <<<"$rendered"; then
  echo 'Spicetify has no auto command' >&2
  exit 1
fi

hook="$tmpdir/spicetify-hook"
printf '%s\n' "$rendered" | sed "s#/Applications/Spotify.app#$tmpdir/Spotify.app#g" >"$hook"
chmod +x "$hook"
mkdir -p "$tmpdir/Spotify.app" "$tmpdir/home/Library/Application Support/Spotify"
: >"$tmpdir/home/Library/Application Support/Spotify/prefs"

run_hook() {
  local running=$1
  : >"$tmpdir/spicetify.log"
  SPICETIFY_LOG="$tmpdir/spicetify.log" SPOTIFY_RUNNING="$running" \
    PATH="$tmpdir/bin:/usr/bin:/bin" "$hook"
}

run_hook 0
grep -Fxq -- 'apply --no-restart' "$tmpdir/spicetify.log"
if grep -Fxq -- 'apply' "$tmpdir/spicetify.log"; then
  echo 'inactive Spotify must not use restart-capable apply' >&2
  exit 1
fi

run_hook 1
grep -Fxq -- 'apply' "$tmpdir/spicetify.log"
if grep -Fq -- '--no-restart' "$tmpdir/spicetify.log"; then
  echo 'active Spotify should use restart-capable apply' >&2
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

for data in \
  '{"personal":false,"headless":false,"chezmoi":{"os":"darwin"}}' \
  '{"personal":true,"headless":true,"chezmoi":{"os":"darwin"}}'; do
  output=$(chezmoi execute-template --source "$repo_root" --override-data "$data" \
    --file "$source_root/.chezmoiscripts/darwin/run_onchange_after_apply-spicetify.sh.tmpl")
  [[ -z $output ]] || { echo 'Spicetify hook must skip out-of-scope hosts' >&2; exit 1; }
done

echo 'declarative Spicetify contract ok'
