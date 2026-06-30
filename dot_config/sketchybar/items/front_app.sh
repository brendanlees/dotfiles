#!/bin/bash

sketchybar --add item front_app center \
    --set front_app \
    icon.font="sketchybar-app-font:Regular:11.0" \
    icon.color="$WHITE" \
    icon.padding_left="$ITEM_PADDING" \
    icon.padding_right="$ITEM_PADDING" \
    label.font="$FONT:Regular:13.0" \
    label.color="$WHITE" \
    label.padding_left=2 \
    label.padding_right="$ITEM_PADDING" \
    background.color="$SURFACE" \
    background.border_color="$SURFACE" \
    background.border_width=1 \
    background.corner_radius="$BORDER_RADIUS" \
    background.height="$PILL_HEIGHT" \
    background.drawing=on \
    padding_left="$ITEM_PADDING" \
    padding_right="$ITEM_PADDING" \
    script="$PLUGIN_DIR/front_app.sh" \
    --subscribe front_app front_app_switched
