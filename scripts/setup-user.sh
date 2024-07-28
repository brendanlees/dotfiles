#!/bin/bash

# oh-my-zsh - (set default to zsh)
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# remove oh-my-zsh default rc file
rm .zshrc
mv .zshrc.pre-oh-my-zsh .zshrc

# update default shell
# chsh -s $(which zsh)