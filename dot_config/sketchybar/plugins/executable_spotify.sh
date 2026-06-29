#!/bin/bash

CONFIG_DIR="${CONFIG_DIR:-${HOME}/.config/sketchybar}"
# shellcheck source=dot_config/sketchybar/colors.sh
source "$CONFIG_DIR/colors.sh"
FONT="${FONT:-JetBrainsMono Nerd Font Mono}"

hide_item() {
  sketchybar --set "$NAME" drawing=off label=""
}

is_running="$(osascript -e 'application "Spotify" is running' 2>/dev/null || true)"
if [ "$is_running" != "true" ]; then
  hide_item
  exit 0
fi

player_state="$(osascript -e 'tell application "Spotify" to player state as string' 2>/dev/null || true)"
case "$player_state" in
  playing) state_icon="⏸" ;;
  paused) state_icon="▶" ;;
  *) state_icon="▶" ;;
esac

artist="$(osascript -e 'tell application "Spotify" to artist of current track' 2>/dev/null || true)"
title="$(osascript -e 'tell application "Spotify" to name of current track' 2>/dev/null || true)"
artwork_url="$(osascript -e 'tell application "Spotify" to artwork url of current track' 2>/dev/null || true)"

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
  icon.font="$FONT:Bold:13.0" \
  icon.color="$accent_color" \
  label="$label" \
  label.color="$LABEL_COLOR" \
  background.border_color="$accent_color"
