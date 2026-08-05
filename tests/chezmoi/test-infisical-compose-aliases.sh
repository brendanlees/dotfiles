#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ALIASES_TEMPLATE="$ROOT/dot_config/zsh/exact_aliases.d/docker.zsh.tmpl"
TEST_BASE="${TMPDIR:-/tmp}"
TEST_ROOT="${TEST_BASE%/}/infisical-compose-aliases-test-$$"
ALIASES="$TEST_ROOT/docker.zsh"
COMPOSE_DIR="$TEST_ROOT/home/docker/compose"
BIN_DIR="$TEST_ROOT/bin"
LOG="$TEST_ROOT/commands.log"
ZSH_BIN="$(command -v zsh)"
trap 'rm -rf "$TEST_ROOT"' EXIT

mkdir -p "$COMPOSE_DIR/infisical/proxy" "$BIN_DIR"
touch "$COMPOSE_DIR/compose.proxy.yml" "$COMPOSE_DIR/.env" "$COMPOSE_DIR/.env-proxy"
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
  chezmoi execute-template <"$ALIASES_TEMPLATE" >"$ALIASES"
cat >"$COMPOSE_DIR/infisical/proxy/.infisical.json" <<'JSON'
{
  "workspaceId": "project-123",
  "defaultEnvironment": "prod",
  "defaultSecretPath": "/nodes/test-node",
  "domain": "http://127.0.0.1:18080"
}
JSON

cat >"$BIN_DIR/infisical" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  login)
    [[ "${INFISICAL_UNIVERSAL_AUTH_CLIENT_ID:-}" == "client-id" ]]
    [[ "${INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET:-}" == "client-secret" ]]
    printf 'infisical login' >>"$INFI_ALIAS_TEST_LOG"
    printf ' <%s>' "$@" >>"$INFI_ALIAS_TEST_LOG"
    printf '\n' >>"$INFI_ALIAS_TEST_LOG"
    printf '%s\n' 'test-token'
    ;;
  run)
    [[ "${INFISICAL_UNIVERSAL_AUTH_ACCESS_TOKEN:-}" == "test-token" ]]
    [[ -z "${INFISICAL_TOKEN:-}" ]]
    [[ -z "${INFISICAL_UNIVERSAL_AUTH_CLIENT_ID:-}" ]]
    [[ -z "${INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET:-}" ]]
    [[ -z "${BW_SESSION:-}" ]]
    printf 'infisical run' >>"$INFI_ALIAS_TEST_LOG"
    printf ' <%s>' "$@" >>"$INFI_ALIAS_TEST_LOG"
    printf '\n' >>"$INFI_ALIAS_TEST_LOG"
    while [[ "$1" != "--" ]]; do shift; done
    shift
    export KOP_BIND_IP=bind KOP_DOCKER_HOST=host KOP_REDIS_ADDR=redis
    exec "$@"
    ;;
  *) exit 2 ;;
esac
SH

cat >"$BIN_DIR/bw" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf 'bw' >>"$INFI_ALIAS_TEST_LOG"
printf ' <%s>' "$@" >>"$INFI_ALIAS_TEST_LOG"
printf '\n' >>"$INFI_ALIAS_TEST_LOG"
case "${1:-}" in
  unlock)
    [[ "${2:-}" == "--raw" ]]
    printf '%s\n' 'test-bw-session'
    ;;
  get)
    [[ "${2:-}" == "item" ]]
    [[ "${3:-}" == "e0421ba7-4f2d-4c27-8fff-b49a00a87137" ]]
    [[ "${BW_SESSION:-}" == "test-bw-session" ]]
    cat <<'JSON'
{
  "type": 2,
  "name": "Infisical credentials",
  "fields": [
    {"name": "KOMODO-RPI1_CLIENT_ID", "value": "client-id", "type": 0},
    {"name": "KOMODO-RPI1_CLIENT_SECRET", "value": "client-secret", "type": 1}
  ]
}
JSON
    ;;
  lock)
    [[ "${BW_SESSION:-}" == "test-bw-session" ]]
    ;;
  *) exit 2 ;;
esac
SH

cat >"$BIN_DIR/sudo" <<'SH'
#!/usr/bin/env bash
echo 'sudo must not be used by Infisical Compose aliases' >&2
exit 99
SH

cat >"$BIN_DIR/docker" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ -z "${INFISICAL_TOKEN:-}" ]]
[[ -z "${INFISICAL_UNIVERSAL_AUTH_ACCESS_TOKEN:-}" ]]
[[ -z "${INFISICAL_UNIVERSAL_AUTH_CLIENT_ID:-}" ]]
[[ -z "${INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET:-}" ]]
[[ -z "${BW_SESSION:-}" ]]
[[ "$KOP_BIND_IP" == "bind" ]]
[[ "$KOP_DOCKER_HOST" == "host" ]]
[[ "$KOP_REDIS_ADDR" == "redis" ]]
printf 'docker' >>"$INFI_ALIAS_TEST_LOG"
printf ' <%s>' "$@" >>"$INFI_ALIAS_TEST_LOG"
printf '\n' >>"$INFI_ALIAS_TEST_LOG"
SH
chmod +x "$BIN_DIR/infisical" "$BIN_DIR/bw" "$BIN_DIR/sudo" "$BIN_DIR/docker"

# The default flow prompts once, preserves the cached access token when the
# aliases are re-sourced, and prompts again only after an explicit clear.
: >"$LOG"
printf '%s\n' client-id client-secret client-id client-secret | \
  HOME="$TEST_ROOT/home" \
  PATH="$BIN_DIR:$PATH" \
  INFI_ALIAS_TEST_LOG="$LOG" \
  "$ZSH_BIN" -fc "
    cd '$COMPOSE_DIR'
    setopt aliases
    source '$ALIASES'
    eval 'idcrec.proxy'
    [[ \${parameters[_INFISICAL_COMPOSE_ACCESS_TOKEN]} != *export* ]]
    source '$ALIASES'
    eval 'idcpull.proxy'
    infi-auth-clear
    eval 'idcrestart.proxy'
  "

[[ "$(grep -c '^infisical login' "$LOG")" -eq 2 ]]
[[ "$(grep -c '^infisical run' "$LOG")" -eq 3 ]]
grep -Fq 'infisical login <login> <--domain=http://127.0.0.1:18080>' "$LOG"
grep -Fq 'infisical run <run> <--domain=http://127.0.0.1:18080>' "$LOG"
if grep -q '^bw ' "$LOG"; then
  echo 'manual auth unexpectedly invoked bw' >&2
  exit 1
fi
if grep -q -- '--token' "$LOG"; then
  echo 'access token was passed on the command line' >&2
  exit 1
fi
grep -Fq '<--projectId=project-123>' "$LOG"
grep -Fq '<--env=prod>' "$LOG"
grep -Fq '<--path=/nodes/test-node>' "$LOG"
grep -Fq "docker <compose> <--env-file> <$COMPOSE_DIR/.env> <--env-file> <$COMPOSE_DIR/.env-proxy> <-f> <$COMPOSE_DIR/compose.proxy.yml> <up> <-d> <--force-recreate>" "$LOG"

# Profiles without a domain retain the public self-hosted endpoint.
cat >"$COMPOSE_DIR/infisical/proxy/.infisical.json" <<'JSON'
{
  "workspaceId": "project-123",
  "defaultEnvironment": "prod",
  "defaultSecretPath": "/nodes/test-node"
}
JSON
: >"$LOG"
printf '%s\n' client-id client-secret | \
  HOME="$TEST_ROOT/home" \
  PATH="$BIN_DIR:$PATH" \
  INFI_ALIAS_TEST_LOG="$LOG" \
  "$ZSH_BIN" -fc "
    cd '$COMPOSE_DIR'
    setopt aliases
    source '$ALIASES'
    eval 'idcrec.proxy'
  "
grep -Fq 'infisical login <login> <--domain=https://infisical.lab.brendans.cloud>' "$LOG"
grep -Fq 'infisical run <run> <--domain=https://infisical.lab.brendans.cloud>' "$LOG"

# Bitwarden is opt-in. It derives the uppercase custom field names from the
# explicit namespace, exchanges the pair, re-locks, and primes the same cache.
: >"$LOG"
HOME="$TEST_ROOT/home" \
PATH="$BIN_DIR:$PATH" \
INFI_ALIAS_TEST_LOG="$LOG" \
"$ZSH_BIN" -fc "
  cd '$COMPOSE_DIR'
  setopt aliases
  source '$ALIASES'
  infi-auth-bw komodo-rpi1
  eval 'idcrec.proxy'
"

[[ "$(grep -c '^infisical login' "$LOG")" -eq 1 ]]
[[ "$(grep -c '^infisical run' "$LOG")" -eq 1 ]]
grep -Fq 'bw <unlock> <--raw>' "$LOG"
grep -Fq 'bw <get> <item> <e0421ba7-4f2d-4c27-8fff-b49a00a87137>' "$LOG"
grep -Fq 'bw <lock>' "$LOG"

# On a host without bw, the optional helper leaves an existing token untouched.
HOME="$TEST_ROOT/home" \
PATH="/usr/bin:/bin" \
"$ZSH_BIN" -fc "
  cd '$COMPOSE_DIR'
  source '$ALIASES'
  _INFISICAL_COMPOSE_ACCESS_TOKEN=sentinel
  infi-auth-bw komodo-rpi1
  rc=\$?
  [[ \$rc -eq 127 ]]
  [[ \$_INFISICAL_COMPOSE_ACCESS_TOKEN == sentinel ]]
"
