#!/bin/bash

sketchybar --add item calendar right \
  --set calendar \
    icon="⣿" \
    icon.font="$FONT:Regular:13.0" \
    icon.color="$GREY" \
    icon.padding_left=4 \
    icon.padding_right=6 \
    update_freq=30 \
    script="$PLUGIN_DIR/calendar.sh"
