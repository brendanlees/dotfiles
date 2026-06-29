#!/bin/bash

# Compact always-on sync status:
#   icon + two vertically offset dots
#   top dot    = Syncthing
#   bottom dot = Mutagen
# The plugin updates dot colors: grey=inactive, green=healthy/idle,
# yellow=syncing/working, red=error/problem.

SYNC_ICON="󰑓"

sketchybar --add item sync_dot_mutagen right \
  --set sync_dot_mutagen \
  icon="●" \
  icon.font="$FONT:Regular:8.0" \
  icon.color="$GREY" \
  icon.y_offset=-4 \
  icon.padding_left=0 \
  icon.padding_right=2 \
  label.drawing=off \
  background.drawing=off \
  padding_left=-10 \
  padding_right=10

sketchybar --add item sync_dot_syncthing right \
  --set sync_dot_syncthing \
  icon="●" \
  icon.font="$FONT:Regular:8.0" \
  icon.color="$GREY" \
  icon.y_offset=4 \
  icon.padding_left=0 \
  icon.padding_right=2 \
  label.drawing=off \
  background.drawing=off \
  padding_left=0 \
  padding_right=2

sketchybar --add item sync_status right \
  --set sync_status \
  icon="$SYNC_ICON" \
  icon.font="$FONT:Bold:20.0" \
  icon.color="$ICON_COLOR" \
  icon.padding_left=8 \
  icon.padding_right=4 \
  label.drawing=off \
  background.drawing=off \
  padding_left=0 \
  padding_right=0 \
  update_freq=15 \
  script="$PLUGIN_DIR/sync_status.sh" \
  --subscribe sync_status system_woke

sketchybar --add bracket sync_status_group \
  sync_status \
  sync_dot_syncthing \
  sync_dot_mutagen \
  --set sync_status_group \
  background.drawing=on \
  background.color="$PILL_BG" \
  background.border_color="$GREY" \
  background.border_width=1 \
  background.corner_radius="$BORDER_RADIUS" \
  background.height=26 \
  blur_radius=0
