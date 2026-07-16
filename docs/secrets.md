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

## bitwarden cache refresh

after changing bitwarden-backed init data, re-run `chezmoi init --apply brendanlees`; `chezmoi apply` alone does not refresh cached init data.

## token rotation

rotate tokens periodically and after any exposure. after rotating a cached token, re-run `chezmoi init --apply brendanlees`.
