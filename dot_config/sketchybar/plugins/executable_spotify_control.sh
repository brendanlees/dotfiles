#!/bin/bash

set -u

action="${1:-toggle}"

spotify_running() {
  osascript -e 'application "Spotify" is running' 2>/dev/null
}

ensure_spotify() {
  if [ "$(spotify_running)" != "true" ]; then
    open -a Spotify >/dev/null 2>&1 || true
    return 1
  fi
  return 0
}

refresh_spotify_item() {
  sketchybar --trigger spotify_change >/dev/null 2>&1 || true
}

case "$action" in
  previous|prev)
    ensure_spotify || exit 0
    osascript -e 'tell application "Spotify" to previous track' >/dev/null 2>&1 || true
    refresh_spotify_item
    ;;
  toggle|playpause|play-pause)
    ensure_spotify || exit 0
    osascript -e 'tell application "Spotify" to playpause' >/dev/null 2>&1 || true
    refresh_spotify_item
    ;;
  next)
    ensure_spotify || exit 0
    osascript -e 'tell application "Spotify" to next track' >/dev/null 2>&1 || true
    refresh_spotify_item
    ;;
  activate|open|show)
    open -a Spotify >/dev/null 2>&1 || true
    ;;
  popup|toggle-popup)
    sketchybar --set spotify popup.drawing=toggle >/dev/null 2>&1 || true
    ;;
  hide-popup|close-popup)
    sketchybar --set spotify popup.drawing=off >/dev/null 2>&1 || true
    ;;
  *)
    echo "usage: $0 {previous|toggle|next|activate|popup|hide-popup}" >&2
    exit 2
    ;;
esac
