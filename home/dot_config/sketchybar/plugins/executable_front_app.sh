#!/bin/bash

CONFIG_DIR="${CONFIG_DIR:-${HOME}/.config/sketchybar}"

if [ "$SENDER" = "front_app_switched" ]; then
  app_name="${INFO:-}"
  icon=":default:"
  icon_map="$CONFIG_DIR/plugins/icon_map.sh"

  if [ -n "$app_name" ] && [ -x "$icon_map" ]; then
    icon="$($icon_map "$app_name" 2>/dev/null || printf ':default:')"
  fi

  if [ -z "$icon" ]; then
    icon=":default:"
  fi

  sketchybar --set "$NAME" icon="$icon" label="$app_name"
fi
