#!/bin/bash
set -euo pipefail

# @raycast.schemaVersion 1
# @raycast.title Obsidian Daily Note (Neovim)
# @raycast.mode silent
# @raycast.icon 📝
# @raycast.description Open today's daily note in the notes tab of the ov herdr session

# Vicinae may start without the login PATH; inherited tools still win.
PATH="$PATH:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin"

# bmax keeps the vault synced, so Macs that save its ov session as a herdr
# machine use that; bmax itself uses its local session. Remote attaches also
# create a local sessions/ov folder, so herdr's session list can't decide this.
if herdr machine list --json | jq -e 'any(.[]; .label == "bmax/ov")' >/dev/null; then
  api=(herdr --machine bmax/ov)
  attach="herdr --remote bmax --session ov"
else
  api=(herdr --session ov)
  attach="herdr --session ov"
fi

# An attached client keeps its own view, while a new one opens on the session's
# focused tab, so replace any client already attached with this command.
open_window() {
  pkill -HUP -fx "$attach" || true
  osascript - "/bin/zsh -lic 'exec $attach'" >/dev/null <<'APPLESCRIPT'
on run argv
  tell application "Ghostty"
    set cfg to new surface configuration
    set command of cfg to item 1 of argv
    new window with configuration cfg
    activate
  end tell
end run
APPLESCRIPT
}

# Attaching starts a stopped session; wait for it before changing its layout.
if ! "${api[@]}" tab list >/dev/null 2>&1; then
  open_window
  for _ in {1..30}; do
    "${api[@]}" tab list >/dev/null 2>&1 && break
    sleep 1
  done
fi

tab=$("${api[@]}" tab list | jq -r 'first(.result.tabs[] | select(.label == "notes") | .tab_id) // empty')
if [[ -z $tab ]]; then
  tab=$("${api[@]}" workspace create --label notes | jq -r .result.tab.tab_id)
  "${api[@]}" tab rename "$tab" notes >/dev/null
fi
pane=$("${api[@]}" pane list | jq -r --arg tab "$tab" 'first(.result.panes[] | select(.tab_id == $tab) | .pane_id)')
# Start nvim only from an idle shell, never by typing into a running program.
# That shell expands ~, so the same path works for bmax's session.
if "${api[@]}" pane process-info --pane "$pane" |
  jq -e '.result.process_info | .foreground_process_group_id == .shell_pid' >/dev/null; then
  "${api[@]}" pane run "$pane" "cd ~/Notes/Obsidian/PKM && nvim -c 'Obsidian today'" >/dev/null
fi
"${api[@]}" tab focus "$tab" >/dev/null
open_window
