#!/bin/bash

sketchybar --add item calendar right \
  --set calendar \
    icon.drawing=off \
    update_freq=30 \
    script="$PLUGIN_DIR/calendar.sh"
