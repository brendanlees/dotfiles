#!/bin/bash

CONFIG_DIR="${CONFIG_DIR:-${HOME}/.config/sketchybar}"
# shellcheck source=dot_config/sketchybar/colors.sh
source "$CONFIG_DIR/colors.sh"
FONT="${FONT:-JetBrainsMono Nerd Font Mono}"

if [ -z "${TMPDIR:-}" ] || [ ! -d "$TMPDIR" ]; then
  export TMPDIR=/tmp
fi

# Serialize notification and timer refreshes so metadata reads cannot overlap.
LOCK_DIR="${TMPDIR:-/tmp}/sketchybar-spotify-${UID:-$(id -u)}.lock"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT INT TERM

hide_item() {
  sketchybar --set "$NAME" drawing=off label=""
}

spotify_pid="$(pgrep -x Spotify | head -n 1 || true)"

# Keep metadata reads in one guarded call to avoid reopening Spotify.
spotify_info="$(
  osascript <<'APPLESCRIPT' 2>/dev/null || true
if application "Spotify" is running then
  tell application "Spotify"
    set playerState to player state as string
    set trackArtist to ""
    set trackTitle to ""

    try
      set currentTrack to current track
      set trackArtist to artist of currentTrack
      set trackTitle to name of currentTrack
    end try

    return playerState & linefeed & trackArtist & linefeed & trackTitle
  end tell
else
  return "not_running"
end if
APPLESCRIPT
)"

{
  IFS= read -r player_state
  IFS= read -r artist
  IFS= read -r title
} <<< "$spotify_info"

if [ -z "$player_state" ] || [ "$player_state" = "not_running" ]; then
  hide_item
  exit 0
fi

# Spotify can relaunch if it quits during the metadata read.
current_spotify_pid="$(pgrep -x Spotify | head -n 1 || true)"
if [ -n "$spotify_pid" ] && [ "$current_spotify_pid" != "$spotify_pid" ]; then
  if [ -n "$current_spotify_pid" ]; then
    osascript -e 'tell application "Spotify" to quit' >/dev/null 2>&1 || true
  fi
  hide_item
  exit 0
fi

case "$player_state" in
playing) state_icon="▶" ;;
*) state_icon="⏸" ;;
esac

if [ -n "$artist" ] && [ -n "$title" ]; then
  track="$artist — $title"
elif [ -n "$title" ]; then
  track="$title"
elif [ -n "$artist" ]; then
  track="$artist"
else
  track="Spotify"
fi

label="$track"
if [ "${#label}" -gt 40 ]; then
  label="${label:0:39}…"
fi

sketchybar --set "$NAME" \
  drawing=on \
  icon="$state_icon" \
  icon.font="$FONT:Bold:16.0" \
  icon.color="$SPOTIFY_COLOR" \
  label="$label" \
  label.color="$LABEL_COLOR"
