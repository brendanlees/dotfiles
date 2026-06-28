#!/bin/bash

sketchybar --add item calendar right \
  --set calendar \
    icon="$ICON_CALENDAR" \
    icon.font="$FONT:Regular:14.0" \
    icon.color="$CALENDAR_COLOR" \
    icon.padding_left=8 \
    icon.padding_right=4 \
    label.font="$FONT:Regular:13.0" \
    label.color="$WHITE" \
    label.padding_left=0 \
    label.padding_right=8 \
    background.color="$PILL_BG" \
    background.border_color="$CALENDAR_COLOR" \
    background.border_width=1 \
    background.corner_radius=12 \
    background.height=26 \
    background.drawing=on \
    update_freq=30 \
    script="$PLUGIN_DIR/calendar.sh"
