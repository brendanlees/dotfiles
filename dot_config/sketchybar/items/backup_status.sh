#!/bin/bash

# Compact backup status, hidden unless Arq or Time Machine is actively backing up.
# The plugin updates the pill background: blue=Arq, green=Time Machine,
# cyan=both.

BACKUP_ICON=":time_machine:"

sketchybar --add item backup_status right \
  --set backup_status \
  drawing=off \
  icon="$BACKUP_ICON" \
  icon.font="sketchybar-app-font:Regular:12.0" \
  icon.color="$ICON_COLOR" \
  icon.padding_left=8 \
  icon.padding_right=5 \
  label.drawing=off \
  background.drawing=off \
  padding_left=0 \
  padding_right=0 \
  update_freq=30 \
  script="$PLUGIN_DIR/backup_status.sh" \
  --subscribe backup_status system_woke

sketchybar --add bracket backup_status_group \
  backup_status \
  --set backup_status_group \
  background.drawing=off \
  background.color="$PILL_BG" \
  background.border_color="$GREY" \
  background.border_width=1 \
  background.corner_radius="$BORDER_RADIUS" \
  background.height=26 \
  blur_radius=0
