## installation

**macos**

run the bootstrap script:

```sh
sh install.sh
```



**linux**

```sh
sh -c "$(curl -fsLS get.chezmoi.io/lb)" -- init --apply brendanlees
```

**windows**

```pwsh
winget install -e --id twpayne.chezmoi --accept-source-agreements --accept-package-agreements
chezmoi init --apply brendanlees
```

on first run you'll be prompted to set machine role. these role flags gate which config and packages are applied.

```
personal | work | homelab
```

chezmoi will detect the system environment automatically, and configure things accordingly based on the relevant machine role.

```
darwin | windows | linux
```

see [scoping](docs/scoping.md) for non-interactive options via env vars, ansible.

## maintenance

`chezmoi apply` updates configuration and installs missing global tools before the other after-hooks. 

update mise tools explicitly when convenient:

```sh
mise --cd "$HOME" self-update
mise --cd "$HOME" upgrade --exclude starship
mise --cd "$HOME" prune
```

install missing [skills.sh](https://skills.sh/) skills from `agents/.skill-lock.json` and update the rest to their latest upstream versions:

```sh
npx skills update -g -y
```

review the lockfile diff before committing. custom and locally edited skills are allowlisted in `.gitignore`, stay out of the lockfile and are never updated. to fork an upstream skill, remove it from the lockfile and allowlist it.
