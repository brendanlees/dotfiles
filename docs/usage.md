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
# for personal hosts, also install bw before init so the bitwarden integration is wired up:
winget install -e --id Bitwarden.CLI --accept-source-agreements --accept-package-agreements
# open a new terminal so PATH picks up chezmoi/bw, then:
chezmoi init --apply brendanlees
```

on first run, chezmoi will prompt you to configure the machine type (see [scoping](./scoping.md)).

## github token (rate-limit bypass)

mise pulls tools from github releases. without auth, you're limited to 60 req/hr which fails during init. a zero-permission fine-grained PAT bumps this to 5,000 req/hr.

### automatic (ansible)

ansible passes the vault-encrypted token during `chezmoi init` and `chezmoi update` — no action needed.

### personal (bitwarden)

on personal hosts the token is pulled from the same Bitwarden item used for git identity (`d256649b-8944-43a3-a016-abc1018ad825`). add a `read_only_token` custom field to that item (a zero-permission fine-grained PAT) and chezmoi maps it onto `.github_token` at init time, which feeds the after-install scripts that export `GITHUB_TOKEN` (and, on windows, persist it to user-scope env vars for mise/gh).

prerequisites:
- bw installed and on PATH **before** running `chezmoi init` — otherwise the `[bitwarden]` auto-unlock block isn't emitted and the lookup silently falls back to empty. on macos this comes from `run_once_before_install_deps.sh.tmpl`; on windows install it via winget (see the windows install line above) before init.
- bw signed in once: `bw login` (chezmoi handles the per-session unlock automatically when `[bitwarden] unlock = "auto"` is set).

to refresh after rotating the token: `chezmoi init` (re-runs the template, re-fetches from bw, updates `~/.config/chezmoi/chezmoi.toml`).

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

### rotating the token

1. create a new fine-grained PAT (zero permissions) on github
2. update `vault_github_token` in ansible vault
3. run ansible update playbook to propagate to all machines
