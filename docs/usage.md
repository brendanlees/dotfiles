# usage

## updating

pull the latest dotfiles and apply them:

```sh
chezmoi update
```

or do it manually:

```sh
chezmoi git pull && chezmoi apply
```

## installing on a new machine

**macos**

```sh
brew install chezmoi
chezmoi init --apply brendanlees
```

**linux**

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply brendanlees
```

**windows**

```pwsh
winget install -e --id twpayne.chezmoi --accept-source-agreements --accept-package-agreements
chezmoi init --apply brendanlees
```

on first run, choose the machine role. see [scoping](./scoping.md) for non-interactive role setup and ansible usage.

## related docs

- [secrets](./secrets.md) — github token bootstrap, rate limits, and bitwarden cache refresh
- [ssh](./ssh.md) — ssh config and bitwarden-backed keys
- [agentic tooling](./agentic-tooling.md) — headroom wrappers and pi/codex routing
