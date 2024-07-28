# dotfiles

dotfiles, managed by https://www.chezmoi.io/

## set up

install chezmoi at system level
`sudo sh -c 'su -c "cd / && sh -c \"\$(curl -fsLS get.chezmoi.io)\""'
`

apply/pull dotfiles repo to user(s)
`chezmoi init --apply $GITHUB_USERNAME`


