#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
# Keep the Unix socket below macOS's path-length limit.
tmpdir=$(mktemp -d /tmp/cz-ssh.XXXXXX)
test_agent_pid=''
trap '[[ -z "$test_agent_pid" ]] || kill "$test_agent_pid"; rm -rf "$tmpdir"' EXIT
real_ssh=$(command -v ssh)
export REAL_SSH="$real_ssh"

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
fresh_home="$tmpdir/fresh home"
mkdir -p "$fixture/.chezmoiscripts/darwin" "$fixture/dot_local/bin" \
  "$fixture/private_dot_ssh" "$fixture/dot_config/mise" "$fresh_home" "$tmpdir/bin"
printf 'shell installed\n' >"$fixture/dot_zshrc"
printf 'tools configured\n' >"$fixture/dot_config/mise/config.toml"
cp "$repo_root/home/dot_local/bin/executable_cz-ssh-ready" "$fixture/dot_local/bin/"
ssh-keygen -q -t ed25519 -N '' -f "$tmpdir/fixture-key"
mkdir -p "$fresh_home/.ssh/public-keys"
cp "$tmpdir/fixture-key.pub" "$fresh_home/.ssh/public-keys/fixture.pub"
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
test -z "${1:-}"
printf 'called\n' >>"$HOME/ssh-refresh-calls"
test -f "$HOME/tools-installed"
test "$(command -v jq)" = "$HOME/.local/share/mise/shims/jq"
# A skipped refresh must be retried on the next apply after unlocking.
[ "${FIXTURE_BW_LOCKED:-0}" = 0 ] || exit 0
mkdir -p "$HOME/.ssh/config.d"
cat >"$HOME/.ssh/config.d/personal.conf" <<CONF
Host gitea.lab.brendans.cloud
  IdentityAgent "$HOME/.bitwarden-ssh-agent.sock"
  IdentityFile "$HOME/.ssh/public-keys/fixture.pub"
  IdentitiesOnly yes
CONF
mkdir -p "$XDG_STATE_HOME/chezmoi"
printf 'complete\n' >"$XDG_STATE_HOME/chezmoi/ssh-refresh"
SH
cat >"$fixture/dot_local/bin/executable_cz-private-agent-skills" <<'SH'
#!/bin/sh
set -eu
"$HOME/.local/bin/cz-ssh-ready" git@gitea.lab.brendans.cloud
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
# Restrict OpenSSH to the synthetic config, not the real user's tilde Includes.
cat >"$tmpdir/bin/ssh" <<'SH'
#!/bin/sh
set -eu
[ "$1" = -G ] && [ "$2" = -F ]
shift 3
exec "$REAL_SSH" -G -F "$HOME/.ssh/config.d/personal.conf" "$@"
SH
chmod +x "$tmpdir/bin/git" "$tmpdir/bin/ssh"
chezmoi_bin=$(command -v chezmoi)
printf '[data]\npersonal = true\n' >"$tmpdir/fresh.toml"
apply_fresh() {
  # Re-render on every apply: private externals can become eligible after SSH
  # provisioning. Exclude public downloads from this offline regression.
  for template in \
    "$repo_root/home/.chezmoiscripts/run_onchange_after_configure-pi-theme.py.tmpl" \
    "$repo_root/home/.chezmoiscripts/darwin/run_onchange_after_install-packages-npm.sh.tmpl"; do
    relative=${template#"$repo_root/home/"}
    PATH="$tmpdir/bin:$PATH" "$chezmoi_bin" execute-template --source "$repo_root" --override-data-file "$render_data" \
      --override-data "{\"chezmoi\":{\"homeDir\":\"$fresh_home\"}}" \
      --file "$template" >"$fixture/$relative"
  done
  PATH="$tmpdir/bin:$PATH" "$chezmoi_bin" execute-template --source "$repo_root" --override-data-file "$render_data" \
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
  HOME="$fresh_home" XDG_CONFIG_HOME="$fresh_home/.config" XDG_STATE_HOME="$fresh_home/.local/state" PI_AGENT_DIR='' \
    MISE_DATA_DIR="$fresh_home/.local/share/mise" PATH="$tmpdir/bin:/usr/bin:/bin" "$chezmoi_bin" apply \
    --source "$fixture" --destination "$fresh_home" --config "$tmpdir/fresh.toml" \
    --persistent-state "$tmpdir/fresh-state.boltdb" --force
}
FIXTURE_BW_LOCKED=1 apply_fresh
[[ -f "$fresh_home/.zshrc" && -f "$fresh_home/tools-installed" ]]
[[ ! -e "$fresh_home/clones" && ! -e "$fresh_home/.pi" && ! -e "$fresh_home/.claude" ]]
apply_fresh
# Config generation succeeded, but an absent agent is not readiness.
[[ -f "$fresh_home/.local/state/chezmoi/ssh-refresh" ]]
apply_fresh
[[ ! -e "$fresh_home/clones" && ! -e "$fresh_home/.pi" && ! -e "$fresh_home/.claude" ]]
[[ ! -e "$fresh_home/skills-reconciled" ]]
[[ $(wc -l <"$fresh_home/ssh-refresh-calls") -eq 2 ]]

# A listening agent with no keys must also defer private clones.
# Older ssh-agent versions do not quote socket paths with spaces in their output.
# Set the socket ourselves and extract only the PID, rather than evaluating shell code.
export SSH_AUTH_SOCK="$fresh_home/.bitwarden-ssh-agent.sock"
test_agent_pid=$(ssh-agent -s -a "$SSH_AUTH_SOCK" | awk -F '[=;]' '/^SSH_AGENT_PID=/ {print $2}')
apply_fresh
[[ ! -e "$fresh_home/clones" && ! -e "$fresh_home/skills-reconciled" ]]

# A different key does not satisfy the generated public-key hint.
ssh-keygen -q -t ed25519 -N '' -f "$tmpdir/wrong-key"
ssh-add "$tmpdir/wrong-key" >/dev/null 2>&1
apply_fresh
[[ ! -e "$fresh_home/clones" && ! -e "$fresh_home/skills-reconciled" ]]
ssh-add "$tmpdir/fixture-key" >/dev/null 2>&1

# Upgrades may already have usable SSH but not the newly introduced helper.
# Externals are evaluated before apply installs that helper.
rm "$fresh_home/.local/bin/cz-ssh-ready"
readiness() {
  "$chezmoi_bin" execute-template --source "$repo_root" --override-data-file "$render_data" \
    --override-data "{\"chezmoi\":{\"homeDir\":\"$fresh_home\"}}" \
    '{{ includeTemplate ".chezmoitemplates/private-harness-ready.tmpl" . }}'
}
[[ $(PATH="$tmpdir/bin:$PATH" readiness) == true ]] || {
  echo 'Existing SSH must work before the readiness helper is installed' >&2
  exit 1
}
[[ $(PATH="$tmpdir/bin" readiness) == false ]] || {
  echo 'Missing Python must defer private fetches safely' >&2
  exit 1
}
apply_fresh
[[ -f "$fresh_home/skills-reconciled" ]]
[[ -d "$fresh_home/.claude/.git" && -d "$fresh_home/.pi/.git" ]]
[[ $(wc -l <"$fresh_home/clones") -eq 2 ]]
[[ $(wc -l <"$fresh_home/ssh-refresh-calls") -eq 2 ]]
[[ -f "$fresh_home/.pi/agent/themes/chezmoi.json" && -f "$fresh_home/.claude/cli-installed" ]]

# Existing non-agent hosts do not need Bitwarden; effective Host selection matters.
printf '\nHost local-key\n  IdentityAgent none\n' >>"$fresh_home/.ssh/config.d/personal.conf"
HOME="$fresh_home" PATH="$tmpdir/bin:$PATH" "$fresh_home/.local/bin/cz-ssh-ready" git@local-key:owner/repo.git
# SSH URL user/port parsing uses the same host-specific check.
HOME="$fresh_home" PATH="$tmpdir/bin:$PATH" "$fresh_home/.local/bin/cz-ssh-ready" ssh://git@gitea.lab.brendans.cloud:2222/owner/repo.git

# Existing custom socket variables work, but missing variables are not guessed.
cat >>"$fresh_home/.ssh/config.d/personal.conf" <<'CONF'
Host custom-agent
  IdentityAgent $FIXTURE_CUSTOM_AGENT
CONF
HOME="$fresh_home" PATH="$tmpdir/bin:$PATH" FIXTURE_CUSTOM_AGENT="$SSH_AUTH_SOCK" \
  "$fresh_home/.local/bin/cz-ssh-ready" git@custom-agent:owner/repo.git
if env -u FIXTURE_CUSTOM_AGENT HOME="$fresh_home" PATH="$tmpdir/bin:$PATH" \
  "$fresh_home/.local/bin/cz-ssh-ready" git@custom-agent:owner/repo.git >"$tmpdir/unset.log" 2>&1; then
  echo 'unset agent variable unexpectedly considered ready' >&2
  exit 1
fi
grep -Fq 'cz-ssh-refresh --fail' "$tmpdir/unset.log"

# Exercise the timeout path without waiting for a real hung process.
python3 - "$repo_root/home/dot_local/bin/executable_cz-ssh-ready" <<'PY'
import contextlib
import io
import runpy
import subprocess
import sys
helper = runpy.run_path(sys.argv[1])
original_run = subprocess.run
def timeout(args, **kwargs):
    assert kwargs['timeout'] == 5
    raise subprocess.TimeoutExpired(args, kwargs['timeout'])
subprocess.run = timeout
try:
    sys.argv = ['cz-ssh-ready', 'git@example.invalid']
    with contextlib.redirect_stderr(io.StringIO()) as errors:
        assert helper['main']() == 1
    assert 'SSH is not ready' in errors.getvalue()
finally:
    subprocess.run = original_run
PY

# A dead agent is not readiness.
kill "$test_agent_pid"
wait "$test_agent_pid" 2>/dev/null || true
test_agent_pid=''
if HOME="$fresh_home" PATH="$tmpdir/bin:$PATH" "$fresh_home/.local/bin/cz-ssh-ready" git@gitea.lab.brendans.cloud >/dev/null 2>&1; then
  echo 'dead agent unexpectedly considered ready' >&2
  exit 1
fi

# Local hooks remain usable after cloning even when private fetches are deferred.
python3 - "$render_data" "$repo_root" <<'PY'
import json
import subprocess
import sys
from pathlib import Path
path = Path(sys.argv[1])
data = json.loads(path.read_text())
registry = json.loads(subprocess.check_output(
    ['chezmoi', 'data', '--source', sys.argv[2], '--format', 'json'], text=True,
))
data['theme'] = 'fixture'
data['themes'] = {'fixture': next(iter(registry['themes'].values()))}
path.write_text(json.dumps(data))
PY
apply_fresh
jq -e '.vars.activeTheme == "fixture"' "$fresh_home/.pi/agent/themes/chezmoi.json" >/dev/null
grep -Fq 'exec node -- claude install --force latest' \
  "$fixture/.chezmoiscripts/darwin/run_onchange_after_install-packages-npm.sh.tmpl"
[[ $(wc -l <"$fresh_home/clones") -eq 2 ]]
[[ $(wc -l <"$fresh_home/ssh-refresh-calls") -eq 2 ]]
python3 - "$fixture/.chezmoiexternal.json" <<'PY'
import json
import sys
from pathlib import Path
assert json.loads(Path(sys.argv[1]).read_text()) == {}, 'private fetches still require the agent'
PY

echo 'Private bootstrap gates fetches on agent readiness and keeps existing local hooks usable offline'
