#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

render_data="$tmpdir/render-data.json"
rendered_external="$tmpdir/external.toml"
cat >"$render_data" <<'JSON'
{
  "personal": true,
  "work": false,
  "homelab": false,
  "ephemeral": false,
  "headless": false,
  "chezmoi": {"os": "darwin", "username": "fixture", "hostname": "host"}
}
JSON

chezmoi execute-template --source "$repo_root" --override-data-file "$render_data" \
  --file "$repo_root/home/.chezmoiexternal.toml.tmpl" >"$rendered_external"

for repo in claude-config pi-config; do
  expected="ssh://git@gitea.lab.brendans.cloud/xbxd/$repo.git"
  grep -Fqx "url = \"$expected\"" "$rendered_external"
done

if grep -Fq 'https://gitea.lab.brendans.cloud/xbxd/' "$rendered_external"; then
  echo 'Gitea external repositories must not use HTTPS Git transport' >&2
  exit 1
fi

migration_script="$tmpdir/migrate-gitea-remotes.sh"
chezmoi execute-template --source "$repo_root" --override-data-file "$render_data" \
  --file "$repo_root/home/.chezmoiscripts/run_before_migrate-gitea-external-remotes.sh.tmpl" \
  >"$migration_script"
chmod +x "$migration_script"

for repo in claude-config pi-config; do
  target="$tmpdir/home/.${repo%-config}"
  mkdir -p "$target"
  git init --quiet "$target"
  git -C "$target" remote add origin \
    "https://gitea.lab.brendans.cloud/xbxd/$repo.git"
done

HOME="$tmpdir/home" "$migration_script"
for repo in claude-config pi-config; do
  target="$tmpdir/home/.${repo%-config}"
  expected="ssh://git@gitea.lab.brendans.cloud/xbxd/$repo.git"
  [[ $(git -C "$target" remote get-url origin) == "$expected" ]]
done

echo 'Gitea external repositories use SSH and migrate existing HTTPS checkouts'
