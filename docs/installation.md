## installation

**macos**

Run the repository's bootstrap script:

```sh
sh install.sh
```

Without a checkout, download it first so Git/Command Line Tools are not a prerequisite:

```sh
curl -fsSL https://raw.githubusercontent.com/brendanlees/dotfiles/main/install.sh -o /tmp/dotfiles-install.sh
less /tmp/dotfiles-install.sh
sh /tmp/dotfiles-install.sh
```

The script checks Apple's Command Line Tools (or an active Xcode installation), installs Homebrew and mise when missing, activates Homebrew in the current process, then installs/reuses chezmoi and applies the dotfiles. Existing package-manager mise installs are linked at `~/.local/bin/mise`, which the apply hooks expect. Persistent shell setup and declared mise tools remain owned by chezmoi.

If developer tools are missing, complete the Apple installer and rerun the script. It does not accept Xcode licences or switch developer directories for you. Remote Homebrew/mise installers require confirmation; automation can opt in with `CHEZMOI_ALLOW_REMOTE_SCRIPTS=1`.

For Bitwarden-backed private repos, unlock the CLI before init and configure the SSH manifest. The first apply provisions SSH; a second apply fetches the Gitea configs. See [SSH bootstrap](ssh.md#first-apply) and [secrets](secrets.md).

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
