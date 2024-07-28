# dotfiles

## Set up

Install chezmoi
`sudo sh -c "$(curl -fsLS get.chezmoi.io)"`

In a new shell, pull down repo
`chezmoi init --apply $GITHUB_USERNAME`

Install env dependencies via setup-env.sh
`sudo sh ~/.local/share/chezmoi/scripts/setup-env.sh`

Install user specific dependencies via setup-user.sh
`sh ~/.local/share/chezmoi/scripts/setup-user.sh`
