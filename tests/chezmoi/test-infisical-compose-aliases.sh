#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ALIASES_TEMPLATE="$ROOT/dot_config/zsh/exact_aliases.d/docker.zsh.tmpl"
TEST_ROOT="${TMPDIR:-/tmp}/infisical-compose-aliases-test-$$"
ALIASES="$TEST_ROOT/docker.zsh"
COMPOSE_DIR="$TEST_ROOT/home/docker/compose"
BIN_DIR="$TEST_ROOT/bin"
LOG="$TEST_ROOT/commands.log"
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
  "managedKeys": ["KOP_BIND_IP", "KOP_DOCKER_HOST", "KOP_REDIS_ADDR"]
}
JSON

cat >"$BIN_DIR/infisical" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  login)
    [[ "${INFISICAL_UNIVERSAL_AUTH_CLIENT_ID:-}" == "client-id" ]]
    [[ "${INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET:-}" == "client-secret" ]]
    printf '%s\n' 'test-token'
    ;;
  run)
    [[ -z "${INFISICAL_UNIVERSAL_AUTH_CLIENT_ID:-}" ]]
    [[ -z "${INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET:-}" ]]
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

cat >"$BIN_DIR/sudo" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == "--preserve-env=KOP_BIND_IP,KOP_DOCKER_HOST,KOP_REDIS_ADDR" ]]
shift
exec "$@"
SH

cat >"$BIN_DIR/docker" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ "$KOP_BIND_IP" == "bind" ]]
[[ "$KOP_DOCKER_HOST" == "host" ]]
[[ "$KOP_REDIS_ADDR" == "redis" ]]
printf 'docker' >>"$INFI_ALIAS_TEST_LOG"
printf ' <%s>' "$@" >>"$INFI_ALIAS_TEST_LOG"
printf '\n' >>"$INFI_ALIAS_TEST_LOG"
SH
chmod +x "$BIN_DIR/infisical" "$BIN_DIR/sudo" "$BIN_DIR/docker"

HOME="$TEST_ROOT/home" \
PATH="$BIN_DIR:$PATH" \
INFI_ALIAS_TEST_LOG="$LOG" \
INFISICAL_UNIVERSAL_AUTH_CLIENT_ID=client-id \
INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET=client-secret \
zsh -fc "cd '$COMPOSE_DIR'; setopt aliases; source '$ALIASES'; eval 'idcrec.proxy'"

grep -Fq '<--projectId=project-123>' "$LOG"
grep -Fq '<--env=prod>' "$LOG"
grep -Fq '<--path=/nodes/test-node>' "$LOG"
grep -Fq "docker <compose> <--env-file> <$COMPOSE_DIR/.env> <--env-file> <$COMPOSE_DIR/.env-proxy> <-f> <$COMPOSE_DIR/compose.proxy.yml> <up> <-d> <--force-recreate>" "$LOG"
