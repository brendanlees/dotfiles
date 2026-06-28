#!/bin/bash

sketchybar --add item soundsource right \
  --set soundsource \
    icon="$ICON_VOLUME_UNKNOWN" \
    icon.font="$FONT:Bold:16.0" \
    icon.color="$GREY" \
    label.drawing=off \
    update_freq=60 \
    script="$PLUGIN_DIR/soundsource.sh" \
    click_script="osascript -e 'tell application \"SoundSource\" to activate'"
