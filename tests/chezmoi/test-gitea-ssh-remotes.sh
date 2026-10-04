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
  "ssh": {"bw_manifest_item": ""},
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

# Configure Bitwarden only for the fresh-machine case. Existing SSH setups
# without a manifest retain the external behavior tested above.
python3 - "$render_data" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
data = json.loads(path.read_text())
data['ssh'] = {'bw_manifest_item': 'fixture-manifest'}
path.write_text(json.dumps(data))
PY

# Reproduce a new machine with no shell setup, tools or SSH credentials. Keep
# real hook names so chezmoi owns the ordering; only external services are fake.
fixture="$tmpdir/source"
fresh_home="$tmpdir/fresh-home"
mkdir -p "$fixture/.chezmoiscripts/darwin" "$fixture/dot_local/bin" \
  "$fixture/private_dot_ssh" "$fixture/dot_config/mise" "$fresh_home" "$tmpdir/bin"
printf 'shell installed\n' >"$fixture/dot_zshrc"
printf 'tools configured\n' >"$fixture/dot_config/mise/config.toml"
cp "$repo_root/home/private_dot_ssh/config.tmpl" "$fixture/private_dot_ssh/config.tmpl"
for template in \
  "$repo_root"/home/.chezmoiscripts/run_after_*install-tools.sh.tmpl \
  "$repo_root"/home/.chezmoiscripts/*refresh-ssh-keys.sh.tmpl \
  "$repo_root"/home/.chezmoiscripts/darwin/run_after_reconcile-private-agent-skills.sh.tmpl; do
  relative=${template#"$repo_root/home/"}
  chezmoi execute-template --source "$repo_root" --override-data-file "$render_data" \
    --file "$template" >"$fixture/$relative"
done
cat >"$fixture/dot_local/bin/executable_mise" <<'SH'
#!/bin/sh
set -eu
test -f "$HOME/.config/mise/config.toml"
case "$*" in
  'exec node -- '*claude*)
    mkdir -p "$HOME/.claude"
    printf 'installed\n' >"$HOME/.claude/cli-installed"
    ;;
esac
printf 'installed\n' >"$HOME/tools-installed"
mkdir -p "$HOME/.local/share/mise/shims"
printf '#!/bin/sh\nexit 0\n' >"$HOME/.local/share/mise/shims/jq"
chmod +x "$HOME/.local/share/mise/shims/jq"
SH
cat >"$fixture/dot_local/bin/executable_cz-ssh-refresh" <<'SH'
#!/bin/sh
set -eu
test "${1:-}" = --if-changed
test -f "$HOME/tools-installed"
test "$(command -v jq)" = "$HOME/.local/share/mise/shims/jq"
# A skipped refresh must be retried on the next apply after unlocking.
[ "${FIXTURE_BW_LOCKED:-0}" = 0 ] || exit 0
mkdir -p "$HOME/.ssh/config.d"
printf 'fixture\n' >"$HOME/.ssh/config.d/personal.conf"
SH
cat >"$fixture/dot_local/bin/executable_cz-private-agent-skills" <<'SH'
#!/bin/sh
set -eu
test -f "$HOME/.ssh/config.d/personal.conf"
test "$(command -v jq)" = "$HOME/.local/share/mise/shims/jq"
printf 'reconciled\n' >"$HOME/skills-reconciled"
SH
cat >"$tmpdir/bin/git" <<'SH'
#!/bin/sh
set -eu
if [ "$1" = clone ]; then
  test -f "$HOME/.ssh/config.d/personal.conf" || {
    echo 'fixture: private clone attempted before SSH provisioning' >&2
    exit 128
  }
  for destination do :; done
  if [ -d "$destination" ] && [ -n "$(ls -A "$destination")" ]; then
    echo 'fixture: cannot clone into a nonempty directory' >&2
    exit 128
  fi
  mkdir -p "$destination/.git"
  printf '%s\n' "$*" >>"$HOME/clones"
fi
SH
chmod +x "$tmpdir/bin/git"
chezmoi_bin=$(command -v chezmoi)
printf '[data]\npersonal = true\n' >"$tmpdir/fresh.toml"
apply_fresh() {
  # Re-render on every apply: private externals can become eligible after SSH
  # provisioning. Exclude public downloads from this offline regression.
  for template in \
    "$repo_root/home/.chezmoiscripts/run_onchange_after_configure-pi-theme.py.tmpl" \
    "$repo_root/home/.chezmoiscripts/darwin/run_onchange_after_install-packages-npm.sh.tmpl"; do
    relative=${template#"$repo_root/home/"}
    "$chezmoi_bin" execute-template --source "$repo_root" --override-data-file "$render_data" \
      --override-data "{\"chezmoi\":{\"homeDir\":\"$fresh_home\"}}" \
      --file "$template" >"$fixture/$relative"
  done
  "$chezmoi_bin" execute-template --source "$repo_root" --override-data-file "$render_data" \
    --override-data "{\"chezmoi\":{\"homeDir\":\"$fresh_home\"}}" \
    --file "$repo_root/home/.chezmoiexternal.toml.tmpl" >"$tmpdir/fresh-externals.toml"
  python3 - "$tmpdir/fresh-externals.toml" "$fixture/.chezmoiexternal.json" <<'PY'
import json
import sys
import tomllib
from pathlib import Path
entries = tomllib.loads(Path(sys.argv[1]).read_text())
Path(sys.argv[2]).write_text(json.dumps({k: v for k, v in entries.items() if k in ('.claude', '.pi')}))
PY
  HOME="$fresh_home" XDG_CONFIG_HOME="$fresh_home/.config" PI_AGENT_DIR='' \
    MISE_DATA_DIR="$fresh_home/.local/share/mise" PATH="$tmpdir/bin:/usr/bin:/bin" "$chezmoi_bin" apply \
    --source "$fixture" --destination "$fresh_home" --config "$tmpdir/fresh.toml" \
    --persistent-state "$tmpdir/fresh-state.boltdb" --force
}
FIXTURE_BW_LOCKED=1 apply_fresh
[[ -f "$fresh_home/.zshrc" && -f "$fresh_home/tools-installed" ]]
[[ ! -e "$fresh_home/clones" && ! -e "$fresh_home/.pi" && ! -e "$fresh_home/.claude" ]]
apply_fresh
[[ -f "$fresh_home/skills-reconciled" ]]
apply_fresh
[[ -d "$fresh_home/.claude/.git" && -d "$fresh_home/.pi/.git" ]]
[[ $(wc -l <"$fresh_home/clones") -eq 2 ]]
[[ -f "$fresh_home/.pi/agent/themes/chezmoi.json" && -f "$fresh_home/.claude/cli-installed" ]]

echo 'Private repo bootstrap waits for SSH, retries after unlock and preserves base provisioning'
