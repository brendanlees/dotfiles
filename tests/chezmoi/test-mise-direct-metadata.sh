#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_BASE="${TMPDIR:-/tmp}"
TEST_ROOT="${TEST_BASE%/}/mise-direct-metadata-test-$$"
TEST_HOME="$TEST_ROOT/home"
MISE_LOCK="$TEST_HOME/.config/mise/mise.lock"
MISE_LOG="$TEST_ROOT/mise.log"
BREW_LOG="$TEST_ROOT/brew.log"
RENDERED_CONFIG="$TEST_ROOT/mise.toml"
RENDERED_SCRIPT="$TEST_ROOT/install-tools.sh"
trap 'rm -rf "$TEST_ROOT"' EXIT

mkdir -p "$TEST_HOME/.local/bin" "$(dirname "$MISE_LOCK")" "$TEST_ROOT/bin"
cat >"$TEST_ROOT/chezmoi.toml" <<'TOML'
[data]
personal = false
work = false
homelab = false
ephemeral = true
headless = true
theme = "black-metal-bathory"
TOML

chezmoi --config "$TEST_ROOT/chezmoi.toml" execute-template --source "$ROOT" \
  <"$ROOT/dot_config/mise/config.toml.tmpl" >"$RENDERED_CONFIG"
chezmoi --config "$TEST_ROOT/chezmoi.toml" execute-template --source "$ROOT" \
  <"$ROOT/.chezmoiscripts/run_after_install_tools.sh.tmpl" >"$RENDERED_SCRIPT"
chmod +x "$RENDERED_SCRIPT"

grep -Fxq 'chezmoi = "latest"' "$RENDERED_CONFIG"
if grep -Fxq '    - chezmoi' "$ROOT/.chezmoidata/packages-darwin.yml"; then
  echo "chezmoi must not be managed by Homebrew" >&2
  exit 1
fi

cat >"$MISE_LOCK" <<'LOCK'
[[tools.infisical]]
version = "0.43.118"

[tools.infisical."platforms.macos-arm64"]
checksum = "sha256:4403ad59f01e0f0a1465527163a5de882c685eabfd818997d1e314570591c293"
LOCK

cat >"$TEST_HOME/.local/bin/mise" <<'MISE'
#!/usr/bin/env bash
set -euo pipefail
[[ "${MISE_USE_VERSIONS_HOST:-}" == "0" ]]
[[ "${MISE_CACHE_DIR:-}" == "$XDG_CACHE_HOME/mise-direct" ]]
printf '%s\n' "$*" >>"${MISE_METADATA_TEST_LOG:?}"
case "${1:-}" in
  install)
    [[ ! -e "$HOME/.config/mise/mise.lock" ]]
    ;;
  ls)
    ;;
  self-update|prune)
    ;;
  *)
    echo "unexpected mise command: $*" >&2
    exit 2
    ;;
esac
MISE
chmod +x "$TEST_HOME/.local/bin/mise"

cat >"$TEST_ROOT/bin/brew" <<'BREW'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
  "list --formula chezmoi")
    ;;
  "uninstall --formula chezmoi")
    grep -Fxq 'install' "${MISE_METADATA_TEST_LOG:?}"
    printf '%s\n' "$*" >>"${BREW_MIGRATION_TEST_LOG:?}"
    ;;
  *)
    echo "unexpected brew command: $*" >&2
    exit 2
    ;;
esac
BREW
chmod +x "$TEST_ROOT/bin/brew"

HOME="$TEST_HOME" \
XDG_CONFIG_HOME="$TEST_HOME/.config" \
XDG_CACHE_HOME="$TEST_HOME/.cache" \
PATH="$TEST_ROOT/bin:/usr/bin:/bin" \
MISE_METADATA_TEST_LOG="$MISE_LOG" \
BREW_MIGRATION_TEST_LOG="$BREW_LOG" \
  "$RENDERED_SCRIPT"

[[ ! -e "$MISE_LOCK" ]]
grep -Fq 'self-update --yes --no-plugins' "$MISE_LOG"
grep -Fxq 'install' "$MISE_LOG"
grep -Fxq 'ls --installed' "$MISE_LOG"
grep -Fxq 'prune --yes' "$MISE_LOG"
if [[ "$(uname -s)" == "Darwin" ]]; then
  grep -Fxq 'uninstall --formula chezmoi' "$BREW_LOG"
else
  [[ ! -e "$BREW_LOG" ]]
fi

echo "mise direct metadata cache ok"
