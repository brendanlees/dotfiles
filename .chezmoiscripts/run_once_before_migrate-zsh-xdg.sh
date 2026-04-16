#!/bin/bash
set -euo pipefail

# create XDG directory structure for zsh
mkdir -p "$HOME/.local/share/zsh/plugins"
mkdir -p "$HOME/.local/state/zsh"
mkdir -p "$HOME/.cache/zsh"

# migrate zsh history to XDG state dir (copy, don't move — old file
# will be cleaned up by .chezmoiremove after this script succeeds)
if [ -f "$HOME/.zsh_history" ] && [ ! -f "$HOME/.local/state/zsh/history" ]; then
  cp "$HOME/.zsh_history" "$HOME/.local/state/zsh/history"
  echo "migrated zsh history -> ~/.local/state/zsh/history"
fi
