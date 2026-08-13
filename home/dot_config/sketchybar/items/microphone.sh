#!/bin/bash

# Hidden unless CoreAudio reports that an app is actively capturing input.
# The compact red circle sits beside the focused-app pill in the center block.
sketchybar --add item microphone center \
    --set microphone \
    drawing=off \
    width=28 \
    align=center \
    icon="$ICON_MICROPHONE" \
    icon.color="$WHITE" \
    icon.align=center \
    icon.padding_left=0 \
    icon.padding_right=0 \
    label.drawing=off \
    background.color="$MICROPHONE_ACTIVE_COLOR" \
    background.border_width=0 \
    background.corner_radius=14 \
    background.height=28 \
    background.drawing=on \
    padding_left=3 \
    padding_right=3 \
    update_freq=0 \
    script="$PLUGIN_DIR/microphone.sh" \
    --subscribe microphone microphone_change system_woke
