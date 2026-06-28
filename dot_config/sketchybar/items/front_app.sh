#!/bin/bash

sketchybar --add item front_app center \
  --set front_app \
    icon.font="sketchybar-app-font:Regular:16.0" \
    icon.color="$WHITE" \
    icon.padding_left=8 \
    icon.padding_right=4 \
    label.font="$FONT:Semibold:13.0" \
    label.color="$WHITE" \
    label.padding_left=0 \
    label.padding_right=8 \
    background.color="$PILL_BG" \
    background.border_color="$FRONT_APP_COLOR" \
    background.border_width=1 \
    background.corner_radius=12 \
    background.height=26 \
    background.drawing=on \
    padding_left=6 \
    padding_right=6 \
    script="$PLUGIN_DIR/front_app.sh" \
  --subscribe front_app front_app_switched
