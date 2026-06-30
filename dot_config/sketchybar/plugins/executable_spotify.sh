#!/bin/bash

CONFIG_DIR="${CONFIG_DIR:-${HOME}/.config/sketchybar}"
# shellcheck source=dot_config/sketchybar/colors.sh
source "$CONFIG_DIR/colors.sh"
FONT="${FONT:-JetBrainsMono Nerd Font Mono}"

if [ -z "${TMPDIR:-}" ] || [ ! -d "$TMPDIR" ]; then
  export TMPDIR=/tmp
fi

LOCK_DIR="${TMPDIR:-/tmp}/sketchybar-spotify-${UID:-$(id -u)}.lock"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT INT TERM

hide_item() {
  sketchybar --set "$NAME" drawing=off label=""
}

spotify_pid="$(pgrep -x Spotify | head -n 1 || true)"

spotify_info="$(osascript <<'APPLESCRIPT' 2>/dev/null || true
if application "Spotify" is running then
  tell application "Spotify"
    set playerState to player state as string
    set trackArtist to ""
    set trackTitle to ""
    set trackArtwork to ""

    try
      set currentTrack to current track
      set trackArtist to artist of currentTrack
      set trackTitle to name of currentTrack
      set trackArtwork to artwork url of currentTrack
    end try

    return playerState & linefeed & trackArtist & linefeed & trackTitle & linefeed & trackArtwork
  end tell
else
  return "not_running"
end if
APPLESCRIPT
)"

if [ -z "$spotify_info" ]; then
  hide_item
  exit 0
fi

player_state="$(printf '%s\n' "$spotify_info" | sed -n '1p')"
if [ "$player_state" = "not_running" ]; then
  hide_item
  exit 0
fi

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
  paused|stopped) state_icon="⏸" ;;
  *) state_icon="⏸" ;;
esac

artist="$(printf '%s\n' "$spotify_info" | sed -n '2p')"
title="$(printf '%s\n' "$spotify_info" | sed -n '3p')"
artwork_url="$(printf '%s\n' "$spotify_info" | sed -n '4p')"

if [ -n "$artist" ] && [ -n "$title" ]; then
  track="$artist — $title"
elif [ -n "$title" ]; then
  track="$title"
elif [ -n "$artist" ]; then
  track="$artist"
else
  track="Spotify"
fi

max_chars="${SPOTIFY_LABEL_MAX_CHARS:-40}"
label="$(/usr/bin/python3 - "$track" "$max_chars" <<'PY'
import sys

text = sys.argv[1]
try:
    max_chars = int(sys.argv[2])
except Exception:
    max_chars = 40

if max_chars < 2:
    max_chars = 2

if len(text) > max_chars:
    text = text[: max_chars - 1] + "…"

print(text)
PY
)"

accent_color="$SPOTIFY_COLOR"
if [ -n "$artwork_url" ] && [ -x "$CONFIG_DIR/plugins/spotify_art_accent.py" ]; then
  artwork_accent="$("$CONFIG_DIR/plugins/spotify_art_accent.py" "$artwork_url" 2>/dev/null || true)"
  if [ -n "$artwork_accent" ]; then
    accent_color="$artwork_accent"
  fi
fi

sketchybar --set "$NAME" \
  drawing=on \
  icon="$state_icon" \
  icon.font="$FONT:Bold:15.0" \
  icon.color="$accent_color" \
  label="$label" \
  label.color="$LABEL_COLOR" \
