#!/bin/bash
set -euo pipefail

# @raycast.schemaVersion 1
# @raycast.title Obsidian Daily Note (Neovim)
# @raycast.mode silent
# @raycast.icon 📝
# @raycast.description Open today's daily note in a new Ghostty window

# An interactive login shell loads mise and the same ov shortcut used in terminals.
exec open -na Ghostty --args -e /bin/zsh -lic ov
