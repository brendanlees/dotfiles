#!/bin/bash

sketchybar --add item spotify right \
    --set spotify \
    drawing=off \
    icon=":spotify:" \
    icon.font="sketchybar-app-font:Regular:16.0" \
    icon.color="$SPOTIFY_COLOR" \
    label.font="$FONT:Regular:13.0" \
    label.color="$WHITE" \
    background.color="$PILL_BG" \
    background.border_color="$SPOTIFY_COLOR" \
    background.border_width=1 \
    background.corner_radius="$BORDER_RADIUS" \
    background.height=26 \
    background.drawing=on \
    padding_left="$PADDINGS" \
    padding_right="$PADDINGS" \
    update_freq=15 \
    script="$PLUGIN_DIR/spotify.sh" \
    click_script="osascript -e 'tell application \"Spotify\" to activate'"
