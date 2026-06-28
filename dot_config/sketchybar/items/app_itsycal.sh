#!/bin/bash

sketchybar --add item itsycal right \
  --set itsycal \
    icon=󰃭 \
    icon.font="$FONT:Bold:16.0" \
    icon.color=$ICON_COLOR \
    label.drawing=off \
    click_script="open -a 'Itsycal'"
