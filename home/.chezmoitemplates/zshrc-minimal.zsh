# Minimal shell for hosts on the minimal role, such as the Home Assistant SSH
# add-on. Tools come from the host's package manager, not mise.

export EDITOR=nvim
export VISUAL=nvim
# Standalone editor config in ~/.config/nvim-minimal.
export NVIM_APPNAME=nvim-minimal
export PATH="$HOME/.local/bin:$PATH"

alias v=nvim
alias vim=nvim
alias ll='ls -la'

# HISTFILE keeps its default (~/.zsh_history), which the Home Assistant add-on
# links into its persistent /data volume.
HISTSIZE=10000
SAVEHIST=$HISTSIZE
setopt appendhistory sharehistory hist_ignore_space hist_ignore_all_dups

autoload -U compinit && compinit -u
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

PROMPT='%F{blue}%~%f %(?.%F{green}.%F{red})❯%f '

set -o vi
bindkey jj vi-cmd-mode
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line
bindkey '^P' history-search-backward
bindkey '^N' history-search-forward

# Ctrl+X Ctrl+E edits the current command line in nvim.
autoload -U edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line
