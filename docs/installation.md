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

The role-scoped `taps` list in `home/.chezmoidata/packages-darwin.yml` is also the Homebrew approval list. Provisioning runs `brew trust --tap` before tapping each entry; this trusts future contents of those taps, without disabling trust checks globally. Fully qualified packages must have their tap declared for the same roles.

For Bitwarden-backed private repos, unlock the CLI before init and configure the SSH manifest. The first apply provisions SSH. For agent-backed hosts, separately open Bitwarden desktop, sign in and enable its SSH agent before applying again to fetch private configs. The desktop toggle remains manual. See [SSH bootstrap](ssh.md#first-apply) and [secrets](secrets.md).

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

## macOS Finder and input preferences

The defaults hook applies selected Finder, mouse, trackpad and keyboard preferences to non-headless personal and work Macs. System shortcuts stay under local user control; Kanata and OpenLogi retain their own configuration. Full preference and application-preset plist snapshots are no longer tracked. This does not delete existing preferences or uninstall applications. LaunchAgent/service templates remain managed.

Column view is the default for Finder windows and searches. Finder can still remember a different view in an existing folder's `.DS_Store`; provisioning does not erase those files, sidebar bookmarks or recent-folder history. Log out and back in if keyboard layout or input changes do not take effect immediately.

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
