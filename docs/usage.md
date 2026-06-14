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
