# secrets

## github token

mise fetches tools from github releases. without auth, github rate limits can break first-run installs; a zero-permission fine-grained token raises the bootstrap limit.

- ansible hosts receive the vault-encrypted token during init/update.
- interactive hosts can pass `GITHUB_TOKEN=ghp_xxx chezmoi init --apply brendanlees`.
- bitwarden-backed hosts can unlock before init/apply:

```sh
export BW_SESSION=$(bw unlock --raw)
chezmoi init --apply brendanlees
```

### mise authentication

On hosts with a cached `github_token`, the managed mise configuration resolves it on demand through chezmoi's `credential_command`. The token is not exported globally or embedded in mise configuration.

Verify the active source with:

```sh
mise token github
```

The token is masked by default; the output should identify `credential_command` as its source.

## home assistant mcp endpoint

On personal hosts, `chezmoi init` reads the `secret_path` custom field from the dedicated Bitwarden item and caches it as chezmoi data. Rendering is one-way: `chezmoi apply` reads that cache to manage `~/.config/mcp/mcp.json`; it neither writes to Bitwarden nor refreshes the cached field.

The managed directory is mode `0700`, and `mcp.json` is mode `0600`. Non-personal hosts and personal hosts without the cached field do not manage `.config/mcp`.

To rotate the endpoint, update the Bitwarden field, unlock Bitwarden, and re-run `chezmoi init --apply brendanlees`. Running `chezmoi apply` alone continues using the previously cached value.

## bitwarden cache refresh

after changing bitwarden-backed init data, re-run `chezmoi init --apply brendanlees`; `chezmoi apply` alone does not refresh cached init data.

## token rotation

rotate tokens periodically and after any exposure. after rotating a cached token, re-run `chezmoi init --apply brendanlees`.
