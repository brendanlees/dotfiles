#!/bin/bash

# packages
apt install git neofetch tmux

# chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)"

# starship
curl -sS https://starship.rs/install.sh | sh

# oh-my-zsh - (do not set default to zsh)
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

