# secrets

## GitHub authentication

Keep dependency downloads separate from repository work. A low-privilege download token can authenticate successfully without having permission to create a PR.

### Download token provisioning

Use a low-privilege GitHub token for public release downloads. A fine-grained token with no repository permissions is sufficient to raise the API rate limit.

Provide it **before the first init** through the dedicated input:

```sh
GITHUB_DOWNLOAD_TOKEN=your-download-token chezmoi init --apply brendanlees
```

Alternatively, on personal machines, install and sign in to the Bitwarden CLI before init, then unlock it:

```sh
export BW_SESSION=$(bw unlock --raw)
chezmoi init --apply brendanlees
```

Init uses `GITHUB_DOWNLOAD_TOKEN`, then Bitwarden's `read_only_token` when available, then the existing private `github_token` cache. It never takes a download credential from `GH_TOKEN`, `GITHUB_TOKEN`, or `GITHUB_PERSONAL_ACCESS_TOKEN`. Existing caches remain compatible; if one previously captured a repository token, explicitly replace it through the dedicated input or Bitwarden.

Installing Bitwarden in an apply hook is too late for that init's secret lookup. Without a supplied or cached token, authenticated downloads cannot be guaranteed. Ansible-managed hosts must inject their vault-encrypted download token as `GITHUB_DOWNLOAD_TOKEN` during init/update. Never commit the generated chezmoi config or paste its contents into logs.

### First apply and subsequent downloads

The tool-install hook makes the cache available within its own process before its first `mise install`, unless `GITHUB_TOKEN` is already supplied. It runs before the other after-hooks, from the home directory, without needing an interactive shell. A failed install stops apply rather than recording success. Mise also resolves the cache on demand through `github.credential_command`; its explicit environment overrides still follow mise's own precedence.

Zsh and PowerShell do **not** automatically export a token or copy a saved `gh` login into the environment. Their `gh-download-token` function reads only the private download cache when explicitly called. It replaces the old ambiguous `gh-token` helper; `GH_TOKEN_AUTOEXPORT` is no longer used. For a POSIX command that needs a download token:

```sh
GITHUB_TOKEN="$(gh-download-token)" your-download-command
```

This scopes the export to that command. The accessor outputs a secret, so do not run it directly in shared logs. `GITHUB_DOWNLOAD_TOKEN` is an init input, not a general-purpose environment variable understood by third-party tools.

Check mise's active source with `mise token github`. The token is masked by default. This checks token selection, not whether GitHub accepts it.

### PRs and repository work

Use `gh auth login --hostname github.com` once per machine/account and let GitHub CLI manage the login in the system credential store. If no credential store is available, `gh` can fall back to a plaintext file; check `gh auth status --hostname github.com` for the storage location. Dotfiles do not provision or overwrite this login.

For headless agents, inject a separate repository credential as `GH_TOKEN` into that agent's environment. Give it access to the intended repositories and the permissions required for its operations, including PR creation. Do not broaden the download token to solve PR failures.

GitHub CLI selects **`GH_TOKEN`, then `GITHUB_TOKEN`, then its stored login**. Explicit project/CI overrides remain respected. A valid login or a successful read request does not prove PR write permission. Git-over-SSH authentication is also separate from API authentication.

### Migrating existing sessions

After applying the updated profiles, clear the old automatic export in your current POSIX shell, then check the stored login without environment overrides:

```sh
unset GITHUB_TOKEN
env -u GH_TOKEN -u GITHUB_TOKEN gh auth status --hostname github.com
```

If no stored login exists, sign in without those overrides:

```sh
env -u GH_TOKEN -u GITHUB_TOKEN gh auth login --hostname github.com
```

On PowerShell, clear the old process export with `$env:GITHUB_TOKEN = $null`. If an older apply also saved it persistently, remove that legacy User variable:

```powershell
[Environment]::SetEnvironmentVariable('GITHUB_TOKEN', $null, 'User')
```

Temporarily clear any intentional `GH_TOKEN` override as well when diagnosing or setting up the stored login. Do not remove credentials from CI jobs that require them.

Restart terminals and agents from a clean parent environment. Existing processes retain inherited variables; a new shell launched inside an old terminal, tmux server, or agent can still inherit the stale export. Profiles deliberately do not unset user-supplied tokens. Remove old exports from project or launcher configuration if the problem returns there.

### Spicetify

The upstream CLI update checker makes unauthenticated GitHub requests and does not read `GITHUB_TOKEN`. The managed config disables that checker; Homebrew owns Spicetify updates. Exporting a token alone cannot fix rate limits from that checker.

## bitwarden cache refresh

After changing Bitwarden-backed init data, re-run `chezmoi init --apply brendanlees`; `chezmoi apply` alone does not refresh cached init data. Unset `GITHUB_DOWNLOAD_TOKEN` first if Bitwarden should supply its replacement. Ambient `GITHUB_TOKEN` and `GH_TOKEN` no longer affect what init caches.
