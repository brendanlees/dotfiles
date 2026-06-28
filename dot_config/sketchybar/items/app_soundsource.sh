#!/bin/bash

sketchybar --add item soundsource right \
  --set soundsource \
    icon="$ICON_VOLUME_UNKNOWN" \
    icon.font="$FONT:Bold:16.0" \
    icon.color="$ICON_COLOR" \
    label.drawing=off \
    click_script="osascript -e 'tell application \"System Events\" to key code 0 using {control down, option down}'"
