#!/bin/bash

sketchybar --add item calendar right \
    --set calendar \
    icon="⣿" \
    icon.font="$FONT:Regular:13.0" \
    icon.color="$GREY" \
    icon.padding_left=6 \
    icon.padding_right=12 \
    update_freq=30 \
    script="$PLUGIN_DIR/calendar.sh"
