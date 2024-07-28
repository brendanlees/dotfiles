# dotfiles

dotfiles, managed by https://www.chezmoi.io/

## set up

install chezmoi at system level
`sudo su
cd /
sh -c "$(curl -fsLS get.chezmoi.io)"
exit`

apply/pull dotfiles repo to user
`sudo sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply $GITHUB_USERNAME`


