#!/bin/bash
set -euo pipefail

# AeroSpace may start without the login PATH; inherited tools still win.
PATH="$PATH:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin"

# Alt+N reserves this title for the notes window.
window=$(aerospace list-windows --all --format '%{window-id} %{app-bundle-id} %{window-title}' --json |
  jq -r --arg notes_title "Obsidian Notes (Herdr)" 'first(.[] | select(
    ."app-bundle-id" == "com.mitchellh.ghostty" and ."window-title" != $notes_title
  ) | ."window-id") // empty')

if [[ -n $window ]]; then
  aerospace focus --window-id "$window"
  exit 0
fi

# Activating the app alone could bring notes forward instead of opening a shell.
osascript - >/dev/null <<'APPLESCRIPT'
tell application "Ghostty"
  set terminalWindow to new window
  activate window terminalWindow
end tell
APPLESCRIPT
