#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

fake_bin="$tmpdir/bin"
bw_log="$tmpdir/bw.log"
mkdir -p "$fake_bin"
: > "$bw_log"

cat > "$fake_bin/bw" <<'BW'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "${BW_LOG:?}"

if [[ "${BW_MODE:-}" == "missing-session" ]]; then
  echo "not logged in" >&2
  exit 1
fi

if [[ "${1:-}" != "get" || "${2:-}" != "item" ]]; then
  echo "unexpected bw command: $*" >&2
  exit 64
fi

item_id=${3:-}
case "$item_id" in
  manifest)
    manifest_json=$(cat <<'JSON'
{
  "keys": {
    "example_personal_key": {
      "scope": "personal",
      "mode": "local_file",
      "item": "local-key",
      "path": "~/.ssh/keys/personal/id_ed25519_example",
      "public_key": "ssh-ed25519 AAAA-local example_personal_key"
    },
    "example_work_key": {
      "scope": "work",
      "mode": "bitwarden_agent",
      "item": "work-key",
      "path": "~/.ssh/keys/work/id_ed25519_work",
      "public_key": "ssh-ed25519 AAAA-work example_work_key"
    }
  },
  "hosts": {
    "example-personal-host": {
      "scope": "personal",
      "host": "192.0.2.10",
      "user": "example",
      "port": 22,
      "key": "example_personal_key",
      "options": {"IdentitiesOnly": "yes"}
    },
    "example-work-bastion": {
      "scope": "work",
      "host": "work.example.invalid",
      "user": "example",
      "key": "example_work_key",
      "options": {"IdentitiesOnly": "yes"}
    }
  }
}
JSON
)
    jq -n --arg notes "$manifest_json" '{id:"manifest", notes:$notes}'
    ;;
  local-key)
    cat <<'JSON'
{
  "id": "local-key",
  "sshKey": {
    "privateKey": "fake-local-private-key\n",
    "publicKey": "ssh-ed25519 AAAA-local example_personal_key"
  }
}
JSON
    ;;
  work-key)
    cat <<'JSON'
{
  "id": "work-key",
  "sshKey": {
    "privateKey": "should-not-be-written\n",
    "publicKey": "ssh-ed25519 AAAA-work example_work_key"
  }
}
JSON
    ;;
  *)
    echo "unexpected bw item id: $item_id" >&2
    exit 64
    ;;
esac
BW
chmod +x "$fake_bin/bw"

refresh_cmd="$repo_root/dot_local/bin/executable_cz-ssh-refresh.tmpl"

new_home() {
  local name=$1
  local home_dir="$tmpdir/home-$name"
  rm -rf "$home_dir"
  mkdir -p "$home_dir"
  printf '%s\n' "$home_dir"
}

run_refresh() {
  local home_dir=$1
  local role=$2
  shift 2
  HOME="$home_dir" \
    PATH="$fake_bin:$PATH" \
    BW_LOG="$bw_log" \
    SSH_BW_MANIFEST_ITEM="manifest" \
    CHEZMOI_ROLE="$role" \
    BITWARDEN_SSH_AUTH_SOCK="$tmpdir/bw-agent.sock" \
    "$refresh_cmd" "$@"
}

run_refresh_without_config() {
  local home_dir=$1
  shift
  HOME="$home_dir" \
    PATH="$fake_bin:$PATH" \
    BW_LOG="$bw_log" \
    CHEZMOI_ROLE="personal" \
    BITWARDEN_SSH_AUTH_SOCK="$tmpdir/bw-agent.sock" \
    "$refresh_cmd" "$@"
}

assert_contains() {
  local file=$1
  local expected=$2
  if ! grep -Fq -- "$expected" "$file"; then
    echo "expected $file to contain: $expected" >&2
    echo "actual:" >&2
    cat "$file" >&2
    exit 1
  fi
}

assert_not_exists() {
  local path=$1
  if [[ -e "$path" ]]; then
    echo "expected path not to exist: $path" >&2
    exit 1
  fi
}

file_mode() {
  stat -f '%Lp' "$1" 2>/dev/null || stat -c '%a' "$1"
}

# Missing config skips by default and is strict with --fail.
config_home=$(new_home config)
if ! config_output=$(run_refresh_without_config "$config_home" 2>&1); then
  echo "expected missing config to skip with exit 0" >&2
  echo "$config_output" >&2
  exit 1
fi
if [[ "$config_output" != *warn:* ]]; then
  echo "expected missing config warning, got: $config_output" >&2
  exit 1
fi
if run_refresh_without_config "$config_home" --fail >/tmp/cz-ssh-refresh-strict.out 2>&1; then
  echo "expected --fail without config to exit non-zero" >&2
  cat /tmp/cz-ssh-refresh-strict.out >&2
  exit 1
fi

# Missing Bitwarden session skips by default.
session_home=$(new_home session)
if ! session_output=$(BW_MODE=missing-session run_refresh "$session_home" personal 2>&1); then
  echo "expected missing session to skip with exit 0" >&2
  echo "$session_output" >&2
  exit 1
fi
if [[ "$session_output" != *warn:* ]]; then
  echo "expected missing session warning, got: $session_output" >&2
  exit 1
fi

# local_file writes only scoped personal config and restrictive private key files.
personal_home=$(new_home personal)
: > "$bw_log"
run_refresh "$personal_home" personal
personal_conf="$personal_home/.ssh/config.d/personal.conf"
personal_key="$personal_home/.ssh/keys/personal/id_ed25519_example"
assert_contains "$personal_conf" "Host example-personal-host"
assert_contains "$personal_conf" "HostName 192.0.2.10"
assert_contains "$personal_conf" "IdentityFile ~/.ssh/keys/personal/id_ed25519_example"
assert_contains "$personal_key" "fake-local-private-key"
if [[ "$(file_mode "$personal_key")" != "600" ]]; then
  echo "expected $personal_key mode 600, got $(file_mode "$personal_key")" >&2
  exit 1
fi
assert_not_exists "$personal_home/.ssh/config.d/work.conf"
if grep -q -- "work-key" "$bw_log"; then
  echo "did not expect work key fetch during personal refresh" >&2
  cat "$bw_log" >&2
  exit 1
fi

# bitwarden_agent writes public-key hints and config, never private key material.
work_home=$(new_home work)
: > "$bw_log"
run_refresh "$work_home" work
work_conf="$work_home/.ssh/config.d/work.conf"
work_pub="$work_home/.ssh/public-keys/example_work_key.pub"
assert_contains "$work_conf" "Host example-work-bastion"
assert_contains "$work_conf" "IdentityAgent $tmpdir/bw-agent.sock"
assert_contains "$work_conf" "IdentityFile ~/.ssh/public-keys/example_work_key.pub"
assert_contains "$work_pub" "ssh-ed25519 AAAA-work example_work_key"
assert_not_exists "$work_home/.ssh/keys/work/id_ed25519_work"
if grep -R -- "should-not-be-written" "$work_home/.ssh" >/dev/null 2>&1; then
  echo "bitwarden_agent private key fixture was written under ~/.ssh" >&2
  exit 1
fi
if grep -q -- "work-key" "$bw_log"; then
  echo "bitwarden_agent must not fetch the private key item" >&2
  cat "$bw_log" >&2
  exit 1
fi
assert_not_exists "$work_home/.ssh/config.d/personal.conf"

# A migration to bitwarden_agent warns if a stale local private key still exists.
stale_home=$(new_home stale)
mkdir -p "$stale_home/.ssh/keys/work"
printf 'legacy-private-key\n' > "$stale_home/.ssh/keys/work/id_ed25519_work"
chmod 600 "$stale_home/.ssh/keys/work/id_ed25519_work"
if ! stale_output=$(run_refresh "$stale_home" work 2>&1); then
  echo "expected stale key refresh to succeed" >&2
  echo "$stale_output" >&2
  exit 1
fi
if [[ "$stale_output" != *"local private key still exists"* ]]; then
  echo "expected stale key warning, got: $stale_output" >&2
  exit 1
fi
assert_contains "$stale_home/.ssh/keys/work/id_ed25519_work" "legacy-private-key"

# Strict mode makes Bitwarden failures fatal.
fail_home=$(new_home fail)
if BW_MODE=missing-session run_refresh "$fail_home" personal --fail >/tmp/cz-ssh-refresh-fail.out 2>&1; then
  echo "expected --fail with missing session to exit non-zero" >&2
  cat /tmp/cz-ssh-refresh-fail.out >&2
  exit 1
fi

echo "ssh bitwarden refresh ok"
