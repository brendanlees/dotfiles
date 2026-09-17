# ssh

## private agent skills remote

On personal macOS and Windows hosts, the private-skills prompt expects a Git SSH clone URL, for example:

```text
git@github.com:OWNER/REPO.git
ssh://git@git.example.com:2222/OWNER/REPO.git
```

For GitHub the SSH user is always `git`, not your GitHub username. `github.com:OWNER/REPO.git` is missing the user and is rejected. Use the SSH user and port advertised by a self-hosted Git service. SSH keys/agent access are separate from the GitHub API token.

The values are cached in chezmoi's config under `[data.private_agent_skills]` as `remote` and `checkout`. The checkout must be an absolute path outside the public dotfiles repository; do not enter a literal `~`. Existing nonempty cached values are reused on init, so use `chezmoi edit-config` to correct them rather than expecting another prompt. Check host-local data overrides as well if an old value keeps winning.

For an existing checkout, its `git remote get-url origin` must exactly match the configured URL, including SSH syntax and the `.git` suffix. The helper does not rewrite remotes, pull, reset or delete your checkout. Verify any mismatch before manually correcting the URL, then run `cz-private-agent-skills --fail reconcile` for a visible error instead of the normal non-blocking warning.

## host configuration

these maintain a generic ssh config scaffold, while private hostnames, aliases, keys, and other bitwarden item ids live in a private manifest referenced by local chezmoi config.

## setup

1. install `bw` (and `jq` for posix refreshes; windows uses powershell json parsing).
2. sign in and unlock bitwarden: `export BW_SESSION=$(bw unlock --raw)` on posix, or `$env:BW_SESSION = bw unlock --raw` in powershell.
3. create a bitwarden secure and add manifest json to the notes field.
4. re-run `chezmoi init --apply brendanlees` on an enabled machine and set `ssh_bw_manifest_item` to that item name or id.
5. run `chezmoi apply`, or refresh manually with helper alias `cz-ssh-refresh`.

leave `ssh_bw_manifest_item` blank to skip ssh generation.

## manifest shape

```json
{
  "keys": {
    "personal_key": {
      "scope": "personal",
      "mode": "local_file",
      "item": "bitwarden-key-item",
      "path": "~/.ssh/keys/personal/id_ed25519_example",
      "public_key": "ssh-ed25519 AAAA... personal_key"
    },
    "work_agent_key": {
      "scope": "work",
      "mode": "bitwarden_agent",
      "item": "bitwarden-agent-key-item",
      "public_key": "ssh-ed25519 AAAA... work_agent_key"
    }
  },
  "hosts": {
    "example-host": {
      "scope": "personal",
      "host": "example.invalid",
      "user": "me",
      "port": 22,
      "key": "personal_key",
      "options": { "IdentitiesOnly": "yes" }
    },
    "tailscale-host": {
      "scope": "personal",
      "host": "tailscale-name.example.ts.net",
      "user": "me"
    }
  }
}
```

hosts may omit `key` when openssh defaults, tailscale ssh, or dns should decide identity.

## key modes

- `local_file`: fetches the bitwarden ssh key item, writes the private key to `path` with `0600`, writes a sibling `.pub` hint when available, and emits scoped config under `~/.ssh/config.d/`.
- `bitwarden_agent`: never writes private key material. it writes a public-key hint under `~/.ssh/public-keys/` and emits config for bitwarden ssh agent.

to migrate to `bitwarden_agent`, import the key into bitwarden, change the manifest mode, keep `public_key`, then remove any old local private key manually.

## refresh behavior

`cz-ssh-refresh` is non-blocking during `chezmoi apply`: missing bitwarden, missing `jq` on posix, lock state, or manifest config prints `warn:` and exits 0. use `cz-ssh-refresh --fail` when refresh errors should be fatal. On windows the managed helper is `~/.local/bin/cz-ssh-refresh.ps1`; the powershell profile prepends `~/.local/bin` to `PATH`, so a new shell can run `cz-ssh-refresh` directly.

if bitwarden is locked, run:

```sh
export BW_SESSION=$(bw unlock --raw)
cz-ssh-refresh
```

if in powershell:

```powershell
$env:BW_SESSION = bw unlock --raw
cz-ssh-refresh
```
