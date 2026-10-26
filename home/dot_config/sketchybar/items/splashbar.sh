#!/bin/bash

# SplashBar owns the frame clock and cache; no screen capture or service polling.
sketchybar --add item splashbar right \
    --set splashbar \
    drawing=off \
    width=32 \
    icon.drawing=off \
    label.drawing=off \
    background.drawing=on \
    background.color=0x00000000 \
    background.border_width=0 \
    background.image.scale=0.5 \
    padding_left="$((ITEM_PADDING + 12))" \
    padding_right="$((ITEM_PADDING + 4))" \
    update_freq=1 \
    updates=on \
    script="\"$PLUGIN_DIR/splashbar.py\"" \
    --subscribe splashbar system_woke
