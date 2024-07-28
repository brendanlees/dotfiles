#!/bin/bash

# packages
apt update && apt upgrade -y && apt autoremove
apt install zsh git neofetch

# starship
curl -sS https://starship.rs/install.sh | sh

# oh-my-zsh - (do not set default to zsh)
# sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

