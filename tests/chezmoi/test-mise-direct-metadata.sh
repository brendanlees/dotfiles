#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_BASE="${TMPDIR:-/tmp}"
TEST_ROOT="${TEST_BASE%/}/mise-direct-metadata-test-$$"
TEST_HOME="$TEST_ROOT/home"
MISE_LOCK="$TEST_HOME/.config/mise/mise.lock"
MISE_LOG="$TEST_ROOT/mise.log"
RENDERED_SCRIPT="$TEST_ROOT/install-tools.sh"
trap 'rm -rf "$TEST_ROOT"' EXIT

mkdir -p "$TEST_HOME/.local/bin" "$(dirname "$MISE_LOCK")"
cat >"$TEST_ROOT/chezmoi.toml" <<'TOML'
[data]
personal = false
work = false
homelab = false
ephemeral = true
headless = true
theme = "black-metal-bathory"
TOML

CHEZMOI_CONFIG_FILE="$TEST_ROOT/chezmoi.toml" \
  chezmoi execute-template --source "$ROOT" \
  <"$ROOT/.chezmoiscripts/run_after_install_tools.sh.tmpl" >"$RENDERED_SCRIPT"
chmod +x "$RENDERED_SCRIPT"

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

HOME="$TEST_HOME" \
XDG_CONFIG_HOME="$TEST_HOME/.config" \
XDG_CACHE_HOME="$TEST_HOME/.cache" \
PATH="/usr/bin:/bin" \
MISE_METADATA_TEST_LOG="$MISE_LOG" \
  "$RENDERED_SCRIPT"

[[ ! -e "$MISE_LOCK" ]]
grep -Fq 'self-update --yes --no-plugins' "$MISE_LOG"
grep -Fxq 'install' "$MISE_LOG"
grep -Fxq 'ls --installed' "$MISE_LOG"
grep -Fxq 'prune --yes' "$MISE_LOG"

echo "mise direct metadata cache ok"
