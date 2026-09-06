# secrets

## adding a github token (for mise authentication)

mise fetches tools from github releases. without auth, github rate limits can break first-run installs; a zero-permission fine-grained token raises the bootstrap limit.

- interactive hosts can pass `GITHUB_TOKEN=ghp_xxx chezmoi init --apply brendanlees`.
- bitwarden-backed hosts can unlock before init/apply:
- if also using ansible homelab playbook, hosts receive the vault-encrypted token during init/update.

```sh
export BW_SESSION=$(bw unlock --raw)
chezmoi init --apply brendanlees
```

On hosts with a cached `github_token`, mise config resolves it on demand through chezmoi's `credential_command`. The install hook also supplies it to the current process before the first download; an injected `GITHUB_TOKEN` takes precedence. Windows no longer copies it into the persistent User environment.

If an older Windows apply saved the token there, remove that old export once from PowerShell:

```powershell
[Environment]::SetEnvironmentVariable('GITHUB_TOKEN', $null, 'User')
```

New shells will use mise's credential command. The cached value still lives in the private chezmoi config, not in this repository.

Verify the active source with:

```sh
mise token github
```

The token is masked by default; output should identify `credential_command` as its source.

## bitwarden cache refresh

after changing bitwarden-backed init data, re-run `chezmoi init --apply brendanlees`; `chezmoi apply` alone does not refresh cached init data.
