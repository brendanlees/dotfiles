#!/bin/bash

sketchybar --add item battery right \
    --set battery \
    icon.font="$FONT:Bold:14.0" \
    icon.color="$GREEN" \
    icon.padding_right=0 \
    label.font="$FONT:Regular:13.0" \
    label.color="$WHITE" \
    background.color="$PILL_BG" \
    background.border_color="$GREEN" \
    background.border_width=1 \
    background.corner_radius=8 \
    background.height="$PILL_HEIGHT" \
    background.drawing=on \
    padding_left="$ITEM_PADDING" \
    padding_right="$ITEM_PADDING" \
    update_freq=120 \
    script="$PLUGIN_DIR/battery.sh" \
    --subscribe battery power_source_change system_woke
