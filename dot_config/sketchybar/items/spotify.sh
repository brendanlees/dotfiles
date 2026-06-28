#!/bin/bash

sketchybar --add item spotify right \
  --set spotify \
    drawing=off \
    icon=":spotify:" \
    icon.font="sketchybar-app-font:Regular:16.0" \
    icon.color="$ICON_COLOR" \
    label.font="$FONT:Regular:13.0" \
    label.color="$LABEL_COLOR" \
    update_freq=15 \
    script="$PLUGIN_DIR/spotify.sh" \
    click_script="osascript -e 'tell application \"Spotify\" to activate'"
