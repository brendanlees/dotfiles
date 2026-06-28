#!/bin/bash

sketchybar --add item soundsource right \
  --set soundsource \
    icon=󰕾 \
    icon.font="$FONT:Bold:16.0" \
    icon.color=$ICON_COLOR \
    label.drawing=off \
    click_script="osascript -e 'tell application \"SoundSource\" to activate'"
