#!/bin/bash

# shellcheck source=../colors.sh
source "$CONFIG_DIR/colors.sh"

set_item_state() {
  if [ "$1" = "1" ]; then
    sketchybar \
      --set "$NAME" \
        drawing=on \
        icon.color="$WHITE" \
        background.color="$MICROPHONE_ACTIVE_COLOR" \
      --set microphone_balance drawing=on
  else
    sketchybar \
      --set "$NAME" drawing=off \
      --set microphone_balance drawing=off
  fi
}

# Hammerspoon (~/.hammerspoon/microphone.lua) watches CoreAudio and sends the
# new state with this event.
if [ "${SENDER:-}" = "microphone_change" ]; then
  set_item_state "${MIC_ACTIVE:-0}"
  exit 0
fi

# After the bar loads, ask Hammerspoon to resend the current state.
open -g "hammerspoon://microphone-refresh"
