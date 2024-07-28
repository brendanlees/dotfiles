# dotfiles

dotfiles, managed by https://www.chezmoi.io/

## set up

install chezmoi
`su && cd / && sh -c "$(curl -fsLS get.chezmoi.io) && exit"`

or
`sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply $GITHUB_USERNAME`

in a new shell, pull down repo
`chezmoi init --apply $GITHUB_USERNAME`
