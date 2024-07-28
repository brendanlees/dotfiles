# dotfiles

dotfiles, managed by https://www.chezmoi.io/

## set up

install chezmoi at system level
`sudo sh -c 'su -c "cd / && sh -c \"\$(curl -fsLS get.chezmoi.io)\""'`

apply/pull dotfiles repo to as intended user(s)
```sh

# for root/sudo users
sudo chezmoi init --apply $GITHUB_USERNAME

# for system users
chezmoi init --apply $GITHUB_USERNAME

```

## references, future tweaks
- https://www.chezmoi.io/
	- docs
	- user guides
- https://github.com/twpayne/dotfiles
	- creators repo
- https://github.com/logandonley/dotfiles
	- ansible integration
- https://github.com/sudopluto/dotfiles
	- encryption usage


