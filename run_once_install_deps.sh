#!/bin/bash

# prep package manager
apt update && apt upgrade -y && apt autoremove

# install packages
apt install zsh git -y

# install starship
curl -sS https://starship.rs/install.sh | sh -y
