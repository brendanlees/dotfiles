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

if [[ "${1:-}" == "status" && "${2:-}" == "--raw" ]]; then
  case "${BW_MODE:-unlocked}" in
    locked)
      printf '{"status":"locked"}
'
      exit 0
      ;;
    missing-session)
      echo "not logged in" >&2
      exit 1
      ;;
    *)
      printf '{"status":"unlocked"}
'
      exit 0
      ;;
  esac
fi

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
  manifest|"manifest'quoted")
    case "${BW_MANIFEST_VARIANT:-default}" in
      default)
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
      "options": {"IdentitiesOnly": "yes", "UseKeychain": "yes"}
    },
    "example-work-bastion": {
      "scope": "work",
      "host": "work.example.invalid",
      "user": "example",
      "key": "example_work_key",
      "options": {"IdentitiesOnly": "yes", "UseKeychain": "yes"}
    }
  }
}
JSON
)
        ;;
      symlink-path)
        manifest_json=$(cat <<'JSON'
{
  "keys": {
    "escape_key": {
      "scope": "personal",
      "mode": "local_file",
      "item": "local-key",
      "path": "~/.ssh/keys/escape/id_ed25519_escape",
      "public_key": "ssh-ed25519 AAAA-escape escape_key"
    }
  },
  "hosts": {
    "example-symlink-host": {
      "scope": "personal",
      "host": "192.0.2.20",
      "user": "example",
      "key": "escape_key"
    }
  }
}
JSON
)
        ;;
      missing-host)
        manifest_json=$(cat <<'JSON'
{
  "keys": {
    "example_personal_key": {
      "scope": "personal",
      "mode": "local_file",
      "item": "local-key",
      "path": "~/.ssh/keys/personal/id_ed25519_example",
      "public_key": "ssh-ed25519 AAAA-local example_personal_key"
    }
  },
  "hosts": {
    "example-malformed-host": {
      "scope": "personal",
      "user": "example",
      "key": "example_personal_key"
    }
  }
}
JSON
)
        ;;
      keyless-host)
        manifest_json=$(cat <<'JSON'
{
  "keys": {},
  "hosts": {
    "example-tailscale-host": {
      "scope": "personal",
      "host": "example-tailscale-host.example.ts.net",
      "user": "example",
      "port": 22,
      "options": {"IdentitiesOnly": "no", "ForwardAgent": "no", "UseKeychain": "yes"}
    }
  }
}
JSON
)
        ;;
      *)
        echo "unexpected manifest variant: ${BW_MANIFEST_VARIANT:-}" >&2
        exit 64
        ;;
    esac
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

run_refresh_variant() {
  local variant=$1
  local home_dir=$2
  local role=$3
  shift 3
  BW_MANIFEST_VARIANT="$variant" run_refresh "$home_dir" "$role" "$@"
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

rendered_refresh_cmd="$tmpdir/cz-ssh-refresh-rendered"
render_data="$tmpdir/render-data.json"
cat > "$render_data" <<'JSON'
{
  "personal": true,
  "work": false,
  "homelab": false,
  "ephemeral": false,
  "ssh": {
    "bw_manifest_item": "manifest'quoted",
    "bw_agent_sock_env": "BITWARDEN_SSH_AUTH_SOCK"
  }
}
JSON
chezmoi execute-template --override-data-file "$render_data" < "$refresh_cmd" > "$rendered_refresh_cmd"
chmod +x "$rendered_refresh_cmd"

rendered_linux_refresh_cmd="$tmpdir/cz-ssh-refresh-linux-rendered"
rendered_darwin_refresh_cmd="$tmpdir/cz-ssh-refresh-darwin-rendered"
render_data_linux="$tmpdir/render-data-linux.json"
render_data_darwin="$tmpdir/render-data-darwin.json"
cat > "$render_data_linux" <<'JSON'
{
  "chezmoi": {"os": "linux"},
  "personal": true,
  "work": false,
  "homelab": false,
  "ephemeral": false,
  "ssh": {
    "bw_manifest_item": "manifest",
    "bw_agent_sock_env": "BITWARDEN_SSH_AUTH_SOCK"
  }
}
JSON
cat > "$render_data_darwin" <<'JSON'
{
  "chezmoi": {"os": "darwin"},
  "personal": true,
  "work": false,
  "homelab": false,
  "ephemeral": false,
  "ssh": {
    "bw_manifest_item": "manifest",
    "bw_agent_sock_env": "BITWARDEN_SSH_AUTH_SOCK"
  }
}
JSON
chezmoi execute-template --override-data-file "$render_data_linux" < "$refresh_cmd" > "$rendered_linux_refresh_cmd"
chezmoi execute-template --override-data-file "$render_data_darwin" < "$refresh_cmd" > "$rendered_darwin_refresh_cmd"
chmod +x "$rendered_linux_refresh_cmd" "$rendered_darwin_refresh_cmd"

run_rendered_refresh() {
  local home_dir=$1
  local role=$2
  shift 2
  HOME="$home_dir" \
    PATH="$fake_bin:$PATH" \
    BW_LOG="$bw_log" \
    CHEZMOI_ROLE="$role" \
    BITWARDEN_SSH_AUTH_SOCK="$tmpdir/bw-agent.sock" \
    "$rendered_refresh_cmd" "$@"
}

run_specific_rendered_refresh() {
  local rendered_cmd=$1
  local home_dir=$2
  local role=$3
  shift 3
  HOME="$home_dir" \
    PATH="$fake_bin:$PATH" \
    BW_LOG="$bw_log" \
    CHEZMOI_ROLE="$role" \
    BITWARDEN_SSH_AUTH_SOCK="$tmpdir/bw-agent.sock" \
    "$rendered_cmd" "$@"
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

assert_not_contains() {
  local file=$1
  local unexpected=$2
  if grep -Fq -- "$unexpected" "$file"; then
    echo "expected $file not to contain: $unexpected" >&2
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

# Rendered templates shell-quote config values containing single quotes and show concise progress.
render_home=$(new_home rendered)
: > "$bw_log"
render_output=$(run_rendered_refresh "$render_home" personal 2>&1)
assert_contains "$bw_log" "get item manifest'quoted"
assert_contains "$render_home/.ssh/config.d/personal.conf" "Host example-personal-host"
assert_contains "$render_home/.ssh/keys/personal/id_ed25519_example" "fake-local-private-key"
if [[ "$render_output" != *"info: checking Bitwarden status"* ]]; then
  echo "expected progress output for Bitwarden status, got: $render_output" >&2
  exit 1
fi
if [[ "$render_output" != *"info: reading SSH Bitwarden manifest"* ]]; then
  echo "expected progress output for manifest read, got: $render_output" >&2
  exit 1
fi
if [[ "$render_output" != *"info: processing SSH hosts"* ]]; then
  echo "expected progress output for host processing, got: $render_output" >&2
  exit 1
fi
if [[ "$render_output" != *"info: writing SSH config"* ]]; then
  echo "expected progress output for config write, got: $render_output" >&2
  exit 1
fi
if [[ "$render_output" != *"info: SSH refresh complete: 1 hosts (1 local-file, 0 Bitwarden Agent, 0 keyless)"* ]]; then
  echo "expected progress summary, got: $render_output" >&2
  exit 1
fi

# Darwin-only SSH options are preserved only for Darwin renders.
linux_options_home=$(new_home linux-options)
run_specific_rendered_refresh "$rendered_linux_refresh_cmd" "$linux_options_home" personal
assert_contains "$linux_options_home/.ssh/config.d/personal.conf" "IdentitiesOnly yes"
assert_not_contains "$linux_options_home/.ssh/config.d/personal.conf" "UseKeychain"

darwin_options_home=$(new_home darwin-options)
run_specific_rendered_refresh "$rendered_darwin_refresh_cmd" "$darwin_options_home" personal
assert_contains "$darwin_options_home/.ssh/config.d/personal.conf" "IdentitiesOnly yes"
assert_contains "$darwin_options_home/.ssh/config.d/personal.conf" "UseKeychain yes"

# Locked Bitwarden skips before attempting item reads.
locked_home=$(new_home locked)
: > "$bw_log"
if ! locked_output=$(BW_MODE=locked run_refresh "$locked_home" personal 2>&1); then
  echo "expected locked Bitwarden to skip with exit 0" >&2
  echo "$locked_output" >&2
  exit 1
fi
if [[ "$locked_output" != *"warn: Bitwarden CLI is locked"* ]]; then
  echo "expected locked Bitwarden warning, got: $locked_output" >&2
  exit 1
fi
assert_contains "$bw_log" "status --raw"
assert_not_contains "$bw_log" "get item"
assert_not_exists "$locked_home/.ssh/config.d/personal.conf"

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

# Malformed required host fields warn and skip by default, and fail with --fail.
malformed_home=$(new_home malformed)
if ! malformed_output=$(BW_MANIFEST_VARIANT=missing-host run_refresh "$malformed_home" personal 2>&1); then
  echo "expected malformed manifest to skip with exit 0" >&2
  echo "$malformed_output" >&2
  exit 1
fi
if [[ "$malformed_output" != *"warn: host 'example-malformed-host' requires field 'host'"* ]]; then
  echo "expected malformed manifest warning, got: $malformed_output" >&2
  exit 1
fi
assert_not_exists "$malformed_home/.ssh/config.d/personal.conf"
if BW_MANIFEST_VARIANT=missing-host run_refresh "$malformed_home" personal --fail >/tmp/cz-ssh-refresh-malformed.out 2>&1; then
  echo "expected --fail with malformed manifest to exit non-zero" >&2
  cat /tmp/cz-ssh-refresh-malformed.out >&2
  exit 1
fi
assert_contains /tmp/cz-ssh-refresh-malformed.out "error: host 'example-malformed-host' requires field 'host'"

# Hosts without a key generate normal SSH config without identity directives or key fetches.
keyless_home=$(new_home keyless)
: > "$bw_log"
run_refresh_variant "keyless-host" "$keyless_home" personal
keyless_conf="$keyless_home/.ssh/config.d/personal.conf"
assert_contains "$keyless_conf" "Host example-tailscale-host"
assert_contains "$keyless_conf" "HostName example-tailscale-host.example.ts.net"
assert_contains "$keyless_conf" "User example"
assert_contains "$keyless_conf" "IdentitiesOnly no"
assert_contains "$keyless_conf" "ForwardAgent no"
assert_not_contains "$keyless_conf" "UseKeychain"
assert_not_contains "$keyless_conf" "IdentityFile"
assert_not_contains "$keyless_conf" "IdentityAgent"
if grep -q -- "local-key\|work-key" "$bw_log"; then
  echo "keyless host must not fetch SSH key items" >&2
  cat "$bw_log" >&2
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
assert_contains "$personal_conf" "IdentitiesOnly yes"
assert_not_contains "$personal_conf" "UseKeychain"
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

# Symlinked private-key path components under ~/.ssh are rejected before writing.
symlink_home=$(new_home symlink)
outside_keys="$tmpdir/outside-keys"
mkdir -p "$symlink_home/.ssh/keys" "$outside_keys"
ln -s "$outside_keys" "$symlink_home/.ssh/keys/escape"
: > "$bw_log"
if ! symlink_output=$(BW_MANIFEST_VARIANT=symlink-path run_refresh "$symlink_home" personal 2>&1); then
  echo "expected symlinked key path to skip with exit 0" >&2
  echo "$symlink_output" >&2
  exit 1
fi
if [[ "$symlink_output" != *"warn: refusing to write SSH key through symlinked path component"* ]]; then
  echo "expected symlink warning, got: $symlink_output" >&2
  exit 1
fi
assert_not_exists "$outside_keys/id_ed25519_escape"
if grep -q -- "local-key" "$bw_log"; then
  echo "symlinked key path must be rejected before private key item fetch" >&2
  cat "$bw_log" >&2
  exit 1
fi

# Symlinked bitwarden_agent public-key hint paths are rejected before writing.
public_symlink_home=$(new_home public-symlink)
outside_pub="$tmpdir/outside-public-key.pub"
mkdir -p "$public_symlink_home/.ssh/public-keys"
printf 'outside-original
' > "$outside_pub"
ln -s "$outside_pub" "$public_symlink_home/.ssh/public-keys/example_work_key.pub"
: > "$bw_log"
if ! public_symlink_output=$(run_refresh "$public_symlink_home" work 2>&1); then
  echo "expected symlinked public key hint path to skip with exit 0" >&2
  echo "$public_symlink_output" >&2
  exit 1
fi
if [[ "$public_symlink_output" != *"warn: refusing to write SSH key through symlinked path component"* ]]; then
  echo "expected public-key symlink warning, got: $public_symlink_output" >&2
  exit 1
fi
assert_contains "$outside_pub" "outside-original"
if grep -q -- "ssh-ed25519 AAAA-work" "$outside_pub"; then
  echo "public key hint write escaped ~/.ssh through a symlink" >&2
  exit 1
fi
if grep -q -- "work-key" "$bw_log"; then
  echo "bitwarden_agent public hint path should be rejected without fetching private key item" >&2
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
