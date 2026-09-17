# secrets

## GitHub authentication

Use a low-privilege GitHub token for public release downloads. A fine-grained token with no repository permissions is sufficient to raise the API rate limit.

Provide it **before the first init**:

```sh
GITHUB_TOKEN=your-token chezmoi init --apply brendanlees
```

Alternatively, install and sign in to the Bitwarden CLI before init, then unlock it:

```sh
export BW_SESSION=$(bw unlock --raw)
chezmoi init --apply brendanlees
```

Installing Bitwarden in an apply hook is too late for that init's secret lookup. Without either source, authenticated downloads cannot be guaranteed. Ansible-managed hosts can supply their vault-encrypted token during init/update.

Init caches the token in the private chezmoi config. An injected `GITHUB_TOKEN` takes precedence over Bitwarden; re-init without either preserves an existing cached token. Never commit the generated config or paste its contents into logs.

### First apply and subsequent commands

The tool-install hook exports the cached token before its first `mise install`, unless `GITHUB_TOKEN` is already supplied. It runs before the other after-hooks, from the home directory, without needing an interactive shell. A failed install stops apply rather than recording success. Mise also resolves the cache on demand through its `github.credential_command` setting.

Zsh and PowerShell resolve the token after mise activation and export `GITHUB_TOKEN` for commands outside mise. Their precedence is:

1. Existing `GITHUB_TOKEN`.
2. Existing `GITHUB_PERSONAL_ACCESS_TOKEN`.
3. Cached chezmoi `github_token`.
4. `gh auth token`, if available.

Set `GH_TOKEN_AUTOEXPORT=0` before shell startup for accessor-only use, then pass `GITHUB_TOKEN=$(gh-token)` to individual POSIX commands. Automatic export makes the token available to child processes; it does not copy it into shell configuration or Windows' persistent User environment. Open a new shell after applying these profile changes. Mise-specific token environment overrides still follow mise's own precedence.

Check mise's active source without printing the token:

```sh
mise token github
```

The token is masked by default. This checks token selection, not whether GitHub accepts it.

If an older Windows apply saved the token persistently, remove that old export once from PowerShell:

```powershell
[Environment]::SetEnvironmentVariable('GITHUB_TOKEN', $null, 'User')
```

### Spicetify

The upstream CLI update checker makes unauthenticated GitHub requests and does not read `GITHUB_TOKEN`. The managed config disables that checker; Homebrew owns Spicetify updates. Exporting a token alone cannot fix rate limits from that checker.

## bitwarden cache refresh

After changing Bitwarden-backed init data, re-run `chezmoi init --apply brendanlees`; `chezmoi apply` alone does not refresh cached init data. Unset an old exported `GITHUB_TOKEN` first if Bitwarden should supply its replacement.
