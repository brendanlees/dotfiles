#!/bin/bash

# prep package manager
apt update && apt upgrade -y && apt autoremove

# install packages
apt install zsh git

# install starship
curl -sS https://starship.rs/install.sh | sh -s -y

# set zsh to default shell
chsh -s $(which zsh)
