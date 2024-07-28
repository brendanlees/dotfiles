#!/bin/bash

# prep package manager
apt update && apt upgrade -y && apt autoremove

# install packages
apt install zsh git

# install starship
sh -c "$(curl -sS https://starship.rs/install.sh)" -- -y

# set zsh to default shell
chsh -s $(which zsh)
