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

on first run, chezmoi will prompt you to configure the machine type (see [scoping](./scoping.md)).

## github token (rate-limit bypass)

mise pulls tools from github releases. without auth, you're limited to 60 req/hr which fails during init. a zero-permission fine-grained PAT bumps this to 5,000 req/hr.

### automatic (ansible)

ansible passes the vault-encrypted token during `chezmoi init` and `chezmoi update` — no action needed.

### manual bootstrap

pass the token as an env var:
```sh
GITHUB_TOKEN=ghp_xxx chezmoi init --apply brendanlees
```

### rotating the token

1. create a new fine-grained PAT (zero permissions) on github
2. update `vault_github_token` in ansible vault
3. run ansible update playbook to propagate to all machines
