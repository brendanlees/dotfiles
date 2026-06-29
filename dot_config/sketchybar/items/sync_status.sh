#!/bin/bash

# Compact always-on sync status.
# The plugin updates the pill background: grey=inactive,
# green=healthy/idle, yellow=syncing/working, red=error/problem.

SYNC_ICON="󰑓"

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
  --set sync_status_group \
  background.drawing=on \
  background.color="$PILL_BG" \
  background.border_color="$GREY" \
  background.border_width=1 \
  background.corner_radius="$BORDER_RADIUS" \
  background.height=26 \
  blur_radius=0
