#!/bin/bash

sketchybar --add item front_app_separator left \
  --set front_app_separator \
    icon="⣿" \
    icon.font="$FONT:Regular:13.0" \
    icon.color="$GREY" \
    icon.padding_left=6 \
    icon.padding_right=8 \
    label.drawing=off

sketchybar --add item front_app left \
  --set front_app \
    icon.font="sketchybar-app-font:Regular:16.0" \
    icon.padding_right=5 \
    label.font="$FONT:Semibold:13.0" \
    script="$PLUGIN_DIR/front_app.sh" \
  --subscribe front_app front_app_switched
