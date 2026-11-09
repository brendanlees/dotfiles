#!/bin/bash

sketchybar --add item clipboard_feedback right \
    --set clipboard_feedback \
    drawing=off \
    icon.drawing=off \
    label.font="$FONT:Bold:13.0" \
    label.color="$GREEN" \
    background.color="$PILL_BG" \
    background.border_color="$SURFACE" \
    background.border_width=1 \
    background.corner_radius="$BORDER_RADIUS" \
    background.height="$PILL_HEIGHT" \
    background.drawing=on \
    padding_left="$ITEM_PADDING" \
    padding_right="$ITEM_PADDING"
