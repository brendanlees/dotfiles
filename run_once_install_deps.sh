#!/bin/bash

# prep package manager
apt update && apt upgrade -y && apt autoremove

# install packages
apt install zsh git

# install starship
curl -syS https://starship.rs/install.sh | sh

# set zsh to default shell
chsh -s $(which zsh)
