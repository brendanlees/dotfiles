#!/bin/bash

# prep package manager
apt update -y && apt upgrade -y && apt autoremove -y

# install packages
apt install zsh git -y

# install starship
curl -sS https://starship.rs/install.sh | sh -y
