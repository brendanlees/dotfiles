# usage

## updating

pull the latest dotfiles and re-apply:

```sh
chezmoi update
```

or manually:

```sh
chezmoi git pull && chezmoi apply
```

## re-installing on a new machine

**macos:**

```sh
brew install chezmoi
chezmoi init --apply brendanlees
```

**linux:**

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply brendanlees
```

**windows:**

```pwsh
winget install -e --id twpayne.chezmoi --accept-source-agreements --accept-package-agreements
chezmoi init --apply brendanlees
```

on first run, chezmoi will prompt you to configure the machine type.

certain scopes inherit secrets and require bitwarden to be installed and logged in prior to init (see [scoping](./scoping.md) for more detail).

## github token (rate-limit bypass)

mise pulls tools from github releases. without auth, you're limited to 60 req/hr which fails during init. a zero-permission fine-grained PAT bumps this to 5,000 req/hr.

### automatic (ansible)

ansible passes the vault-encrypted token during `chezmoi init` and `chezmoi update` — no action needed.

### populating secrets (via bitwarden)

prerequisites:

- bw installed and on PATH **before** running `chezmoi init`
- bw signed in once: `bw login`.

first-time setup:

- requires export of bw unlock to prevent continous password prompting for each secret token

```sh
export BW_SESSION=$(bw unlock --raw)
chezmoi init --apply brendanlees
```

once dotfile environment is configured, the same command is stored a helper for future use

```sh
cz-bw-init       # zsh helper: bw unlock --raw → BW_SESSION → chezmoi init
```

to refresh after rotating any cached field: re-run `cz-bw-init` (or the manual equivalent).

secrets use the namespace `.bw_$name`, using the item id and are stored within relevant scope guards.

each `[data.bw_*]` table is populated by ranging over the items custom fields in `.chezmoi.toml.tmpl`.

adding a new custom field in bw only requires referencing it as `{{ .bw_<group>.<field_name> }}` in the template — no schema enumeration needed on the chezmoi side.

after editing a value in Bitwarden, re-run `chezmoi init` to refresh the cache. `chezmoi apply` alone won't see the change.

### manual bootstrap

pass the token as an env var:

```sh
GITHUB_TOKEN=ghp_xxx chezmoi init --apply brendanlees
```

### in-shell access (personal hosts)

`GITHUB_TOKEN` is no longer eager-exported into every shell — it's pulled lazily from `gh auth` when needed:

```sh
GITHUB_TOKEN=$(gh-token) some-tool
```

if a tool requires `GITHUB_TOKEN` to be present unconditionally, opt in to the old behavior by setting `GH_TOKEN_AUTOEXPORT=1` before zsh sources its config (e.g. in `~/.zshenv` or a launchd `EnvironmentVariables` entry).

if `chezmoi apply` fails while mise is fetching GitHub-backed tools/plugins, refresh the cached Bitwarden token with `chezmoi init --apply brendanlees` and, if needed, update the local mise binary with `mise self-update` first.

### rotating the token

1. create a new fine-grained PAT (zero permissions) on github
2. update `vault_github_token` in ansible vault
3. run ansible update playbook to propagate to all machines

## ssh config and keys via bitwarden

This repo manages only generic SSH plumbing. Private host aliases, hostnames,
addresses, private keys, and real Bitwarden item IDs live outside the public repo:
local chezmoi config stores the manifest item name/id, and the Bitwarden secure
note stores the manifest JSON in its `.notes` field.

Setup flow:

1. Install `bw` and `jq`, then sign in/unlock Bitwarden.
2. Create a private Bitwarden secure note for the SSH manifest.
3. Re-run `chezmoi init` on personal/work machines and enter the manifest item
   name or id at the `ssh_bw_manifest_item` prompt. Leave it blank to skip.
4. Run `chezmoi apply`; on personal/work machines the non-blocking hook runs
   `cz-ssh-refresh` after apply. You can also run `cz-ssh-refresh` manually.
   Homelab use currently requires setting `ssh_bw_manifest_item` explicitly and
   running a manual refresh, or a future hook expansion.

Minimal manifest shape:

```json
{
  "keys": {
    "example_personal_key": {
      "scope": "personal",
      "mode": "local_file",
      "item": "example-local-key-item",
      "path": "~/.ssh/keys/personal/id_ed25519_example",
      "public_key": "ssh-ed25519 AAAA-example example_personal_key"
    },
    "example_work_key": {
      "scope": "work",
      "mode": "bitwarden_agent",
      "item": "example-work-key-item",
      "public_key": "ssh-ed25519 AAAA-example example_work_key"
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
    },
    "example-tailscale-host": {
      "scope": "personal",
      "host": "example-tailscale-host.example.ts.net",
      "user": "example",
      "options": {"IdentitiesOnly": "no"}
    }
  }
}
```

Hosts may omit `key` for Tailscale SSH/DNS or other entries that should use
OpenSSH defaults instead of a managed identity. Keyless hosts still get
`HostName`, `User`, `Port`, and `options`, but no `IdentityFile` or
`IdentityAgent` lines are generated.

Supported key modes:

- `local_file`: `cz-ssh-refresh` fetches the referenced Bitwarden SSH key item,
  writes the private key to the manifest `path` with mode `0600`, writes a
  sibling `.pub` hint when a public key is available, and generates scoped SSH
  config in `~/.ssh/config.d/<scope>.conf`.
- `bitwarden_agent`: `cz-ssh-refresh` never fetches or writes private key
  material. It writes only `~/.ssh/public-keys/<key>.pub` from manifest
  `public_key` and emits SSH config with `IdentityAgent` plus that public-key
  hint file. The generated shell environment exports `BITWARDEN_SSH_AUTH_SOCK`
  with a default of `$HOME/.bitwarden-ssh-agent.sock`, matching Bitwarden's
  macOS app socket, and does not override `SSH_AUTH_SOCK`.

`bitwarden_agent` is not work-only: the key mode itself is independent of
scope. Use it for any enabled manifest scope when the host entry and referenced
key have matching scope and that machine should use Bitwarden SSH Agent for the
key. The automatic init/apply flow documented above is currently wired for
personal/work machines; homelab entries need explicit manifest configuration and
manual `cz-ssh-refresh` until hook coverage expands.

To migrate a key from local files to Bitwarden SSH Agent, import the key into
Bitwarden, change the manifest key entry from `local_file` to
`bitwarden_agent`, keep `public_key`, and remove `path` after you have manually
removed any old local private key. If `path` remains and the old file still
exists, refresh warns but does not delete it.

Refresh is intentionally non-blocking: if Bitwarden, `jq`, or the manifest
setting is unavailable, `cz-ssh-refresh` prints `warn:` and exits 0 so
`chezmoi apply` can continue. The helper checks `bw status --raw` before item
reads; if the CLI is locked, run `export BW_SESSION=$(bw unlock --raw)` and
retry. Use `cz-ssh-refresh --fail` in explicit checks or CI-like validation when
missing dependencies or Bitwarden errors should be fatal.

Manual refresh prints concise progress to stderr so slow Bitwarden reads are
visible without exposing host aliases or item IDs:

```text
info: checking Bitwarden status
info: reading SSH Bitwarden manifest
info: processing SSH hosts
info: writing SSH config
info: SSH refresh complete: 21 hosts (7 local-file, 11 Bitwarden Agent, 3 keyless)
```
