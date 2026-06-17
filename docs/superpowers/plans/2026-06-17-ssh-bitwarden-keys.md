# SSH Bitwarden Keys Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a safe, generic chezmoi-managed SSH setup that generates local SSH config/key files from a private Bitwarden manifest, with easy migration from local private-key files to Bitwarden SSH Agent for work keys.

**Architecture:** The public repo manages only generic SSH plumbing and scripts. Private host data, host aliases, key references, and Bitwarden item IDs stay in local chezmoi config and Bitwarden. A `cz-ssh-refresh` helper reads a JSON manifest from Bitwarden, generates scoped `~/.ssh/config.d/*.conf` files, writes local private keys only for `local_file` mode, and writes no private key material for `bitwarden_agent` mode.

**Tech Stack:** chezmoi source-state files, Bash, Bitwarden CLI (`bw`), `jq`, OpenSSH config, shell tests with fake `bw`.

---

## File Structure

- Create: `private_dot_ssh/config.tmpl` — generic `~/.ssh/config` with `Include ~/.ssh/config.d/*.conf` and safe defaults.
- Create: `private_dot_ssh/config.d/.keep`, `private_dot_ssh/keys/.keep`, `private_dot_ssh/public-keys/.keep` — ensure private generated directories exist.
- Modify: `.chezmoi.toml.tmpl` — prompt/cache local-only SSH manifest settings without committing Bitwarden item IDs.
- Create: `dot_local/bin/executable_cz-ssh-refresh.tmpl` — fetch Bitwarden manifest and generate local SSH config/key files.
- Create: `.chezmoiscripts/run_onchange_after_refresh-ssh-keys.sh.tmpl` — non-blocking refresh hook.
- Create: `tests/chezmoi/test-ssh-bitwarden-refresh.sh` — fake `bw` tests for skip behavior, `local_file`, `bitwarden_agent`, scope filtering, and stale-key warning.
- Modify: `docs/usage.md`, `docs/scoping.md`, `README.md` — document usage and role behavior.

## Manifest Contract

Use JSON in the Bitwarden secure note body (`.notes`) to avoid adding a YAML parser dependency.

```json
{
  "keys": {
    "homelab_admin": {
      "scope": "personal",
      "mode": "local_file",
      "item": "bw-key-local",
      "path": "~/.ssh/keys/personal/id_ed25519_homelab",
      "public_key": "ssh-ed25519 AAAA-local homelab_admin"
    },
    "work_main": {
      "scope": "work",
      "mode": "bitwarden_agent",
      "item": "bw-key-work",
      "public_key": "ssh-ed25519 AAAA-work work_main"
    }
  },
  "hosts": {
    "pve1": {
      "scope": "personal",
      "host": "10.0.0.10",
      "user": "root",
      "port": 22,
      "key": "homelab_admin",
      "options": { "IdentitiesOnly": "yes" }
    },
    "work-bastion": {
      "scope": "work",
      "host": "work.example.internal",
      "user": "brendan",
      "key": "work_main",
      "options": { "IdentitiesOnly": "yes" }
    }
  }
}
```

## Task 1: Add generic SSH directories and base config

**Files:**
- Create: `private_dot_ssh/config.tmpl`
- Create: `private_dot_ssh/config.d/.keep`
- Create: `private_dot_ssh/keys/.keep`
- Create: `private_dot_ssh/public-keys/.keep`

- [ ] **Step 1: Create `private_dot_ssh/config.tmpl`**

```sshconfig
# Managed by chezmoi.
# Private host entries are generated locally by cz-ssh-refresh into ~/.ssh/config.d/.

Include ~/.ssh/config.d/*.conf

Host *
  AddKeysToAgent yes
  HashKnownHosts yes
  ServerAliveInterval 60
  ServerAliveCountMax 3
```

- [ ] **Step 2: Create keep files**

```bash
mkdir -p private_dot_ssh/config.d private_dot_ssh/keys private_dot_ssh/public-keys
: > private_dot_ssh/config.d/.keep
: > private_dot_ssh/keys/.keep
: > private_dot_ssh/public-keys/.keep
```

- [ ] **Step 3: Render-check**

```bash
CHEZMOI_ROLE=ephemeral,headless chezmoi execute-template < private_dot_ssh/config.tmpl
```

Expected: output contains `Include ~/.ssh/config.d/*.conf` and no template errors.

- [ ] **Step 4: Commit**

```bash
git add private_dot_ssh
git commit -m "feat(ssh): add generic ssh config scaffold"
```

## Task 2: Add local-only SSH manifest settings to chezmoi data

**Files:**
- Modify: `.chezmoi.toml.tmpl`
- Test: `tests/chezmoi/test-bitwarden-role-gating.sh`

- [ ] **Step 1: Add local prompt variables after the existing `git_email` block**

```gotemplate
# --- optional ssh/bitwarden manifest settings ---
{{- $ssh_bw_manifest_item := "" -}}
{{- $ssh_bw_agent_sock_env := "BITWARDEN_SSH_AUTH_SOCK" -}}
{{- if and (or $personal $work) (not $ephemeral) -}}
{{-   if .ssh_bw_manifest_item -}}
{{-     $ssh_bw_manifest_item = .ssh_bw_manifest_item -}}
{{-   else if stdinIsATTY -}}
{{-     $ssh_bw_manifest_item = promptStringOnce . "ssh_bw_manifest_item" "Bitwarden SSH manifest item id/name (blank to skip)" -}}
{{-   end -}}
{{-   if .ssh_bw_agent_sock_env -}}
{{-     $ssh_bw_agent_sock_env = .ssh_bw_agent_sock_env -}}
{{-   end -}}
{{- end -}}
```

- [ ] **Step 2: Add this under role flags in `[data]`**

```toml
[data.ssh]
  bw_manifest_item = {{ $ssh_bw_manifest_item | quote }}
  bw_agent_sock_env = {{ $ssh_bw_agent_sock_env | quote }}
```

- [ ] **Step 3: Verify existing Bitwarden role gating**

```bash
bash tests/chezmoi/test-bitwarden-role-gating.sh
```

Expected: `bitwarden role gating ok`.

- [ ] **Step 4: Commit**

```bash
git add .chezmoi.toml.tmpl
git commit -m "feat(chezmoi): cache local ssh manifest settings"
```

## Task 3: Write failing refresh-helper tests

**Files:**
- Create: `tests/chezmoi/test-ssh-bitwarden-refresh.sh`

- [ ] **Step 1: Create test file with fake `bw` and assertions**

The test must:

1. create an isolated `$HOME` and fake `bw` on `$PATH`;
2. fake `bw get item manifest` returning a JSON item whose `.notes` is the manifest JSON;
3. fake `bw get item local-key` returning `.sshKey.privateKey` and `.sshKey.publicKey`;
4. fake `bw get item work-key` returning private material that must never be written for `bitwarden_agent` mode;
5. run `dot_local/bin/executable_cz-ssh-refresh.tmpl` directly with:

```bash
HOME="$fake_home" \
PATH="$repo_root/dot_local/bin:$fake_bin:$PATH" \
BW_LOG="$bw_log" \
SSH_BW_MANIFEST_ITEM="manifest" \
CHEZMOI_ROLE="$role" \
BITWARDEN_SSH_AUTH_SOCK="$tmpdir/bw-agent.sock" \
"$repo_root/dot_local/bin/executable_cz-ssh-refresh.tmpl"
```

- [ ] **Step 2: Assert skip-with-warning behavior**

Set `BW_MODE=missing-session`, run refresh, and require warning output containing `warn:` with exit 0.

- [ ] **Step 3: Assert `local_file` behavior**

Run with `CHEZMOI_ROLE=personal` and assert:

```text
~/.ssh/config.d/personal.conf contains Host pve1
~/.ssh/config.d/personal.conf contains HostName 10.0.0.10
~/.ssh/config.d/personal.conf contains IdentityFile ~/.ssh/keys/personal/id_ed25519_homelab
~/.ssh/keys/personal/id_ed25519_homelab contains fake-local-private-key
~/.ssh/keys/personal/id_ed25519_homelab mode is 600
```

- [ ] **Step 4: Assert `bitwarden_agent` behavior**

Run with `CHEZMOI_ROLE=work` and assert:

```text
~/.ssh/config.d/work.conf contains Host work-bastion
~/.ssh/config.d/work.conf contains IdentityAgent $BITWARDEN_SSH_AUTH_SOCK
~/.ssh/config.d/work.conf contains IdentityFile ~/.ssh/public-keys/work_main.pub
~/.ssh/public-keys/work_main.pub contains ssh-ed25519 AAAA-work work_main
no work private key file is written
work private key fixture text should-not-be-written appears nowhere under ~/.ssh
```

- [ ] **Step 5: Assert stale local private key warning**

Create `~/.ssh/keys/work/id_ed25519_work`, run work refresh where manifest has `mode: bitwarden_agent` and a legacy `path`, then assert stderr contains `local private key still exists`.

- [ ] **Step 6: Verify red test**

```bash
bash tests/chezmoi/test-ssh-bitwarden-refresh.sh
```

Expected: FAIL because `dot_local/bin/executable_cz-ssh-refresh.tmpl` does not exist yet.

- [ ] **Step 7: Commit the failing test**

```bash
git add tests/chezmoi/test-ssh-bitwarden-refresh.sh
git commit -m "test(ssh): cover bitwarden ssh refresh modes"
```

## Task 4: Implement `cz-ssh-refresh`

**Files:**
- Create: `dot_local/bin/executable_cz-ssh-refresh.tmpl`
- Test: `tests/chezmoi/test-ssh-bitwarden-refresh.sh`

- [ ] **Step 1: Implement helper behavior**

`dot_local/bin/executable_cz-ssh-refresh.tmpl` must:

1. parse optional `--fail` and default to skip-with-warning;
2. require `bw` and `jq`, warning/skipping if absent;
3. get the manifest item from `SSH_BW_MANIFEST_ITEM` or `{{ .ssh.bw_manifest_item | default "" }}`;
4. read manifest JSON from `.notes`;
5. validate `.keys` and `.hosts` are objects;
6. create `~/.ssh`, `~/.ssh/config.d`, `~/.ssh/keys`, `~/.ssh/public-keys` with `0700` where possible;
7. render only host entries whose `scope` is enabled by `CHEZMOI_ROLE` or chezmoi data flags;
8. for `local_file`, fetch key item, read `.sshKey.privateKey`, write to manifest `path` with `0600`, write `.pub` with `0644`, and emit `IdentityFile <path>`;
9. for `bitwarden_agent`, never fetch/write private key material, write `~/.ssh/public-keys/<key>.pub`, emit `IdentityAgent $<agent-env>` and `IdentityFile ~/.ssh/public-keys/<key>.pub`;
10. reject unknown modes with warning/skip by default and hard error under `--fail`;
11. warn, but do not delete, if `bitwarden_agent` entry has a `path` and that local private key still exists.

Implementation skeleton:

```bash
#!/usr/bin/env bash
set -euo pipefail

FAIL_HARD=false
case "${1:-}" in
  --fail) FAIL_HARD=true ;;
  -h|--help) echo "Usage: cz-ssh-refresh [--fail]"; exit 0 ;;
esac

warn() { echo "warn: $*" >&2; }
die_or_skip() {
  if [[ "$FAIL_HARD" == true ]]; then echo "error: $*" >&2; exit 1; fi
  warn "$*"; exit 0
}
```

- [ ] **Step 2: Run tests**

```bash
bash tests/chezmoi/test-ssh-bitwarden-refresh.sh
```

Expected: `ssh bitwarden refresh ok`.

- [ ] **Step 3: Shellcheck**

```bash
shellcheck dot_local/bin/executable_cz-ssh-refresh.tmpl tests/chezmoi/test-ssh-bitwarden-refresh.sh
```

Expected: no output and exit 0.

- [ ] **Step 4: Commit**

```bash
git add dot_local/bin/executable_cz-ssh-refresh.tmpl tests/chezmoi/test-ssh-bitwarden-refresh.sh
git commit -m "feat(ssh): generate ssh config from bitwarden manifest"
```

## Task 5: Add non-blocking chezmoi refresh hook

**Files:**
- Create: `.chezmoiscripts/run_onchange_after_refresh-ssh-keys.sh.tmpl`

- [ ] **Step 1: Create hook**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Re-run when the refresh helper or local manifest setting changes.
# helper-sha256: {{ include "dot_local/bin/executable_cz-ssh-refresh.tmpl" | sha256sum }}
# manifest-item: {{ .ssh.bw_manifest_item | default "" | sha256sum }}

if [[ "{{ .ephemeral }}" == "true" || "{{ or .personal .work }}" != "true" ]]; then
  exit 0
fi

if ! command -v cz-ssh-refresh >/dev/null 2>&1; then
  echo "warn: cz-ssh-refresh is not on PATH; skipping SSH refresh" >&2
  exit 0
fi

cz-ssh-refresh || echo "warn: SSH refresh failed; continuing chezmoi apply" >&2
```

- [ ] **Step 2: Render and shellcheck**

```bash
CHEZMOI_ROLE=ephemeral,headless chezmoi execute-template < .chezmoiscripts/run_onchange_after_refresh-ssh-keys.sh.tmpl
CHEZMOI_ROLE=personal chezmoi execute-template < .chezmoiscripts/run_onchange_after_refresh-ssh-keys.sh.tmpl | shellcheck -
```

Expected: no template errors and no shellcheck diagnostics.

- [ ] **Step 3: Commit**

```bash
git add .chezmoiscripts/run_onchange_after_refresh-ssh-keys.sh.tmpl
git commit -m "feat(ssh): refresh ssh material after chezmoi apply"
```

## Task 6: Document setup and migration flow

**Files:**
- Modify: `docs/usage.md`
- Modify: `docs/scoping.md`
- Modify: `README.md`

- [ ] **Step 1: Add `docs/usage.md` section `## ssh config and keys via bitwarden`**

Document repo/private boundaries, setup flow, `local_file`, `bitwarden_agent`, manifest-only migration, skip-with-warning default, and `cz-ssh-refresh --fail`.

- [ ] **Step 2: Add scoping note to `docs/scoping.md`**

```markdown
SSH manifest generation also follows role flags. Hosts and keys with `scope: personal`
are generated only for personal machines, and `scope: work` entries are generated only
for work machines. Ephemeral/headless CI roles skip SSH refresh.
```

- [ ] **Step 3: Add README docs link**

```markdown
- [ssh + bitwarden](docs/usage.md#ssh-config-and-keys-via-bitwarden) — local SSH config/key generation from a private Bitwarden manifest
```

- [ ] **Step 4: Commit**

```bash
git add docs/usage.md docs/scoping.md README.md
git commit -m "docs: explain bitwarden ssh refresh flow"
```

## Task 7: Full verification

- [ ] **Step 1: Focused tests**

```bash
bash tests/chezmoi/test-bitwarden-role-gating.sh
bash tests/chezmoi/test-ssh-bitwarden-refresh.sh
```

Expected:

```text
bitwarden role gating ok
ssh bitwarden refresh ok
```

- [ ] **Step 2: Shellcheck**

```bash
shellcheck \
  dot_local/bin/executable_cz-ssh-refresh.tmpl \
  tests/chezmoi/test-ssh-bitwarden-refresh.sh \
  .chezmoiscripts/run_onchange_after_refresh-ssh-keys.sh.tmpl
```

Expected: no output and exit 0.

- [ ] **Step 3: Render templates for CI role**

```bash
CHEZMOI_ROLE=ephemeral,headless chezmoi execute-template < private_dot_ssh/config.tmpl
CHEZMOI_ROLE=ephemeral,headless chezmoi execute-template < .chezmoiscripts/run_onchange_after_refresh-ssh-keys.sh.tmpl
```

Expected: no template errors.

- [ ] **Step 4: Static analysis if available**

```bash
if command -v fallow >/dev/null 2>&1; then
  fallow audit --changed-since main
else
  echo "warn: fallow not installed; skipped"
fi
```

Expected: audit passes or explicit skip.

- [ ] **Step 5: Secret-leak review**

```bash
git diff main...HEAD -- . ':!docs/superpowers/plans/*' | grep -Ei 'BEGIN OPENSSH PRIVATE KEY|real-host|real-ip|real-bitwarden-item' && exit 1 || true
```

Expected: no private key material, real hostnames/IPs, or real Bitwarden item IDs in implementation files.

## Self-Review

- Spec coverage: plan covers generic repo files, local-only manifest reference, non-blocking Bitwarden behavior, `local_file`, `bitwarden_agent`, stale-key warnings, docs, and tests.
- Placeholder scan: no `TBD`/`TODO` placeholders remain. Example hostnames and item IDs are fake examples only.
- Type/name consistency: plan consistently uses `local_file`, `bitwarden_agent`, `SSH_BW_MANIFEST_ITEM`, `BITWARDEN_SSH_AUTH_SOCK`, `cz-ssh-refresh`, and `bw_manifest_item`.
