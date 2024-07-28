# dotfiles

Managed by [chezmoi](https://www.chezmoi.io/) with a bit of [mackup](https://github.com/lra/mackup)

## Installation & Configuration

### Linux
```sh
# install chezmoi at system bin level
sudo sh -c 'su -c "cd / && sh -c \"\$(curl -fsLS get.chezmoi.io)\""'

# use sudo if applying dotfiles repo to root user
sudo chezmoi init --apply $GITHUB_USERNAME

# no sudo if applying dotfiles repo to non-root user(s)
chezmoi init --apply $GITHUB_USERNAME

```

### Mac OS
```sh
# install chezmoi
brew install chezmoi

# apply dotfiles repo to user(s)
chezmoi init --apply $GITHUB_USERNAME

# restore ~/dotfiles-mac/mackup from a backup archive, then run:
mackup restore

```
Mackup symlinks selected Mac OS app config files to the folder `~/dotfiles-mac/`. Snapshots of this directory are then backed up to Time Machine (local) & Arq + Backblaze B2 (cloud). This offers more retention/versioning options than the standard iCloud/Dropbox storage option that is offered as a default in Mackup.


## References & Future Tweaks
- https://www.chezmoi.io/
	- Docs
	- User guides
- https://github.com/twpayne/dotfiles
	- Chezmoi creators repo
- https://github.com/logandonley/dotfiles
	- Ansible integration
- https://github.com/sudopluto/dotfiles
	- Encryption usage
- Gitleaks


