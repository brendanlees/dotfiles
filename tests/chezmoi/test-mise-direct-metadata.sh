#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
home="$tmpdir/home"
mkdir -p "$home/.local/bin" "$home/.config/mise" "$tmpdir/project"
printf '[data]\ngithub_token = "fixture-cached-token"\n' >"$tmpdir/config.toml"
printf 'keep this generated lockfile\n' >"$home/.config/mise/mise.lock"

chezmoi execute-template --source "$repo_root" --config "$tmpdir/config.toml" \
  --override-data '{"chezmoi":{"os":"linux"}}' \
  --file "$repo_root/home/.chezmoiscripts/run_after_install_tools.sh.tmpl" >"$tmpdir/install.sh"

cat >"$home/.local/bin/mise" <<'MISE'
#!/usr/bin/env bash
set -euo pipefail
# Applying config installs missing global tools, never upgrades or prunes.
[[ $# -eq 3 && $1 == --cd && $2 == "$HOME" && $3 == install ]] || exit 91
[[ $MISE_USE_VERSIONS_HOST == 0 && $MISE_CACHE_DIR == "$HOME/.cache/mise-direct" ]] || exit 92
[[ $GITHUB_TOKEN == "$EXPECTED_TOKEN" ]] || exit 93
printf 'install\n' >>"$INSTALL_LOG"
exit "${INSTALL_STATUS:-0}"
MISE
chmod +x "$home/.local/bin/mise"

run_install() {
  (cd "$tmpdir/project" && HOME="$home" XDG_CONFIG_HOME="$home/.config" \
    XDG_CACHE_HOME="$home/.cache" PATH=/usr/bin:/bin INSTALL_LOG="$tmpdir/install.log" \
    GITHUB_API_TOKEN='' GITHUB_TOKEN="$1" EXPECTED_TOKEN="$2" \
    INSTALL_STATUS="${3:-0}" bash "$tmpdir/install.sh")
}
run_install '' fixture-cached-token
run_install fixture-injected-token fixture-injected-token
if run_install '' fixture-cached-token 42; then
  echo 'tool install failure must fail apply' >&2
  exit 1
fi
grep -Fxq 'keep this generated lockfile' "$home/.config/mise/mise.lock"
[[ $(wc -l <"$tmpdir/install.log") -eq 3 ]]

# Root skips other users' project configs instead of granting blanket trust.
for username in root ordinary-user; do
  for template in config.toml miserc.toml; do
    chezmoi execute-template --source "$repo_root" --config "$tmpdir/config.toml" \
      --override-data "{\"personal\":false,\"homelab\":true,\"chezmoi\":{\"os\":\"linux\",\"username\":\"$username\"}}" \
      --file "$repo_root/home/dot_config/mise/$template.tmpl" >"$tmpdir/$username.$template"
  done
done
python3 - "$tmpdir" <<'PY'
import sys
import tomllib
from pathlib import Path
root = Path(sys.argv[1])
for username in ('root', 'ordinary-user'):
    config = tomllib.loads((root / f'{username}.config.toml').read_text())
    assert 'trusted_config_paths' not in config['settings']
    assert 'credential_command' in config['settings']['github']
    assert {'tmux', 'chezmoi'} <= config['tools'].keys()
    rc = tomllib.loads((root / f'{username}.miserc.toml').read_text())
    assert rc.get('ignored_config_paths', []) == (['/home'] if username == 'root' else [])
PY

if grep -Eq '^ +-[[:space:]]+(tmux|chezmoi)$' "$repo_root/home/.chezmoidata/packages-darwin.yml"; then
  echo 'mise-owned tmux and chezmoi must not also be declared in Homebrew' >&2
  exit 1
fi

echo 'mise install and root config boundaries ok'
