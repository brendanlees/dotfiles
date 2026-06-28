#!/bin/bash

sketchybar --add item battery right \
  --set battery \
    icon.font="$FONT:Bold:16.0" \
    update_freq=120 \
    script="$PLUGIN_DIR/battery.sh" \
  --subscribe battery power_source_change system_woke
