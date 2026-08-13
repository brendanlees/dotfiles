#!/bin/bash

# Invisible counterweight for the active microphone circle. It is toggled with
# the microphone so the focused-app pill remains exactly centered.
sketchybar --add item microphone_balance center \
    --set microphone_balance \
    drawing=off \
    width=28 \
    icon.drawing=off \
    label.drawing=off \
    background.drawing=off \
    padding_left=3 \
    padding_right=3
