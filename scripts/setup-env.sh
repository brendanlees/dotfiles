#!/bin/bash

# packages
apt update && apt upgrade -y && apt autoremove
apt install zsh git

# starship
curl -sS https://starship.rs/install.sh | sh
