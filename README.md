# dotfiles

## Set up

Install chezmoi
`sudo sh -c "$(curl -fsLS get.chezmoi.io)"`

In a new shell, pull down repo
`chezmoi init --apply $GITHUB_USERNAME`

Install dependencies via setup.sh
`sudo sh ~/.local/share/chezmoi/setup.sh`

Install omz as user - do not set zsh as default shell
`sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"`