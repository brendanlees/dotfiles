# ssh

this repo keeps only generic ssh plumbing. private hostnames, aliases, keys, and bitwarden item ids live in a private bitwarden manifest referenced by local chezmoi config.

## setup

1. install `bw` and `jq`.
2. sign in and unlock bitwarden: `export BW_SESSION=$(bw unlock --raw)`.
3. create a bitwarden secure note whose notes field contains the manifest json.
4. re-run `chezmoi init --apply brendanlees` on an enabled machine and set `ssh_bw_manifest_item` to that item name or id.
5. run `chezmoi apply`, or refresh manually with `cz-ssh-refresh`.

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

`cz-ssh-refresh` is non-blocking during `chezmoi apply`: missing bitwarden, `jq`, lock state, or manifest config prints `warn:` and exits 0. use `cz-ssh-refresh --fail` when refresh errors should be fatal.

if bitwarden is locked, run:

```sh
export BW_SESSION=$(bw unlock --raw)
cz-ssh-refresh
```
