#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
home="$tmpdir/home"
mkdir -p "$home/.local/bin" "$home/.config/mise" "$tmpdir/project"
printf '[data]\ngithub_token = "fixture-cached-token"\n' >"$tmpdir/config.toml"
printf 'keep this generated lockfile\n' >"$home/.config/mise/mise.lock"

install_templates=("$repo_root"/home/.chezmoiscripts/run_after_*install*tools.sh.tmpl)
install_template=${install_templates[0]}
chezmoi execute-template --source "$repo_root" --config "$tmpdir/config.toml" \
  --override-data '{"chezmoi":{"os":"linux"}}' \
  --file "$install_template" >"$tmpdir/install.sh"

cat >"$home/.local/bin/mise" <<'MISE'
#!/usr/bin/env bash
set -euo pipefail
# Applying config installs missing global tools, never upgrades or prunes.
[[ $1 == --cd && $2 == "$HOME" ]] || exit 91
shift 2
case "$*" in
  install)
    [[ $MISE_USE_VERSIONS_HOST == 0 && $MISE_CACHE_DIR == "$HOME/.cache/mise-direct" ]] || exit 92
    [[ $GITHUB_TOKEN == "$EXPECTED_TOKEN" && $GITHUB_API_TOKEN == "$EXPECTED_TOKEN" ]] || exit 93
    printf 'install\n' >>"$INSTALL_LOG"
    exit "${INSTALL_STATUS:-0}"
    ;;
  'exec -- uv tool install esphome')
    [[ -s "$INSTALL_LOG" ]] || exit 94
    printf '%s\n' "$*" >>"$UV_LOG"
    exit "${UV_STATUS:-0}"
    ;;
  *) exit 95 ;;
esac
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
    assert config['tools']['go'] == '1.26.2'
    rc = tomllib.loads((root / f'{username}.miserc.toml').read_text())
    assert rc.get('ignored_config_paths', []) == (['/home'] if username == 'root' else [])
PY

if grep -Eq '^ +-[[:space:]]+(tmux|chezmoi)$' "$repo_root/home/.chezmoidata/packages-darwin.yml"; then
  echo 'mise-owned tmux and chezmoi must not also be declared in Homebrew' >&2
  exit 1
fi

# A fresh apply must install tools before any other POSIX after-hook. Keep the
# real hook paths so chezmoi, not a hand-written sort, determines execution order.
fixture="$tmpdir/source"
mkdir -p "$fixture/.chezmoiscripts"
python3 - "$repo_root/home/.chezmoiscripts" "$fixture/.chezmoiscripts" <<'PY'
import sys
from pathlib import Path
source, dest = map(Path, sys.argv[1:])
for path in source.rglob('run_*after_*.sh*'):
    relative = path.relative_to(source)
    if 'windows' in relative.parts or 'install_tools' in path.name or 'install-tools' in path.name:
        continue
    output = dest / relative
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text('#!/bin/sh\nset -eu\ntest -s "$INSTALL_LOG"\n')
PY
cp "$tmpdir/install.sh" "$fixture/.chezmoiscripts/$(basename "${install_template%.tmpl}")"
uv_templates=("$repo_root"/home/.chezmoiscripts/darwin/run_onchange_*_install-packages-uv.sh.tmpl)
uv_template=${uv_templates[0]}
chezmoi execute-template --source "$repo_root" --config "$tmpdir/config.toml" \
  --override-data '{"personal":true,"work":false,"homelab":false}' \
  --file "$uv_template" >"$fixture/.chezmoiscripts/darwin/$(basename "$uv_template")"
: >"$tmpdir/first-install.log"
HOME="$home" XDG_CONFIG_HOME="$home/.config" XDG_CACHE_HOME="$home/.cache" \
  PATH=/usr/bin:/bin INSTALL_LOG="$tmpdir/first-install.log" UV_LOG="$tmpdir/uv.log" \
  GITHUB_API_TOKEN='' GITHUB_TOKEN='' EXPECTED_TOKEN=fixture-cached-token \
  "$(command -v chezmoi)" apply --source "$fixture" --destination "$home" \
  --config "$tmpdir/config.toml" --persistent-state "$tmpdir/state.boltdb" --force
[[ $(wc -l <"$tmpdir/first-install.log") -eq 1 ]]
[[ $(wc -l <"$tmpdir/uv.log") -eq 2 ]]
if HOME="$home" PATH=/usr/bin:/bin INSTALL_LOG="$tmpdir/first-install.log" \
  UV_LOG="$tmpdir/uv.log" UV_STATUS=42 sh "$fixture/.chezmoiscripts/darwin/$(basename "$uv_template")"; then
  echo 'uv install failure must fail apply' >&2
  exit 1
fi

# Init must retain an injected bootstrap token for future commands, including a
# re-init with neither the original environment nor Bitwarden available.
for injected in fixture-init-token ''; do
  CHEZMOI_ROLE=ephemeral,headless GITHUB_TOKEN="$injected" chezmoi init \
    --source "$repo_root" --destination "$home" --config "$tmpdir/init.toml" \
    --config-path "$tmpdir/init.toml" --cache "$tmpdir/init-cache" \
    --persistent-state "$tmpdir/init-state.boltdb" --no-tty --force
  python3 - "$tmpdir/init.toml" <<'PY'
import sys
import tomllib
from pathlib import Path
assert tomllib.loads(Path(sys.argv[1]).read_text())['data']['github_token'] == 'fixture-init-token'
PY
done

# Shells resolve the same cache without writing a token into the shell profile.
# Execute only the auth section, avoiding plugins and interactive startup work.
chezmoi execute-template --source "$repo_root" --config "$tmpdir/config.toml" \
  --override-data '{"personal":false,"homelab":false,"chezmoi":{"os":"linux"}}' \
  --file "$repo_root/home/dot_zshrc.tmpl" >"$tmpdir/zshrc"
python3 - "$tmpdir/zshrc" "$tmpdir/auth.zsh" <<'PY'
import sys
from pathlib import Path
text = Path(sys.argv[1]).read_text()
assert 'fixture-cached-token' not in text
start = text.index('# api tokens')
end = text.index('# starship', start)
assert text.index('mise activate zsh') < start
Path(sys.argv[2]).write_text(text[start:end])
PY
mkdir -p "$tmpdir/bin"
ln -s "$(command -v chezmoi)" "$tmpdir/bin/chezmoi"
cat >"$tmpdir/bin/gh" <<'GH'
#!/bin/sh
printf 'gh\n' >>"$GH_LOG"
printf 'fixture-gh-token\n'
GH
chmod +x "$tmpdir/bin/gh"
zsh_bin=$(command -v zsh)
run_shell() {
  mkdir -p "$home/.config/chezmoi"
  cp "$tmpdir/config.toml" "$home/.config/chezmoi/chezmoi.toml"
  # shellcheck disable=SC2016 # Expanded by the isolated zsh process, not bash.
  HOME="$home" XDG_CONFIG_HOME="$home/.config" \
    PATH="$tmpdir/bin:/usr/bin:/bin" GH_LOG="$tmpdir/gh.log" \
    GITHUB_TOKEN="$1" GITHUB_PERSONAL_ACCESS_TOKEN="$2" GH_TOKEN_AUTOEXPORT="$3" \
    EXPECTED_TOKEN="$4" "$zsh_bin" -f -c '
      source "$1"
      [[ ${GITHUB_TOKEN:-} == "$EXPECTED_TOKEN" ]] || exit 1
      if [[ ${GH_TOKEN_AUTOEXPORT:-} == 0 ]]; then
        [[ $(gh-token) == fixture-cached-token ]] || exit 1
      fi
    ' zsh "$tmpdir/auth.zsh"
}
run_shell '' '' '' fixture-cached-token
run_shell fixture-injected '' '' fixture-injected
run_shell '' fixture-legacy '' fixture-legacy
run_shell '' '' 0 ''
[[ ! -e "$tmpdir/gh.log" ]]
printf '[data]\n' >"$tmpdir/config.toml"
run_shell '' '' '' fixture-gh-token
[[ $(wc -l <"$tmpdir/gh.log") -eq 1 ]]

echo 'mise install, bootstrap ordering and shared GitHub credentials ok'
