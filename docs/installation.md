## installation

**macos**

```sh
brew install chezmoi && chezmoi init --apply brendanlees
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

`chezmoi apply` updates configuration and installs missing global tools before the other after-hooks. It does not upgrade mise, upgrade installed tools or prune old versions. Theme switching also skips package scripts and external repository updates.

For authenticated first-run downloads, supply the token before init as described in [secrets](secrets.md). Mise, uv and Herdr tool installation does not require opening a new terminal.

Herdr plugin source builds use the global mise Go toolchain, not whichever `go` shim happens to be on the calling shell's PATH. Hosts without Herdr skip plugin reconciliation. When Herdr is installed, reconciliation checks that toolchain before changing plugins; missing or unusable Go fails visibly. The ledger is updated only after success. If a later plugin fails, earlier successful installs remain, but the old ledger is preserved for retry.

update mise tools explicitly when convenient:

```sh
mise --cd "$HOME" self-update
mise --cd "$HOME" upgrade --exclude starship
mise --cd "$HOME" prune
```
