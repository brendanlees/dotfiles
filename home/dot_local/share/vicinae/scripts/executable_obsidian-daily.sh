#!/bin/bash
set -euo pipefail

# @raycast.schemaVersion 1
# @raycast.title Obsidian Daily Note (Neovim)
# @raycast.mode silent
# @raycast.icon 📝
# @raycast.description Focus notes on workspace 8, opening today's note when starting Neovim

# Vicinae may start without the login PATH; inherited tools still win.
PATH="$PATH:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin"

# Repeated hotkeys during startup must not create competing windows. macOS
# lockf locks the inherited descriptor; a crashed launcher releases it too.
mkdir -p "$HOME/.cache/vicinae"
exec 9>"$HOME/.cache/vicinae/obsidian-notes.lock"
lockf -s -t 0 9 || {
  status=$?
  [[ $status == 75 ]] && exit 0
  exit "$status"
}

window_title="Obsidian Notes (Herdr)"
notes_window() {
  aerospace list-windows --all --format '%{window-id} %{app-bundle-id} %{window-title}' --json |
    jq -r --arg title "$window_title" 'first(.[] | select(
      ."app-bundle-id" == "com.mitchellh.ghostty" and ."window-title" == $title
    ) | ."window-id") // empty'
}
focus_window() {
  aerospace move-node-to-workspace --window-id "$1" 8-notes
  aerospace focus --window-id "$1"
}

# Do not change Herdr's view or type into the editor when returning to notes.
window=$(notes_window)
if [[ -n $window ]]; then
  focus_window "$window"
  exit 0
fi

vault="$HOME/Notes/Obsidian/PKM"
cd "$vault"
api=(herdr --session ov)
attach="herdr --session ov"

# Prepare a stopped server before attaching: an attached Herdr client keeps
# its own view, so focusing a tab after attachment would not select notes.
if ! "${api[@]}" tab list >/dev/null 2>&1; then
  nohup herdr --session ov server </dev/null >/dev/null 2>&1 9>&- &
  ready=false
  for _ in {1..30}; do
    if "${api[@]}" tab list >/dev/null 2>&1; then
      ready=true
      break
    fi
    sleep 1
  done
  if ! "$ready"; then
    echo "The ov Herdr session did not become ready; no notes window was opened." >&2
    exit 1
  fi
fi

tab=$("${api[@]}" tab list | jq -r 'first(.result.tabs[] | select(.label == "notes") | .tab_id) // empty')
if [[ -z $tab ]]; then
  tab=$("${api[@]}" workspace create --label notes --cwd "$vault" | jq -r .result.tab.tab_id)
  "${api[@]}" tab rename "$tab" notes >/dev/null
fi
pane=$("${api[@]}" pane list | jq -r --arg tab "$tab" 'first(.result.panes[] | select(.tab_id == $tab) | .pane_id)')
# Start nvim only from an idle shell, never by typing into a running program.
if "${api[@]}" pane process-info --pane "$pane" |
  jq -e '.result.process_info | .shell_pid > 0 and .foreground_process_group_id == .shell_pid' >/dev/null; then
  "${api[@]}" pane run "$pane" "cd ~/Notes/Obsidian/PKM && nvim -c 'Obsidian today'" >/dev/null
fi
"${api[@]}" tab focus "$tab" >/dev/null

# Override both titles so Neovim/Herdr output and Ghostty's blank default
# cannot hide this window from AeroSpace. Never identify it by app alone.
osascript - "/bin/zsh -lic 'exec $attach'" "$window_title" >/dev/null <<'APPLESCRIPT'
on run argv
  tell application "Ghostty"
    set cfg to new surface configuration
    set command of cfg to item 1 of argv
    set notesWindow to new window with configuration cfg
    set notesTab to selected tab of notesWindow
    set name override of notesTab to item 2 of argv
    set name override of focused terminal of notesTab to item 2 of argv
  end tell
end run
APPLESCRIPT

# AeroSpace learns about new windows asynchronously.
for _ in {1..30}; do
  window=$(notes_window)
  if [[ -n $window ]]; then
    focus_window "$window"
    exit 0
  fi
  sleep 0.1
done
echo "The notes window opened, but AeroSpace could not find it." >&2
exit 1
