# dotfiles

Managed by [chezmoi](https://www.chezmoi.io/)

## Installation & Configuration

### Linux
```sh
# install chezmoi
sudo sh -c 'su -c "cd / && sh -c \"\$(curl -fsLS get.chezmoi.io)\""'

# init as sudo to run setup scripts and apply dotfiles to root
sudo chezmoi init --apply $GITHUB_USERNAME

# init for non-root system user(s) if required
chezmoi init --apply $GITHUB_USERNAME

```

### Mac OS
```sh
# install chezmoi
brew install chezmoi

# apply dotfiles to user
chezmoi init --apply $GITHUB_USERNAME


```


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
- https://github.com/fredericrous/dotfiles


